import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Effects

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// Material bench. Big samples, so the treatment can actually be judged before it
// is applied to a shell where every block is 20px tall.
//
//   ./dev/shot.sh glass-test.qml dev/shots/glass.png
//
// Left column is the flat material, right is glass, for the same set of shapes.
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1600
    height: 760
    visible: true
    color: "#000000"
    title: "LCARS // material bench"

    Binding { target: LcarsUi; property: "scale"; value: win.height / 1152 }

    readonly property var swatches: [
        { name: "brick", c: LcarsUi.brick },
        { name: "rust", c: LcarsUi.rust },
        { name: "peach", c: LcarsUi.peach },
        { name: "gold", c: LcarsUi.gold },
        { name: "violet", c: LcarsUi.violet },
        { name: "lilac", c: LcarsUi.lilac },
        { name: "mauve", c: LcarsUi.mauve },
        { name: "pink", c: LcarsUi.pink }
    ]

    // ---- flat reference across the top -------------------------------------
    Row {
        x: 30
        y: 30
        spacing: 8

        Repeater {
            model: win.swatches
            delegate: LcarsRect {
                required property var modelData
                width: 90
                height: 54
                radiusTL: 10
                radiusBL: 10
                color: modelData.c
                glass: false
            }
        }
    }

    // ---- glass, same swatches ----------------------------------------------
    Row {
        x: 30
        y: 110
        spacing: 8

        Repeater {
            model: win.swatches
            delegate: LcarsRect {
                required property var modelData
                width: 90
                height: 54
                radiusTL: 10
                radiusBL: 10
                color: modelData.c
                glass: true
            }
        }
    }

    // ---- a wide bar, flat vs glass -----------------------------------------
    LcarsStrip {
        x: 30
        y: 210
        width: 700
        height: 46
        color: LcarsUi.gold
        glass: false
    }
    LcarsStrip {
        x: 30
        y: 270
        width: 700
        height: 46
        color: LcarsUi.gold
        glass: true
    }

    // ---- elbow, flat vs glass ----------------------------------------------
    LcarsElbow {
        x: 30
        y: 350
        width: 300
        height: 150
        corner: "topLeft"
        color: LcarsUi.brick
        barThickness: 46
        columnThickness: 120
        outerRadius: 40
        innerRadius: 22
        glass: false
    }
    LcarsElbow {
        x: 360
        y: 350
        width: 300
        height: 150
        corner: "topLeft"
        color: LcarsUi.brick
        barThickness: 46
        columnThickness: 120
        outerRadius: 40
        innerRadius: 22
        glass: true
    }

    // ---- glow strength sweep on a black field ------------------------------
    Row {
        x: 720
        y: 210
        spacing: 14

        Repeater {
            model: [0.0, 0.25, 0.5, 0.8, 1.0]
            delegate: LcarsRect {
                required property var modelData
                width: 90
                height: 106
                radiusTL: 12
                radiusBR: 12
                color: LcarsUi.violet
                glass: true
                glow: modelData
            }
        }
    }

    LcarsLabel {
        x: 720
        y: 186
        width: 600
        text: "glow  0 .25 .5 .8 1.0"
        color: LcarsUi.amber
        size: 16
        caps: false
    }

    // ---- gloss strength sweep ----------------------------------------------
    Row {
        x: 720
        y: 400
        spacing: 14

        Repeater {
            model: [0.0, 0.1, 0.2, 0.35, 0.55]
            delegate: LcarsRect {
                required property var modelData
                width: 90
                height: 106
                radiusTL: 12
                radiusBR: 12
                color: LcarsUi.peach
                glass: true
                gloss: modelData
            }
        }
    }

    LcarsLabel {
        x: 720
        y: 376
        width: 600
        text: "gloss  0 .1 .2 .35 .55"
        color: LcarsUi.amber
        size: 16
        caps: false
    }

    LcarsLabel {
        x: 30
        y: 10
        text: "FLAT"
        color: LcarsUi.orange
        size: 14
    }
    LcarsLabel {
        x: 30
        y: 92
        text: "GLASS"
        color: LcarsUi.orange
        size: 14
    }
}
