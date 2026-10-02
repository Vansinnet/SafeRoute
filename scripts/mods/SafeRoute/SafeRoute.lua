local mod = get_mod("SafeRoute")
local Navigation = require("scripts/extension_systems/navigation/utilities/navigation")
local NavQueries = require("scripts/utilities/nav_queries")
local Routes = mod:io_dofile("SafeRoute/scripts/mods/SafeRoute/routes")
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
-- Guide dots sit on the nav mesh (the walkable floor), raised this much.
local DOT_HEIGHT = 0.6
-- Search box when snapping a main path node to the nav mesh.
local NAV_ABOVE, NAV_BELOW, NAV_LATERAL = 2, 2, 2
-- A path search that has not finished after this many seconds is cancelled.
local LEG_TIMEOUT = 3
-- Test builds: one console log line per path search ("[MOD][SafeRoute][INFO] guide ..."). Off for
-- releases.
local LOG_GUIDE_PATHS = false

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
-- Nav objects for the guide paths. They live in the mission's nav world, which the game destroys
-- right after the main path manager, so they are released from the MainPathManager.destroy hook.
local nav = {
    world = nil,
    traverse_logic = nil,
    cost_table = nil,
    astar = nil,
    running = false,
    leg_time = 0,
    jobs = {},
    job = nil,
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

local function forget_nav()
    nav.world = nil
    nav.traverse_logic = nil
    nav.cost_table = nil
    nav.astar = nil
    nav.running = false
    nav.job = nil
    table.clear(nav.jobs)
end

-- Only while the nav world is alive.
local function destroy_nav()
    local astar = nav.astar

    if astar then
        if nav.running and not GwNavAStar.processing_finished(astar) then
            GwNavAStar.cancel(astar)
        end

        GwNavAStar.destroy(astar)
    end

    if nav.traverse_logic then
        GwNavTraverseLogic.destroy(nav.traverse_logic)
        GwNavTagLayerCostTable.destroy(nav.cost_table)
    end

    forget_nav()
end

local function forget_mission()
    remove_markers()
    -- The hook has already destroyed the nav objects; if it did not run, the nav world is gone and
    -- they must not be touched.
    forget_nav()
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

-- One job per road: the walkable path from the fork into the road, up to its SAFE ROUTE / WRONG WAY
-- marker. The fork is where the path into the crossroad ends, or else the road's first node.
local function queue_guide_jobs(crossroads)
    for index, crossroad in ipairs(crossroads) do
        local approach = crossroad.approach

        crossroad.guide_paths = {}

        if crossroad.safe_road_id ~= nil then
            for _, road in ipairs(crossroad.roads) do
                if #road.points > 0 then
                    local waypoints = Routes.head(road.points, ENTRY_DISTANCE)

                    if approach then
                        table.insert(waypoints, 1, approach[#approach])
                    end

                    nav.jobs[#nav.jobs + 1] = {
                        label = string.format("fork %d road %s%s", index, tostring(road.id), road.safe and " (safe)" or ""),
                        waypoints = waypoints,
                        store = function(path)
                            crossroad.guide_paths[road.id] = path
                        end,
                    }
                end
            end
        end
    end
end

local function ensure_nav()
    if nav.astar then
        return true
    end

    local nav_mesh = Managers.state.nav_mesh
    local nav_world = nav_mesh and nav_mesh:nav_world()

    if not nav_world then
        return false
    end

    -- Same as the client's own traverse logic (nav_mesh_manager.lua:333-343): the level's allowed
    -- nav tag layers at cost 1.
    local traverse_logic, cost_table = Navigation.create_traverse_logic(nav_world, {}, nil, false)

    nav.world = nav_world
    nav.traverse_logic = traverse_logic
    nav.cost_table = cost_table
    nav.astar = GwNavAStar.create()

    return true
end

local function on_nav_mesh(point)
    return NavQueries.position_on_mesh_with_outside_position(nav.world, nav.traverse_logic,
        Vector3(point[1], point[2], point[3]), NAV_ABOVE, NAV_BELOW, NAV_LATERAL)
end

local function to_point(position)
    return { position.x, position.y, position.z }
end

local function format_point(point)
    if not point then
        return "none"
    end

    return string.format("(%.1f, %.1f, %.1f)", point[1], point[2], point[3])
end

local function log_guide(job, format, ...)
    if LOG_GUIDE_PATHS then
        mod:info("guide %s: " .. format, job.label, ...)
    end
end

-- Runs the A* legs between consecutive waypoints, one leg at a time across frames. A waypoint off
-- the nav mesh, or a leg without a path, falls back to the straight main path line.
local function step_nav(dt)
    local astar, nav_world, traverse_logic = nav.astar, nav.world, nav.traverse_logic

    if not astar or not nav_world or not traverse_logic then
        return
    end

    local job = nav.job

    if not job then
        job = table.remove(nav.jobs, 1)

        if not job then
            return
        end

        local first = on_nav_mesh(job.waypoints[1])

        job.leg = 1
        job.path = { first and to_point(first) or job.waypoints[1] }
        nav.job = job
        log_guide(job, "%d waypoints from %s to %s", #job.waypoints, format_point(job.waypoints[1]),
            format_point(job.waypoints[#job.waypoints]))
    end

    if nav.running then
        if not GwNavAStar.processing_finished(astar) then
            nav.leg_time = nav.leg_time + dt

            if nav.leg_time < LEG_TIMEOUT then
                return
            end

            GwNavAStar.cancel(astar)
            nav.running = false
            log_guide(job, "leg %d timed out after %.1f s, straight line used", job.leg, nav.leg_time)
            Routes.append(job.path, job.leg_end)
        else
            nav.running = false

            if GwNavAStar.path_found(astar) then
                local leg_path = {}

                for i = 1, GwNavAStar.node_count(astar) do
                    local point = to_point(GwNavAStar.node_at_index(astar, i))

                    leg_path[#leg_path + 1] = point
                    Routes.append(job.path, point)
                end

                log_guide(job, "leg %d path found, %d nodes, %.1f m (straight %.1f m)", job.leg, #leg_path,
                    Routes.length(leg_path), Routes.length({ job.leg_start, job.leg_end }))
            else
                log_guide(job, "leg %d no path between %s and %s, straight line used", job.leg,
                    format_point(job.leg_start), format_point(job.leg_end))
                Routes.append(job.path, job.leg_end)
            end
        end

        job.leg = job.leg + 1
    end

    local waypoints = job.waypoints

    while job.leg < #waypoints do
        local from = on_nav_mesh(waypoints[job.leg])
        local to = on_nav_mesh(waypoints[job.leg + 1])

        if from and to then
            job.leg_start = to_point(from)
            job.leg_end = to_point(to)
            GwNavAStar.start(astar, nav_world, from, to, traverse_logic)
            nav.running = true
            nav.leg_time = 0

            return
        end

        log_guide(job, "leg %d off the nav mesh (%s -> %s, snapped %s -> %s), straight line used", job.leg,
            format_point(waypoints[job.leg]), format_point(waypoints[job.leg + 1]),
            format_point(from and to_point(from)), format_point(to and to_point(to)))
        Routes.append(job.path, waypoints[job.leg + 1])
        job.leg = job.leg + 1
    end

    log_guide(job, "done, %d points, %.1f m", #job.path, Routes.length(job.path))
    job.store(job.path)
    nav.job = nil
end

local function add_marker(key, point, height, data)
    local position = Vector3(point[1], point[2], point[3] + height)

    data.max_distance = config.max_distance
    Managers.event:trigger("add_world_marker_position", MarkerTemplate.name, position, function(id)
        state.markers[key] = id
    end, data)
end

-- The SAFE ROUTE / WRONG WAY markers show through walls.
local function add_crossroad_markers(index, crossroad)
    for _, road in ipairs(crossroad.roads) do
        local points = road.points

        if #points > 0 then
            local key = index .. ":" .. tostring(road.id)

            if road.safe then
                add_marker(key, Routes.point_along(points, ENTRY_DISTANCE), MARKER_HEIGHT, {
                    color = SAFE_COLOR,
                    icon = SAFE_ICON,
                    label = mod:localize("label_safe"),
                })
            elseif config.show_wrong_roads and crossroad.safe_road_id ~= nil then
                add_marker(key, Routes.point_along(points, ENTRY_DISTANCE), MARKER_HEIGHT, {
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

-- Dots along the walkable path from the fork to each road's marker, stopping short of the marker:
-- green to SAFE ROUTE, red to WRONG WAY (with "Mark wrong roads"). Only the safe path has a dot at the
-- fork itself, so the fork is not marked twice. Paths arrive a few frames after the mission starts.
local function add_guide_markers(index, crossroad)
    local placed = state.guides_placed

    for _, road in ipairs(crossroad.roads) do
        local path = crossroad.guide_paths and crossroad.guide_paths[road.id]
        local key = index .. ":guide:" .. tostring(road.id)

        if path and not placed[key] and (road.safe or config.show_wrong_roads) then
            placed[key] = true

            if road.safe then
                add_dots(key, Routes.spaced_points(path, 0, DOT_SPACING, 1.5), SAFE_COLOR, SAFE_ICON)
            else
                add_dots(key, Routes.spaced_points(path, DOT_SPACING, DOT_SPACING, 1.5), WRONG_COLOR, WRONG_ICON)
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

        if crossroad.approach then
            mod:echo(mod:localize("guide_found", #crossroad.approach, crossroad.approach_gap))
        else
            mod:echo(mod:localize("guide_missing"))
        end
    end
end

mod.update = function(dt)
    if not mod:is_enabled() then
        return
    end

    local main_path = Managers.state and Managers.state.main_path

    if main_path ~= state.main_path then
        forget_mission()
        state.main_path = main_path
        state.crossroads = main_path and load_crossroads(main_path)

        if state.crossroads then
            queue_guide_jobs(state.crossroads)
        end
    end

    local crossroads = state.crossroads

    if not crossroads then
        return
    end

    if config.announce and not state.announced then
        state.announced = true
        mod:echo(mod:localize("announce_text", #crossroads))
    end

    -- Paths are searched once the HUD exists, so the level's nav mesh is in place.
    if state.element and (nav.job or #nav.jobs > 0) and ensure_nav() then
        step_nav(dt)
    end

    place_markers(crossroads)
end

mod:hook("MainPathManager", "destroy", function(func, self, ...)
    destroy_nav()

    return func(self, ...)
end)

mod.on_setting_changed = function()
    refresh_config()
    remove_markers()
end

mod.on_disabled = function()
    remove_markers()
    destroy_nav()
    -- Searches restart from scratch when the mod is enabled again.
    state.main_path = nil
end

mod.on_unload = function()
    remove_markers()
    destroy_nav()
end

mod:command("saferoute", mod:localize("command_description"), function()
    local crossroads = state.crossroads

    if not crossroads then
        mod:echo(mod:localize("no_crossroads"))

        return
    end

    describe_crossroads(crossroads)
end)
