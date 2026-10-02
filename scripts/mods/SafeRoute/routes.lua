local Routes = {}

local function distance(a, b)
    local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]

    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

Routes.length = function(points)
    local total = 0

    for i = 2, #points do
        total = total + distance(points[i - 1], points[i])
    end

    return total
end

-- The point `wanted` metres along a polyline of { x, y, z } arrays, or its last node when it is shorter.
Routes.point_along = function(points, wanted)
    local travelled = 0

    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local length = distance(a, b)

        if length > 0 and travelled + length >= wanted then
            local f = math.max(wanted - travelled, 0) / length

            return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
        end

        travelled = travelled + length
    end

    return points[#points]
end

-- The first `wanted` metres of a polyline, as a new array.
Routes.head = function(points, wanted)
    local result = { points[1] }
    local travelled = 0

    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local length = distance(a, b)

        if travelled + length >= wanted then
            result[#result + 1] = Routes.point_along({ a, b }, wanted - travelled)

            return result
        end

        result[#result + 1] = b
        travelled = travelled + length
    end

    return result
end

-- Points every `spacing` metres along a polyline, from `first` metres in to `stop_short` metres
-- before its end.
Routes.spaced_points = function(points, first, spacing, stop_short)
    local result = {}
    local last = Routes.length(points) - stop_short
    local wanted = first

    while wanted <= last do
        result[#result + 1] = Routes.point_along(points, wanted)
        wanted = wanted + spacing
    end

    return result
end

-- Appends `point` to a polyline unless it repeats the last point.
Routes.append = function(points, point)
    local last = points[#points]

    if not last or distance(last, point) > 0.05 then
        points[#points + 1] = point
    end
end

local function reversed(points)
    local result = {}

    for i = #points, 1, -1 do
        result[#result + 1] = points[i]
    end

    return result
end

-- The last `wanted` metres of a polyline, as a new array in the original direction.
Routes.tail = function(points, wanted)
    return reversed(Routes.head(reversed(points), wanted))
end

local function is_road_segment(crossroads, segment)
    local crossroads_id = segment.crossroads_id

    return crossroads_id ~= nil and crossroads[crossroads_id] ~= nil and segment.road_id ~= nil
end

-- The main path leading into a fork, picked the way Crossroad.stitch_and_remove_unused_roads
-- picks it: the segment before the crossroad's first road, skipping roads the game dropped.
-- It is cut at its node closest to the fork, in case it runs on past it.
-- Returns the approach nodes and the gap in metres from its last node to the fork.
local function find_approach(crossroads, segments, crossroad, is_chosen)
    local fork = crossroad.roads[1].points[1]
    local index = crossroad.first_segment_index - 1

    while index >= 1 do
        local segment = segments[index]

        if not is_road_segment(crossroads, segment) or is_chosen(segment.crossroads_id, segment.road_id) then
            break
        end

        index = index - 1
    end

    local segment = segments[index]

    if not fork or not segment or #segment.nodes == 0 then
        return nil
    end

    local nodes = segment.nodes
    local closest_index, closest_distance = 1, distance(nodes[1], fork)

    for i = 2, #nodes do
        local d = distance(nodes[i], fork)

        if d < closest_distance then
            closest_index, closest_distance = i, d
        end
    end

    local approach = {}

    for i = 1, closest_index do
        approach[i] = nodes[i]
    end

    return approach, closest_distance
end

-- Groups the crossroad segments of a main path resource (the table `dofile` returns, before
-- MainPathManager stitches it) by crossroad and road, in main path order.
-- is_chosen(crossroads_id, road_id) reports the road the game kept for the main path.
Routes.collect = function(main_path_data, is_chosen)
    local crossroads = main_path_data.crossroads

    if type(crossroads) ~= "table" or next(crossroads) == nil then
        return nil
    end

    local list, by_id = {}, {}

    for segment_index, segment in ipairs(main_path_data.main_path_segments) do
        local crossroads_id, road_id = segment.crossroads_id, segment.road_id
        local definition = crossroads_id ~= nil and crossroads[crossroads_id]

        if definition and road_id ~= nil then
            local crossroad = by_id[crossroads_id]

            if not crossroad then
                crossroad = {
                    id = crossroads_id,
                    num_roads = #definition.roads,
                    first_segment_index = segment_index,
                    roads = {},
                    road_by_id = {},
                }
                by_id[crossroads_id] = crossroad
                list[#list + 1] = crossroad
            end

            local road = crossroad.road_by_id[road_id]

            if not road then
                road = {
                    id = road_id,
                    safe = is_chosen(crossroads_id, road_id) and true or false,
                    points = {},
                }
                crossroad.road_by_id[road_id] = road
                crossroad.roads[#crossroad.roads + 1] = road

                if road.safe then
                    crossroad.safe_road_id = road_id
                end
            end

            local points = road.points

            for _, node in ipairs(segment.nodes) do
                points[#points + 1] = node
            end
        end
    end

    for _, crossroad in ipairs(list) do
        table.sort(crossroad.roads, function(a, b)
            return a.id < b.id
        end)

        crossroad.approach, crossroad.approach_gap = find_approach(crossroads, main_path_data.main_path_segments, crossroad, is_chosen)
    end

    return #list > 0 and list or nil
end

return Routes
