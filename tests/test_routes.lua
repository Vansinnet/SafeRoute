-- Offline check: the road SafeRoute marks safe is the road the game's own Crossroad code keeps
-- in the main path. Run from the workspace root:
--   tools/luajit/luajit mods/active/SafeRoute/tests/test_routes.lua

local SOURCE = "darktide-source/"

package.path = SOURCE .. "?.lua;mods/active/SafeRoute/scripts/mods/SafeRoute/?.lua;" .. package.path

-- Engine natives the Crossroad module touches. math.next_random is a native (seed, min, max) ->
-- new_seed, value; this LCG stands in for it, so the specific roads chosen here mean nothing.
Script = { new_array = function() return {} end }
Log = { info = function() end }
table.clear = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
end
math.next_random = function(seed, min, max)
    seed = (seed * 1103515245 + 12345) % 2147483648

    return seed, min + seed % (max - min + 1)
end

local Crossroad = require("scripts/managers/main_path/utilities/crossroad")
local Routes = require("routes")

-- Two nodes along x from `x`. Road segments carry crossroads_id/road_id and sit at their own y,
-- so no road node coincides with a node of another segment.
local function segment(x, y, crossroads_id, road_id)
    return {
        crossroads_id = crossroads_id,
        road_id = road_id,
        nodes = { { x, y, 0 }, { x + 10, y, 0 } },
    }
end

-- One crossroad per data set: with several, the game's stitch walks them in pairs() order, which
-- LuaJIT varies between runs, and the stitched result depends on that order.
local function build_a()
    return {
        crossroads = { cr_a = { roads = { {}, {} } } },
        main_path_segments = {
            segment(0, 0),
            segment(10, 25, "cr_a", 1),
            segment(10, 50, "cr_a", 2),
            segment(20, 0),
        },
        path_markers = {},
    }
end

local function build_b()
    return {
        crossroads = { cr_b = { roads = { {}, {}, {} } } },
        main_path_segments = {
            segment(20, 0),
            segment(30, 25, "cr_b", 1),
            segment(30, 50, "cr_b", 2),
            segment(30, 100, "cr_b", 3),
            segment(40, 0),
        },
        path_markers = {},
    }
end

local function node_key(node)
    return node[1] .. "," .. node[2] .. "," .. node[3]
end

local failures, runs = 0, 0

for seed = 1, 500 do
    for _, build in ipairs({ build_a, build_b }) do
        local game = build()
        local chosen = Crossroad.generate_road_choices(game.crossroads, seed)

        Crossroad.stitch_and_remove_unused_roads(game.crossroads, chosen, game.main_path_segments, game.path_markers, seed)

        local kept = {}

        for _, main_path_segment in ipairs(game.main_path_segments) do
            for _, node in ipairs(main_path_segment.nodes) do
                kept[node_key(node)] = true
            end
        end

        -- Same test as MainPathManager.is_crossroad_segment_available.
        local crossroads = Routes.collect(build(), function(crossroads_id, road_id)
            return chosen[crossroads_id] == road_id
        end)

        for _, crossroad in ipairs(crossroads) do
            local num_safe = 0

            for _, road in ipairs(crossroad.roads) do
                local in_main_path = kept[node_key(road.points[1])] == true

                num_safe = num_safe + (road.safe and 1 or 0)

                if road.safe ~= in_main_path then
                    failures = failures + 1
                    print(string.format("seed %d crossroad %s road %d: safe=%s but in main path=%s", seed, crossroad.id, road.id, tostring(road.safe), tostring(in_main_path)))
                end
            end

            if num_safe ~= 1 or #crossroad.roads ~= crossroad.num_roads then
                failures = failures + 1
                print(string.format("seed %d crossroad %s: %d safe roads, %d of %d roads", seed, crossroad.id, num_safe, #crossroad.roads, crossroad.num_roads))
            end
        end

        runs = runs + 1
    end
end

local line = { { 0, 0, 0 }, { 3, 4, 0 }, { 3, 4, 10 } }
local mid = Routes.point_along(line, 7.5)
assert(Routes.length(line) == 15, "length")
assert(math.abs(mid[1] - 3) < 1e-9 and math.abs(mid[3] - 2.5) < 1e-9, "point_along")
assert(Routes.point_along(line, 99) == line[3], "point_along past the end")
assert(Routes.collect({ crossroads = {}, main_path_segments = {} }, function() return false end) == nil, "no crossroads")

local function same_points(actual, expected)
    if #actual ~= #expected then
        return false
    end

    for i = 1, #expected do
        for k = 1, 3 do
            if math.abs(actual[i][k] - expected[i][k]) > 1e-9 then
                return false
            end
        end
    end

    return true
end

-- Guide line: the approach is the segment before the crossroad's first road, skipping roads the
-- game dropped, cut at its node closest to the fork.
local fork_data = {
    crossroads = {
        near = { roads = { {}, {} } },
        other = { roads = { {}, {} } },
    },
    main_path_segments = {
        { nodes = { { 0, 0, 0 }, { 10, 0, 0 }, { 20, 0, 0 }, { 30, 0, 0 } } },
        { crossroads_id = "near", road_id = 1, nodes = { { 21, 0, 0 }, { 21, 10, 0 }, { 21, 30, 0 } } },
        { crossroads_id = "near", road_id = 2, nodes = { { 21, 0, 0 }, { 21, -10, 0 } } },
        { crossroads_id = "other", road_id = 2, nodes = { { 50, 50, 0 }, { 21, 1, 0 } } },
    },
}
local fork_crossroads = Routes.collect(fork_data, function(crossroads_id, road_id)
    return road_id == 1
end)
local near = fork_crossroads[1]

assert(near.id == "near", "path order")
assert(same_points(near.approach, { { 0, 0, 0 }, { 10, 0, 0 }, { 20, 0, 0 } }), "approach")
assert(same_points(Routes.tail(near.approach, 5), { { 15, 0, 0 }, { 20, 0, 0 } }), "tail")
assert(same_points(Routes.tail(near.approach, 50), near.approach), "tail longer than path")
assert(same_points(Routes.head(near.roads[1].points, 15), { { 21, 0, 0 }, { 21, 10, 0 }, { 21, 15, 0 } }), "head")
assert(math.abs(near.approach_gap - 1) < 1e-9, "approach gap")
-- "other" starts after a dropped road of "near"; like the game's stitch, the approach skips it and
-- uses the road "near" kept.
assert(same_points(fork_crossroads[2].approach, { { 21, 0, 0 }, { 21, 10, 0 }, { 21, 30, 0 } }), "approach skips dropped roads")

-- Guide dots: every `spacing` metres from `first`, stopping `stop_short` before the end.
local straight = { { 0, 0, 0 }, { 10, 0, 0 } }
local dots = Routes.spaced_points(straight, 3, 3, 2)
assert(#dots == 2 and dots[1][1] == 3 and dots[2][1] == 6, "spaced points")
assert(#Routes.spaced_points(straight, 0, 3, 1) == 4, "spaced points from the start")
assert(#Routes.spaced_points({ { 1, 1, 1 } }, 0, 3, 1) == 0, "spaced points on a single point")

local joined = { { 0, 0, 0 } }
Routes.append(joined, { 0, 0, 0.01 })
Routes.append(joined, { 1, 0, 0 })
assert(#joined == 2, "append skips a repeated point")

print(string.format("%d runs (500 seeds x 2 crossroads), %d failures", runs, failures))
os.exit(failures == 0 and 0 or 1)
