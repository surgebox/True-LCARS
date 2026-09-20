import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsTextBar - the full-width header strip, ported from Project-Eve.
//
//   [cap]  gap  [ FLOATING TITLE ]  gap  [ long bar ]  gap  [cap]
//
// Both end caps share the accent colour and are rounded on their OUTER face
// only. They are wider than they are tall, so they read as a pill segment
// rather than a half-circle. `LcarsRect`'s per-corner radii give that directly
// - Project-Eve needed a second rectangle per cap to square off the inner
// face, which is no longer necessary.
//
// The title floats straight on the backdrop with no box behind it, and its type
// size is *solved*, not set: the font's real ink box is measured at a reference
// 100px and the size that makes the capitals exactly `textFill` of the bar
// height is derived from it. That is what makes the text as tall as the strip
// and keeps equal padding above and below, and it keeps working if the font
// changes. `textFill` is the only knob.
//
// Every metric is in design units, so the whole bar scales with the screen.
// ---------------------------------------------------------------------------
Item {
    id: root

    // ---- public inputs -----------------------------------------------------
    property string text: ""
    property color backdrop: LcarsUi.black    // the strip behind everything
    property color accent: LcarsUi.yellow     // caps + the long bar
    property color ink: LcarsUi.honey         // the floating title

    property real barHeight: 56               // the caps/bar/text zone
    property real capWidth: 80                // cap length
    property real gap: 12                     // crisp backdrop slice between pieces
    property real letterSpacing: 4            // tracking, in design units
    property real textFill: 0.92              // ink height / barHeight

    readonly property real barH: LcarsUi.u(barHeight)

    implicitHeight: barH

    // ---- type sizing -------------------------------------------------------
    // The font table's cap-height constants do not match what Qt actually
    // draws, so measure instead.
    FontMetrics {
        id: fm
        font.family: LcarsUi.font
        font.pixelSize: 100
        font.weight: Font.Bold
    }

    TextMetrics {
        id: inkMetrics
        font.family: LcarsUi.font
        font.pixelSize: 100
        font.weight: Font.Bold
        text: root.text
    }

    readonly property real inkRatio: Math.max(0.001, inkMetrics.tightBoundingRect.height / 100)
    readonly property real ascRatio: fm.ascent / 100

    // device-pixel size whose real ink height comes out as barH * textFill
    readonly property real fontPx: Math.max(10, Math.round(barH * textFill / inkRatio))

    // ---- the bar -----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: root.backdrop
    }

    // left cap - rounded on its outer (left) face only
    LcarsRect {
        id: leftCap
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: LcarsUi.u(root.capWidth)
        height: root.barH
        color: root.accent
        radiusTL: height / 2
        radiusBL: height / 2
    }

    // the floating title - its real ink box is centred on the bar, so the
    // padding above and below the capitals is equal
    Text {
        id: titleLabel

        x: leftCap.x + leftCap.width + LcarsUi.u(root.gap)
        // baseline = bar centre + inkHeight/2
        y: root.height / 2
           + root.fontPx * root.inkRatio / 2
           - root.fontPx * root.ascRatio

        text: root.text
        color: root.ink
        font.family: LcarsUi.font
        font.pixelSize: root.fontPx
        font.weight: Font.Bold
        font.letterSpacing: LcarsUi.u(root.letterSpacing)
        font.capitalization: Font.AllUppercase
        renderType: Text.NativeRendering
    }

    // the long square-ended run, filling whatever is left between the title
    // and the right cap
    LcarsRect {
        anchors.left: titleLabel.right
        anchors.leftMargin: LcarsUi.u(root.gap)
        anchors.right: rightCap.left
        anchors.rightMargin: LcarsUi.u(root.gap)
        anchors.verticalCenter: parent.verticalCenter
        height: root.barH
        color: root.accent
    }

    // right cap - rounded on its outer (right) face only
    LcarsRect {
        id: rightCap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: LcarsUi.u(root.capWidth)
        height: root.barH
        color: root.accent
        radiusTR: height / 2
        radiusBR: height / 2
    }
}
