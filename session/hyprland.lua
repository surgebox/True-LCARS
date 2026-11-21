-- Minimal, separate Hyprland configuration for the LCARS login session.
-- Uses Hyprland 0.55+ Lua configuration as packaged by the Fedora COPR.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true } })
hl.config({ general = {
    resize_on_border = true,
    extend_border_grab_area = 16,
    hover_icon_on_border = true,
} })
hl.env("XDG_CURRENT_DESKTOP", "LCARS:Hyprland")
hl.env("GTK_A11Y", "atspi")
hl.env("QT_LINUX_ACCESSIBILITY_ALWAYS_ON", "1")
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())

-- Start the shell after the compositor is ready. Hyprland's Lua API has no
-- exec_once function; the start event fires once per compositor launch.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE GTK_A11Y QT_LINUX_ACCESSIBILITY_ALWAYS_ON; exec /usr/local/bin/lcars-shell")
    hl.exec_cmd("/usr/libexec/polkit-mate-authentication-agent-1")
end)
