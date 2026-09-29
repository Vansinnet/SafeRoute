-- Offline check: the road SafeRoute marks safe is the road the game's own Crossroad code keeps
-- in the main path. Run from the workspace root:
--   tools/luajit/luajit mods/active/SafeRoute/tests/test_routes.lua

local SOURCE = "darktide-source/Darktide-Source-Code-1.13.0/"

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

local function build()
    return {
        crossroads = {
            cr_a = { roads = { {}, {} } },
            cr_b = { roads = { {}, {}, {} } },
        },
        main_path_segments = {
            segment(0, 0),
            segment(10, 25, "cr_a", 1),
            segment(10, 50, "cr_a", 2),
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

local line = { { 0, 0, 0 }, { 3, 4, 0 }, { 3, 4, 10 } }
local mid = Routes.point_along(line, 7.5)
assert(Routes.length(line) == 15, "length")
assert(math.abs(mid[1] - 3) < 1e-9 and math.abs(mid[3] - 2.5) < 1e-9, "point_along")
assert(Routes.point_along(line, 99) == line[3], "point_along past the end")
assert(Routes.collect({ crossroads = {}, main_path_segments = {} }, function() return false end) == nil, "no crossroads")

print(string.format("%d seeds, %d failures", runs, failures))
os.exit(failures == 0 and 0 or 1)
