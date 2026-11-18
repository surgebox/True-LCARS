import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

// Play once over the desktop, then fade through black to the ready LCARS UI.
PanelWindow {
    id: intro
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0
    color: "transparent"
    surfaceFormat.opaque: false

    property bool finishing: false

    function finish() {
        if (finishing) return
        finishing = true
        fadeOut.start()
    }

    Rectangle {
        id: black
        anchors.fill: parent
        color: "black"
    }

    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    // A click skips the remainder of the intro without closing the session.
    MouseArea {
        anchors.fill: parent
        onClicked: intro.finish()
    }

    MediaPlayer {
        id: player
        source: Qt.resolvedUrl("assets/lcars-intro.webm")
        videoOutput: video
        onPositionChanged: {
            // Finish while the last frame is still available to fade out.
            if (player.duration > 0 && player.position >= player.duration - 1500) intro.finish()
        }
        onMediaStatusChanged: {
            if (player.mediaStatus === MediaPlayer.EndOfMedia ||
                player.mediaStatus === MediaPlayer.InvalidMedia) intro.finish()
        }
        onErrorOccurred: intro.finish()
    }

    // Never leave an unplayable or stalled video covering the desktop.
    Timer {
        interval: 25000
        running: intro.visible
        onTriggered: intro.finish()
    }

    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: video; property: "opacity"; from: 1; to: 0; duration: 700 }
        NumberAnimation { target: black; property: "opacity"; from: 1; to: 0; duration: 850 }
        ScriptAction { script: { player.stop(); intro.visible = false } }
    }

    Component.onCompleted: player.play()
}
