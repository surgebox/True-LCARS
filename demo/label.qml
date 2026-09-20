import QtQuick
import QtQuick.Window

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// LcarsLabel - text in the LCARS face, sized in DESIGN units.
//
//   size      design units, not pixels - LcarsUi.u() does the conversion
//   caps      upper-case it (on by default; LCARS is nearly all caps)
//   tracking  letter-spacing, which is what makes it read as LCARS
//   fit       shrink the text to the item's width instead of overflowing
//   weight    Font.Light .. Font.Bold
//
// Run:  qs -p demo/label.qml
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1060
    height: 620
    visible: true
    color: LcarsUi.black
    title: "LCARS // demo - LcarsLabel"

    // The shell derives its scale from the SCREEN height. A demo pins it to 1
    // instead, so a component renders at the same size here as it does in the
    // shell. Without this, a 560-tall window would scale everything to half
    // size and you would misjudge every dimension you were studying.
    Binding { target: LcarsUi; property: "scale"; value: 1 }

    Column {
        x: LcarsUi.u(30)
        y: LcarsUi.u(20)
        spacing: LcarsUi.u(14)

        LcarsLabel {
            text: "LcarsLabel"
            color: LcarsUi.amber
            size: 34
        }

        // ---- size is in design units, so it scales with the window ---------
        LcarsLabel {
            text: "size 60"
            color: LcarsUi.gold
            size: 60
        }
        LcarsLabel {
            text: "size 40"
            color: LcarsUi.gold
            size: 40
        }
        LcarsLabel {
            text: "size 24"
            color: LcarsUi.gold
            size: 24
        }

        Item { width: 1; height: LcarsUi.u(10) }

        // ---- caps and tracking --------------------------------------------
        LcarsLabel {
            text: "caps on, tracking off - reads flat"
            color: LcarsUi.peach
            size: 26
            caps: true
            tracking: false
        }
        LcarsLabel {
            text: "caps on, tracking on - reads LCARS"
            color: LcarsUi.peach
            size: 26
            caps: true
            tracking: true
        }
        LcarsLabel {
            text: "caps off, mixed case passes through"
            color: LcarsUi.peach
            size: 26
            caps: false
        }

        Item { width: 1; height: LcarsUi.u(10) }

        // ---- weight --------------------------------------------------------
        Row {
            spacing: LcarsUi.u(24)
            LcarsLabel { text: "light";     color: LcarsUi.violet; size: 30; weight: Font.Light }
            LcarsLabel { text: "regular";   color: LcarsUi.violet; size: 30; weight: Font.Normal }
            LcarsLabel { text: "demibold";  color: LcarsUi.violet; size: 30; weight: Font.DemiBold }
            LcarsLabel { text: "bold";      color: LcarsUi.violet; size: 30; weight: Font.Bold }
        }

        Item { width: 1; height: LcarsUi.u(10) }

        // ---- fit -------------------------------------------------------------
        // Both boxes are 300 wide. Without fit, the text runs past the edge;
        // with it, the size is reduced until it fits. This is how the shell
        // survives long values like a 9-character disk reading.
        LcarsLabel {
            text: "without fit - this overflows"
            color: LcarsUi.ember
            size: 34
            caps: false
            width: LcarsUi.u(300)
        }
        LcarsLabel {
            text: "with fit - shrinks to the box"
            color: LcarsUi.ember
            size: 34
            caps: false
            fit: true
            width: LcarsUi.u(300)
        }
    }
}
