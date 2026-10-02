local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

local DEFAULT_SIZE = 52
local DEFAULT_COLOR = { 90, 230, 110 }

template.name = "SafeRoute_marker"
template.size = { DEFAULT_SIZE, DEFAULT_SIZE }
template.min_distance = 0
template.max_distance = 60
template.position_offset = { 0, 0, 0 }
template.check_line_of_sight = false
template.screen_clamp = false

template.create_widget_defintion = function(_, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "background",
            value = "content/ui/materials/hud/interactions/frames/point_of_interest_back",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = { DEFAULT_SIZE, DEFAULT_SIZE },
                offset = { 0, 0, 1 },
                color = { 190, 20, 20, 20 },
            },
        },
        {
            pass_type = "texture",
            style_id = "ring",
            value = "content/ui/materials/hud/interactions/frames/point_of_interest_top",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = { DEFAULT_SIZE, DEFAULT_SIZE },
                offset = { 0, 0, 2 },
                color = { 235, DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3] },
            },
        },
        {
            pass_type = "texture",
            style_id = "icon",
            value_id = "icon",
            value = "content/ui/materials/hud/interactions/icons/location",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = { 28, 28 },
                offset = { 0, 0, 3 },
                color = { 255, DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3] },
            },
        },
        {
            pass_type = "text",
            style_id = "label_shadow",
            value_id = "label",
            value = "",
            style = {
                font_type = "proxima_nova_bold",
                font_size = 16,
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                size = { 260, 40 },
                offset = { 1, DEFAULT_SIZE * 0.5 + 5, 3 },
                text_color = { 230, 0, 0, 0 },
            },
            visibility_function = function(content)
                return content.label ~= ""
            end,
        },
        {
            pass_type = "text",
            style_id = "label",
            value_id = "label",
            value = "",
            style = {
                font_type = "proxima_nova_bold",
                font_size = 16,
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                size = { 260, 40 },
                offset = { 0, DEFAULT_SIZE * 0.5 + 4, 4 },
                text_color = { 255, DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3] },
            },
            visibility_function = function(content)
                return content.label ~= ""
            end,
        },
    }, scenegraph_id)
end

local function set_rgb(color, rgb)
    color[2], color[3], color[4] = rgb[1], rgb[2], rgb[3]
end

template.on_enter = function(widget, marker)
    local data = marker.data
    local rgb = data.color or DEFAULT_COLOR
    local size = data.size or DEFAULT_SIZE
    local style = widget.style

    style.background.size[1], style.background.size[2] = size, size
    style.ring.size[1], style.ring.size[2] = size, size
    set_rgb(style.ring.color, rgb)

    local icon_size = math.floor(size * 0.54)

    style.icon.size[1], style.icon.size[2] = icon_size, icon_size
    set_rgb(style.icon.color, rgb)
    set_rgb(style.label.text_color, rgb)
    style.label.offset[2] = size * 0.5 + 4
    style.label_shadow.offset[2] = size * 0.5 + 5

    widget.content.icon = data.icon or widget.content.icon
    widget.content.label = data.label or ""
    marker.template.max_distance = data.max_distance or template.max_distance

    -- With check_line_of_sight the HUD raycasts camera -> marker and stores marker.raycast_result
    -- (true when something is in the way); hidden until the first result arrives.
    local check_line_of_sight = data.check_line_of_sight == true

    marker.template.check_line_of_sight = check_line_of_sight
    widget.content.line_of_sight_progress = check_line_of_sight and 0 or 1
    widget.alpha_multiplier = widget.content.line_of_sight_progress
end

local LINE_OF_SIGHT_SPEED = 8

-- Fades like the game's interaction markers (world_marker_template_interaction.lua:741-752).
template.update_function = function(_, _, widget, marker, marker_template, dt)
    if not marker_template.check_line_of_sight then
        return
    end

    local content = widget.content
    local progress = content.line_of_sight_progress or 0

    if marker.raycast_initialized then
        if marker.raycast_result then
            progress = math.max(progress - dt * LINE_OF_SIGHT_SPEED, 0)
        else
            progress = math.min(progress + dt * LINE_OF_SIGHT_SPEED, 1)
        end
    end

    content.line_of_sight_progress = progress
    widget.alpha_multiplier = progress
end

return template
