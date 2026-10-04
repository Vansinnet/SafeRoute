local mod = get_mod("SafeRoute")
local Routes = mod:io_dofile("SafeRoute/scripts/mods/SafeRoute/routes")
local RecordedRoutes = mod:io_dofile("SafeRoute/scripts/mods/SafeRoute/recorded_routes")
local MarkerTemplate = mod:io_dofile("SafeRoute/scripts/mods/SafeRoute/SafeRoute_marker")

local SAFE_COLOR = { 90, 230, 110 }
local WRONG_COLOR = { 235, 80, 60 }
local SAFE_ICON = "content/ui/materials/hud/interactions/icons/location"
local WRONG_ICON = "content/ui/materials/hud/interactions/icons/attention"
-- Roads of one fork likely share their first node, so entry markers go this far in to keep them apart.
local ENTRY_DISTANCE = 8
local MARKER_HEIGHT = 1.2
local DOT_SIZE = 26
local DOT_SPACING = 2
-- Guide dots stop this far before the end of a route; the road's marker goes this far past the last dot.
local DOT_STOP_SHORT = 1.5
local MARKER_AFTER_LAST_DOT = 1
-- Guide dots are drawn on routes recorded by walking them (recorded_routes.lua),
-- like Markers Improved AIO's hand-placed guides: a dot is always where a player stood. Recorded
-- points are the player's feet; dots float this much above them.
local DOT_HEIGHT = 0.6

-- Removed options: "Markers along the safe road" (v1.0.0) and options from test builds. Their stored
-- values are never read; drop them from the settings file.
for _, setting_id in ipairs({ "show_breadcrumbs", "hide_behind_walls", "show_lead_in", "lead_in_distance" }) do
    if mod:get(setting_id) ~= nil then
        mod:set(setting_id, nil)
    end
end

local config = {}
local state = {
    main_path = nil,
    crossroads = nil,
    announced = false,
    element = nil,
    placed = false,
    markers = {},
    guides_placed = {},
}
local function refresh_config()
    config.show_wrong_roads = mod:get("show_wrong_roads")
    config.max_distance = mod:get("max_distance")
    config.announce = mod:get("announce")
    config.show_guide_dots = mod:get("show_guide_dots")
end

refresh_config()

local function world_markers_element()
    local hud = Managers.ui and Managers.ui:get_hud()

    return hud and hud:element("HudElementWorldMarkers")
end

-- Marker ids belong to the HUD that made them; a new HUD starts counting again, so only
-- remove through events while that HUD is still the current one.
local function remove_markers()
    local event_manager = Managers.event

    if event_manager and state.element and state.element == world_markers_element() then
        for _, id in pairs(state.markers) do
            event_manager:trigger("remove_world_marker", id)
        end
    end

    table.clear(state.markers)
    table.clear(state.guides_placed)
    state.placed = false
end

local function forget_mission()
    remove_markers()
    state.main_path = nil
    state.crossroads = nil
    state.announced = false
end

-- MainPathManager keeps only the chosen road of each crossroad, so read a fresh copy of the resource
-- (dofile runs the chunk again) and ask the manager which road it kept.
local function load_crossroads(main_path)
    local resource_name = main_path._main_path_resource_name

    if type(resource_name) ~= "string" or not Application.can_get_resource("lua", resource_name) then
        return nil
    end

    local data = dofile(resource_name)

    if type(data) ~= "table" then
        return nil
    end

    return Routes.collect(data, function(crossroads_id, road_id)
        return main_path:is_crossroad_segment_available(crossroads_id, road_id)
    end)
end

local function resource_name()
    local main_path = state.main_path

    return main_path and main_path._main_path_resource_name
end

local function recorded_route(crossroads_id, road_id)
    local name = resource_name()
    local by_crossroad = name and RecordedRoutes[name]
    local by_road = by_crossroad and by_crossroad[crossroads_id]

    return by_road and by_road[road_id]
end

local function add_marker(key, point, height, data)
    local position = Vector3(point[1], point[2], point[3] + height)

    data.max_distance = config.max_distance
    Managers.event:trigger("add_world_marker_position", MarkerTemplate.name, position, function(id)
        state.markers[key] = id
    end, data)
end

-- Green dots start at the fork; red dots one step in, so the fork is marked once.
local function first_dot_distance(road)
    return road.safe and 0 or DOT_SPACING
end

