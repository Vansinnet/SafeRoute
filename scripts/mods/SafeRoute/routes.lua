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

-- Groups the crossroad segments of a main path resource (the table `dofile` returns, before
-- MainPathManager stitches it) by crossroad and road, in main path order.
-- is_chosen(crossroads_id, road_id) reports the road the game kept for the main path.
Routes.collect = function(main_path_data, is_chosen)
    local crossroads = main_path_data.crossroads

    if type(crossroads) ~= "table" or next(crossroads) == nil then
        return nil
    end

    local list, by_id = {}, {}

    for _, segment in ipairs(main_path_data.main_path_segments) do
        local crossroads_id, road_id = segment.crossroads_id, segment.road_id
        local definition = crossroads_id ~= nil and crossroads[crossroads_id]

        if definition and road_id ~= nil then
            local crossroad = by_id[crossroads_id]

            if not crossroad then
                crossroad = {
                    id = crossroads_id,
                    num_roads = #definition.roads,
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
    end

    return #list > 0 and list or nil
end

return Routes
