import QtQuick
import Quickshell
import Quickshell.Wayland

// Full-screen desktop chrome. APP is a transparent input hole over normal
// Hyprland windows; the controller keeps those windows inside the hole.
PanelWindow {
    id: panel
    anchors { top: true; right: true; bottom: true; left: true }
    color: "transparent"
    aboveWindows: true
    WlrLayershell.keyboardFocus: content.internalPage
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    surfaceFormat.opaque: false
    mask: Region {
        width: panel.width
        height: panel.height
        Region {
            x: content.appAreaX
            y: content.appAreaY
            width: content.internalPage ? 0 : content.appAreaWidth
            height: content.internalPage ? 0 : content.appAreaHeight
            intersection: Intersection.Subtract
        }
    }

    ShellContent {
        id: content
        desktopMode: true
        monitorName: panel.screen ? panel.screen.name : ""
    }
}
