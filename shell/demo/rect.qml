import QtQuick
import QtQuick.Window

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// LcarsRect - a rectangle with four INDEPENDENT corner radii.
//
// This is the workhorse: most of the shell is this component. QtQuick's own
// Rectangle can only round all four corners together, which can't express an
// LCARS cap (rounded on its outer edge only).
//
// Run:  qs -p demo/rect.qml
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1060
    height: 560
    visible: true
    color: LcarsUi.black
    title: "LCARS // demo - LcarsRect"

    // The shell derives its scale from the SCREEN height. A demo pins it to 1
    // instead, so a component renders at the same size here as it does in the
    // shell. Without this, a 560-tall window would scale everything to half
    // size and you would misjudge every dimension you were studying.
    Binding { target: LcarsUi; property: "scale"; value: 1 }

    readonly property var cases: [
        { t: "none",       tl: 0,  tr: 0,  br: 0,  bl: 0,  note: "a plain block" },
        { t: "top-left",   tl: 46, tr: 0,  br: 0,  bl: 0,  note: "the screen-edge corner" },
        { t: "top-right",  tl: 0,  tr: 46, br: 0,  bl: 0,  note: "faces the right edge" },
        { t: "bottom-right", tl: 0, tr: 0, br: 46, bl: 0, note: "faces down + right" },
        { t: "bottom-left", tl: 0, tr: 0, br: 0, bl: 46, note: "faces down + left" },
        { t: "left side",  tl: 46, tr: 0,  br: 0,  bl: 46, note: "a right-hand cap" },
        { t: "right side", tl: 0,  tr: 46, br: 46, bl: 0,  note: "a left-hand cap" },
        { t: "clamped",    tl: 999, tr: 0, br: 999, bl: 0, note: "999 -> clamped to half" }
    ]

    LcarsLabel {
        id: heading
        x: LcarsUi.u(30)
        y: LcarsUi.u(18)
        text: "LcarsRect  -  four corners, set one at a time"
        color: LcarsUi.amber
        size: 30
        caps: false
    }

    LcarsLabel {
        x: LcarsUi.u(30)
        y: LcarsUi.u(56)
        width: LcarsUi.u(1000)
        text: "Radii are clamped to half the shorter side, so a value larger than the "
            + "box degrades to a pill instead of deforming. That matters because these "
            + "boxes are animated - a radius that fits at full size may not at half."
        color: LcarsUi.grey
        size: 20
        caps: false
        wrapMode: Text.WordWrap
    }

    Grid {
        x: LcarsUi.u(30)
        y: LcarsUi.u(130)
        columns: 4
        rowSpacing: LcarsUi.u(30)
        columnSpacing: LcarsUi.u(30)

        Repeater {
            model: win.cases

            delegate: Item {
                width: LcarsUi.u(210)
                height: LcarsUi.u(180)

                LcarsRect {
                    width: LcarsUi.u(180)
                    height: LcarsUi.u(110)
                    color: LcarsUi.gold
                    radiusTL: LcarsUi.u(modelData.tl)
                    radiusTR: LcarsUi.u(modelData.tr)
                    radiusBR: LcarsUi.u(modelData.br)
                    radiusBL: LcarsUi.u(modelData.bl)
                }

                LcarsLabel {
                    y: LcarsUi.u(122)
                    width: parent.width
                    text: modelData.t
                    color: LcarsUi.orange
                    size: 24
                    caps: false
                }

                LcarsLabel {
                    y: LcarsUi.u(148)
                    width: parent.width
                    text: modelData.note
                    color: LcarsUi.grey
                    size: 17
                    caps: false
                }
            }
        }
    }
}
