import QtQuick
import QtQuick.Window
import Quickshell
import "ui"
import "theme"

Window {
    id: preview
    width: 850; height: 310; visible: true; color: LcarsUi.black
    title: "LCARS battery status · offline preview"

    Item {
    id: surface
    anchors.fill: parent
    LcarsLabel { x: 40; y: 8; text: "COMPACT · 30%"; size: 18; color: LcarsUi.lilac }
    LcarsIconButton {
        x: 0; y: 41; width: 36; height: 30
        glyph: "\uf028"; glyphSize: 19; iconColor: LcarsUi.grey
    }
    LcarsBattery {
        x: 40; y: 45; width: 118; height: 26
        vertical: false; present: true; percent: 30; status: "DISCHARGING"
    }
    Rectangle { x: 40; y: 102; width: 165; height: 12; color: LcarsUi.lilac }

    LcarsLabel { x: 280; y: 8; text: "EXPANDED · 30%"; size: 18; color: LcarsUi.lilac }
    LcarsIconButton {
        x: 248; y: 166; width: 42; height: 30
        glyph: "\uf028"; glyphSize: 15; iconColor: LcarsUi.grey
    }
    LcarsBattery {
        x: 300; y: 45; width: 42; height: 156
        present: true; percent: 30; status: "DISCHARGING"
    }
    Rectangle { x: 240; y: 236; width: 160; height: 12; color: LcarsUi.lilac }

    LcarsLabel { x: 540; y: 8; text: "EXPANDED · CHARGING"; size: 18; color: LcarsUi.lilac }
    LcarsBattery {
        x: 580; y: 45; width: 42; height: 156
        present: true; percent: 30; plugged: true; status: "CHARGING"
    }
    Rectangle { x: 520; y: 236; width: 160; height: 12; color: LcarsUi.lilac }
    }

    Timer {
        interval: 600; running: Quickshell.env("LCARS_CAPTURE") === "1"
        onTriggered: surface.grabToImage(result => {
            result.saveToFile("/tmp/lcars-battery-hover.png")
            Qt.quit()
        })
    }
}
