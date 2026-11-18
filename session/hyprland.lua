-- Minimal, separate Hyprland configuration for the LCARS login session.
-- Uses Hyprland 0.55+ Lua configuration as packaged by the Fedora COPR.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true } })
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())

-- Start the shell after the compositor is ready. Hyprland's Lua API has no
-- exec_once function; the start event fires once per compositor launch.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/local/bin/lcars-shell")
end)
