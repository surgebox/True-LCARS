import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsLabel - Text pre-set with the LCARS face and design-unit sizing.
// `size` is in design units (2048x1152 canvas), not pixels.
// ---------------------------------------------------------------------------
Text {
    id: root

    property real size: 28
    property bool caps: true
    property bool tracking: false
    // shrink to the item's width instead of overflowing it
    property bool fit: false

    font.family: LcarsUi.font
    font.pixelSize: Math.round(LcarsUi.u(size))
    font.weight: Font.DemiBold
    font.letterSpacing: tracking ? LcarsUi.u(size) * 0.03 : 0
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    fontSizeMode: fit ? Text.HorizontalFit : Text.FixedSize
    minimumPixelSize: fit ? Math.round(LcarsUi.u(10)) : 1
    color: LcarsUi.orange
    verticalAlignment: Text.AlignVCenter
}
