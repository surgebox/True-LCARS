import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Full-screen desktop chrome. APP is a transparent input hole over normal
// Hyprland windows; the controller keeps those windows inside the hole.
ShellRoot {
    IntroScreen { }

    // Keep the wallpaper beneath normal app windows and the LCARS chrome.
    PanelWindow {
        anchors { top: true; right: true; bottom: true; left: true }
        WlrLayershell.layer: WlrLayer.Background
        exclusiveZone: 0
        color: "black"

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/lcars-wallpaper.png")
            fillMode: Image.PreserveAspectCrop
        }
    }

    PanelWindow {
        id: panel
        anchors { top: true; right: true; bottom: true; left: true }
        color: "transparent"
        aboveWindows: true
        WlrLayershell.keyboardFocus: content.powerMenuOpen ? WlrKeyboardFocus.Exclusive
            : content.internalPage || content.networkMenuOpen
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusiveZone: 0
        surfaceFormat.opaque: false
        mask: Region {
            width: panel.width
            height: panel.height
            Region {
                x: content.appAreaX
                y: content.appAreaY
                width: content.captureAppArea ? 0 : content.appAreaWidth
                height: content.captureAppArea ? 0 : content.appAreaHeight
                intersection: Intersection.Subtract
            }
        }

        ShellContent {
            id: content
            desktopMode: true
            monitorName: panel.screen ? panel.screen.name : ""
            hyprMonitor: panel.screen ? Hyprland.monitorFor(panel.screen) : null
            activeWindow: ToplevelManager.activeToplevel
        }
    }
}
