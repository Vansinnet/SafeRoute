local mod = get_mod("SafeRoute")
local Routes = mod:io_dofile("SafeRoute/scripts/mods/SafeRoute/routes")
local MarkerTemplate = mod:io_dofile("SafeRoute/scripts/mods/SafeRoute/SafeRoute_marker")

local SAFE_COLOR = { 90, 230, 110 }
local WRONG_COLOR = { 235, 80, 60 }
local SAFE_ICON = "content/ui/materials/hud/interactions/icons/location"
local WRONG_ICON = "content/ui/materials/hud/interactions/icons/attention"
-- Roads of one fork likely share their first node, so entry markers go this far in to keep them apart.
local ENTRY_DISTANCE = 8
local BREADCRUMB_SPACING = 12
local MAX_BREADCRUMBS = 25
local MARKER_HEIGHT = 1.2

local config = {}
local state = {
    main_path = nil,
    crossroads = nil,
    announced = false,
    element = nil,
    placed = false,
    markers = {},
}

local function refresh_config()
    config.show_wrong_roads = mod:get("show_wrong_roads")
    config.show_breadcrumbs = mod:get("show_breadcrumbs")
    config.max_distance = mod:get("max_distance")
    config.announce = mod:get("announce")
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

local function add_marker(key, point, data)
    local position = Vector3(point[1], point[2], point[3] + MARKER_HEIGHT)

    data.max_distance = config.max_distance
    Managers.event:trigger("add_world_marker_position", MarkerTemplate.name, position, function(id)
        state.markers[key] = id
    end, data)
end

local function add_crossroad_markers(index, crossroad)
    for _, road in ipairs(crossroad.roads) do
        local points = road.points

        if #points > 0 then
            local key = index .. ":" .. tostring(road.id)

            if road.safe then
                add_marker(key, Routes.point_along(points, ENTRY_DISTANCE), {
                    color = SAFE_COLOR,
                    icon = SAFE_ICON,
                    label = mod:localize("label_safe"),
                })

                if config.show_breadcrumbs then
                    local length = Routes.length(points)
                    local distance = ENTRY_DISTANCE + BREADCRUMB_SPACING
                    local count = 0

                    while distance < length - 2 and count < MAX_BREADCRUMBS do
                        count = count + 1
                        add_marker(key .. ":" .. count, Routes.point_along(points, distance), {
                            color = SAFE_COLOR,
                            icon = SAFE_ICON,
                            size = 26,
                        })
                        distance = distance + BREADCRUMB_SPACING
                    end
                end
            elseif config.show_wrong_roads and crossroad.safe_road_id ~= nil then
                add_marker(key, Routes.point_along(points, ENTRY_DISTANCE), {
                    color = WRONG_COLOR,
                    icon = WRONG_ICON,
                    label = mod:localize("label_wrong"),
                })
            end
        end
    end
end

local function describe_crossroads(crossroads)
    for index, crossroad in ipairs(crossroads) do
        local safe = crossroad.safe_road_id

        mod:echo(mod:localize("crossroad_line", index, safe ~= nil and tostring(safe) or "?", crossroad.num_roads))
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

    local element = world_markers_element()

    if element ~= state.element then
        table.clear(state.markers)
        state.placed = false
        state.element = element
    end

    if state.placed or not element or not Managers.event then
        return
    end

    state.placed = true

    -- Also replaces the template in a HUD that survived a mod reload.
    element._marker_templates[MarkerTemplate.name] = MarkerTemplate

    for index, crossroad in ipairs(crossroads) do
        add_crossroad_markers(index, crossroad)
    end
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
