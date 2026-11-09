import QtQuick
import QtQuick.Window
import Quickshell
import "theme"
import "ui"

// Visual study only; the shell will provide the focused text field later.
Window {
    id: preview
    width: 1600; height: 460
    visible: true
    color: LcarsUi.black
    title: "LCARS touch keyboard preview"

    Binding {
        target: LcarsUi
        property: "scale"
        value: Math.min(preview.width / 1600, preview.height / 460)
    }
    LcarsKeyboard {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - LcarsUi.u(40))
    }
    Timer {
        interval: 1000; running: Quickshell.env("LCARS_CAPTURE") === "1"
        onTriggered: preview.contentItem.grabToImage(result => {
            result.saveToFile("/tmp/lcars-keyboard-preview.png")
            Qt.quit()
        })
    }
}
