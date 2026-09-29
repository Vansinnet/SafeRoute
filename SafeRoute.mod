return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`SafeRoute` encountered an error loading the Darktide Mod Framework.")
        new_mod("SafeRoute", {
            mod_script = "SafeRoute/scripts/mods/SafeRoute/SafeRoute",
            mod_data = "SafeRoute/scripts/mods/SafeRoute/SafeRoute_data",
            mod_localization = "SafeRoute/scripts/mods/SafeRoute/SafeRoute_localization",
        })
    end,
    packages = {},
}
