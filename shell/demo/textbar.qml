import QtQuick
import QtQuick.Window

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// LcarsTextBar - the "HELLO <NAME>" bar.
//
//   text      the title; the caps are sized to the ink, not to a font size
//   accent    the caps and the long bar
//   ink       the title's colour (normally a shade of the accent)
//   barHeight / capWidth / gap    the three dimensions that define the shape
//
// The trick is that the type size is SOLVED from a TextMetrics ink box rather
// than picked, so the caps stay exactly as tall as the text at any size. That
// is why it can be resized without the letters swimming in their caps.
//
// Run:  qs -p demo/textbar.qml
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1200
    height: 560
    visible: true
    color: LcarsUi.black
    title: "LCARS // demo - LcarsTextBar"

    // The shell derives its scale from the SCREEN height. A demo pins it to 1
    // instead, so a component renders at the same size here as it does in the
    // shell. Without this, a 560-tall window would scale everything to half
    // size and you would misjudge every dimension you were studying.
    Binding { target: LcarsUi; property: "scale"; value: 1 }

    Column {
        x: LcarsUi.u(24)
        y: LcarsUi.u(24)
        spacing: LcarsUi.u(30)

        LcarsLabel {
            text: "default - yellow accent, honey ink, power button on"
            color: LcarsUi.grey
            size: 20
            caps: false
        }

        LcarsTextBar {
            width: LcarsUi.u(1150)
            text: "Hello Henry"
        }

        LcarsLabel {
            text: "powerButton: false - the right cap is inert again"
            color: LcarsUi.grey
            size: 20
            caps: false
        }

        LcarsTextBar {
            width: LcarsUi.u(1150)
            text: "Hello Henry"
            powerButton: false
        }

        LcarsLabel {
            text: "a different accent, a shorter bar"
            color: LcarsUi.grey
            size: 20
            caps: false
        }

        LcarsTextBar {
            width: LcarsUi.u(760)
            text: "Lcars"
            accent: LcarsUi.violet
            ink: LcarsUi.lilac
        }

        LcarsLabel {
            text: "barHeight 80 - everything is derived from it"
            color: LcarsUi.grey
            size: 20
            caps: false
        }

        LcarsTextBar {
            width: LcarsUi.u(900)
            text: "Hello Henry"
            barHeight: 80
        }
    }
}
