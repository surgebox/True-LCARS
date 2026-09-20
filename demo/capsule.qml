import QtQuick
import QtQuick.Window

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// LcarsCapsule - the CPU / MEM / NET / DSK readout pills.
//
//   label / value        the two strings
//   labelColor/valueColor  they are usually the same dark ink
//   radiusFactor         corner radius as a fraction of the height (0.42 = pill)
//   valueFit             shrink the value so a long reading never overflows
//
// The whole point of `valueFit` is the last row: a 9-character disk reading has
// to sit in the same box as a 2-character CPU percentage without either the
// box or the font size changing.
//
// Run:  qs -p demo/capsule.qml
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1060
    height: 520
    visible: true
    color: LcarsUi.black
    title: "LCARS // demo - LcarsCapsule"

    // The shell derives its scale from the SCREEN height. A demo pins it to 1
    // instead, so a component renders at the same size here as it does in the
    // shell. Without this, a 560-tall window would scale everything to half
    // size and you would misjudge every dimension you were studying.
    Binding { target: LcarsUi; property: "scale"; value: 1 }

    LcarsLabel {
        x: LcarsUi.u(30)
        y: LcarsUi.u(18)
        text: "LcarsCapsule  -  a label and a value in one pill"
        color: LcarsUi.amber
        size: 30
        caps: false
    }

    Column {
        x: LcarsUi.u(30)
        y: LcarsUi.u(80)
        spacing: LcarsUi.u(18)

        LcarsCapsule {
            width: LcarsUi.u(440)
            height: LcarsUi.u(52)
            label: "CPU"
            value: "9%"
            color: LcarsUi.violet
        }

        LcarsCapsule {
            width: LcarsUi.u(440)
            height: LcarsUi.u(52)
            label: "MEM"
            value: "9GB/15GB"
            color: LcarsUi.salmon
        }

        LcarsCapsule {
            width: LcarsUi.u(440)
            height: LcarsUi.u(52)
            label: "NET"
            value: "5G-NET 12KB/S"
            color: LcarsUi.amber
        }

        LcarsCapsule {
            width: LcarsUi.u(440)
            height: LcarsUi.u(52)
            label: "DSK"
            value: "49GB/86GB"
            color: LcarsUi.violet
        }

        Item { width: 1; height: LcarsUi.u(14) }

        // The same width, three very different value lengths. Only the value
        // text changes size; the pill never does.
        Row {
            spacing: LcarsUi.u(20)
            LcarsCapsule { width: LcarsUi.u(210); height: LcarsUi.u(50); label: "DSK"; value: "49GB/86GB"; color: LcarsUi.violet }
            LcarsCapsule { width: LcarsUi.u(210); height: LcarsUi.u(50); label: "DSK"; value: "12MB";      color: LcarsUi.violet }
            LcarsCapsule { width: LcarsUi.u(210); height: LcarsUi.u(50); label: "DSK"; value: "999GB/999GB"; color: LcarsUi.violet }
        }
    }
}
