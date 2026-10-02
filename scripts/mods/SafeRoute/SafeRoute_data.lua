local mod = get_mod("SafeRoute")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "show_wrong_roads",
                type = "checkbox",
                tooltip = "show_wrong_roads_tooltip",
                default_value = true,
            },
            {
                setting_id = "show_guide_dots",
                type = "checkbox",
                tooltip = "show_guide_dots_tooltip",
                default_value = true,
            },
            {
                setting_id = "max_distance",
                type = "numeric",
                tooltip = "max_distance_tooltip",
                default_value = 60,
                range = { 20, 200 },
            },
            {
                setting_id = "announce",
                type = "checkbox",
                tooltip = "announce_tooltip",
                default_value = true,
            },
        },
    },
}
