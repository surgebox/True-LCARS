import QtQuick
import QtQuick.Window

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// LcarsStrip - a horizontal bar, which is what a band segment is.
//
//   capLeft / capRight   turn an END into a half-round cap
//   round                give the square corners a uniform radius
//
// LCARS strips are square-ended by default. The caps are what make a bar read
// as "this is the end of a run" rather than "this continues off-screen".
//
// Run:  qs -p demo/strip.qml
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1060
    height: 520
    visible: true
    color: LcarsUi.black
    title: "LCARS // demo - LcarsStrip"

    // The shell derives its scale from the SCREEN height. A demo pins it to 1
    // instead, so a component renders at the same size here as it does in the
    // shell. Without this, a 560-tall window would scale everything to half
    // size and you would misjudge every dimension you were studying.
    Binding { target: LcarsUi; property: "scale"; value: 1 }

    readonly property var cases: [
        { t: "plain",     cl: false, cr: false, r: 0,  c: LcarsUi.gold },
        { t: "capLeft",   cl: true,  cr: false, r: 0,  c: LcarsUi.peach },
        { t: "capRight",  cl: false, cr: true,  r: 0,  c: LcarsUi.violet },
        { t: "both caps", cl: true,  cr: true,  r: 0,  c: LcarsUi.mauve },
        { t: "round 24",  cl: false, cr: false, r: 24, c: LcarsUi.rust }
    ]

    LcarsLabel {
        x: LcarsUi.u(30)
        y: LcarsUi.u(18)
        text: "LcarsStrip  -  a bar, with optional end caps"
        color: LcarsUi.amber
        size: 30
        caps: false
    }

    Column {
        x: LcarsUi.u(30)
        y: LcarsUi.u(80)
        spacing: LcarsUi.u(24)

        Repeater {
            model: win.cases

            delegate: Row {
                spacing: LcarsUi.u(24)

                LcarsStrip {
                    width: LcarsUi.u(460)
                    height: LcarsUi.u(48)
                    color: modelData.c
                    capLeft: modelData.cl
                    capRight: modelData.cr
                    round: LcarsUi.u(modelData.r)
                }

                LcarsLabel {
                    width: LcarsUi.u(220)
                    height: LcarsUi.u(48)
                    text: modelData.t
                    color: LcarsUi.grey
                    size: 22
                    caps: false
                }
            }
        }
    }

    LcarsLabel {
        x: LcarsUi.u(30)
        y: LcarsUi.u(430)
        width: LcarsUi.u(1000)
        text: "The caps are height/2, so they stay round at any thickness - which "
            + "is what makes them safe to animate."
        color: LcarsUi.grey
        size: 20
        caps: false
        wrapMode: Text.WordWrap
    }
}