-- With a recorded route, the marker stands 1 m past the route's last guide dot; otherwise 8 m
-- along the road's main path.
local function marker_point(crossroad, road)
    local route = recorded_route(crossroad.id, road.id)

    if not route then
        return Routes.point_along(road.points, ENTRY_DISTANCE)
    end

    local length = Routes.length(route)
    local first = first_dot_distance(road)
    local wanted = length

    if length - DOT_STOP_SHORT >= first then
        local last_dot = first + math.floor((length - DOT_STOP_SHORT - first) / DOT_SPACING) * DOT_SPACING

        wanted = math.min(last_dot + MARKER_AFTER_LAST_DOT, length)
    end

    return Routes.point_along(route, wanted)
end

-- The SAFE ROUTE / WRONG WAY markers show through walls.
local function add_crossroad_markers(index, crossroad)
    for _, road in ipairs(crossroad.roads) do
        local points = road.points

        if #points > 0 then
            local key = index .. ":" .. tostring(road.id)

            if road.safe then
                add_marker(key, marker_point(crossroad, road), MARKER_HEIGHT, {
                    color = SAFE_COLOR,
                    icon = SAFE_ICON,
                    label = mod:localize("label_safe"),
                })
            elseif config.show_wrong_roads and crossroad.safe_road_id ~= nil then
                add_marker(key, marker_point(crossroad, road), MARKER_HEIGHT, {
                    color = WRONG_COLOR,
                    icon = WRONG_ICON,
                    label = mod:localize("label_wrong"),
                })
            end
        end
    end
end

-- Guide dots hide behind walls.
local function add_dots(key, points, color, icon)
    for i, point in ipairs(points) do
        add_marker(key .. ":" .. i, point, DOT_HEIGHT, {
            color = color,
            icon = icon,
            size = DOT_SIZE,
            check_line_of_sight = true,
        })
    end
end

-- Dots along the recorded route from the fork to each road's marker: green to SAFE ROUTE, red to
-- WRONG WAY (with "Mark wrong roads"). Only the safe route has a dot at the fork itself.
local function add_guide_markers(index, crossroad)
    local placed = state.guides_placed

    for _, road in ipairs(crossroad.roads) do
        local route = recorded_route(crossroad.id, road.id)
        local key = index .. ":guide:" .. tostring(road.id)

        if route and not placed[key] and crossroad.safe_road_id ~= nil and (road.safe or config.show_wrong_roads) then
            placed[key] = true

            local dots = Routes.spaced_points(route, first_dot_distance(road), DOT_SPACING, DOT_STOP_SHORT)

            if road.safe then
                add_dots(key, dots, SAFE_COLOR, SAFE_ICON)
            else
                add_dots(key, dots, WRONG_COLOR, WRONG_ICON)
            end
        end
    end
end

local function place_markers(crossroads)
    local element = world_markers_element()

    if element ~= state.element then
        table.clear(state.markers)
        table.clear(state.guides_placed)
        state.placed = false
        state.element = element
    end

    if not element or not Managers.event then
        return
    end

    if not state.placed then
        state.placed = true

        -- Also replaces the template in a HUD that survived a mod reload.
        element._marker_templates[MarkerTemplate.name] = MarkerTemplate

        for index, crossroad in ipairs(crossroads) do
            add_crossroad_markers(index, crossroad)
        end
    end

    if config.show_guide_dots then
        for index, crossroad in ipairs(crossroads) do
            add_guide_markers(index, crossroad)
        end
    end
end

local function describe_crossroads(crossroads)
    for index, crossroad in ipairs(crossroads) do
        local safe = crossroad.safe_road_id

        mod:echo(mod:localize("crossroad_line", index, safe ~= nil and tostring(safe) or "?", crossroad.num_roads))

        for _, road in ipairs(crossroad.roads) do
            mod:echo(mod:localize(recorded_route(crossroad.id, road.id) and "route_recorded" or "route_missing",
                tostring(crossroad.id), tostring(road.id)))
        end
    end
end

mod.update = function()
    if not mod:is_enabled() then
        return
    end

    local main_path = Managers.state and Managers.state.main_path

    if main_path ~= state.main_path then
        forget_mission()
        state.main_path = main_path
        state.crossroads = main_path and load_crossroads(main_path)
    end

    local crossroads = state.crossroads

    if not crossroads then
        return
    end

    if config.announce and not state.announced then
        state.announced = true
        mod:echo(mod:localize("announce_text", #crossroads))
    end

    place_markers(crossroads)
end

mod.on_setting_changed = function()
    refresh_config()
    remove_markers()
end

mod.on_disabled = function()
    remove_markers()
end

mod.on_unload = function()
    remove_markers()
end

mod:command("saferoute", mod:localize("command_description"), function()
    local crossroads = state.crossroads

    if not crossroads then
        mod:echo(mod:localize("no_crossroads"))

        return
    end

    describe_crossroads(crossroads)
end)
