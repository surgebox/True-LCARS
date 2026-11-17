-- Minimal, separate Hyprland configuration for the LCARS login session.
-- Uses Hyprland 0.55+ Lua configuration as packaged by the Fedora COPR.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.exec_once("/usr/local/bin/lcars-shell")
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
