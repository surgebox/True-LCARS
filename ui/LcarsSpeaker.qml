import QtQuick
import QtQuick.Shapes
import "../theme"

// ---------------------------------------------------------------------------
// LcarsSpeaker - a volume glyph that is drawn rather than borrowed.
//
// Every icon font on this machine caps out at three wave counts (Font Awesome:
// none / one / two; Material Symbols the same three under different names).
// Drawing it makes the wave count a number instead of a choice between glyphs,
// and lets the arcs be spaced to whatever reads best at this size.
//
// Waves are concentric arcs off the mouth of the cone, so they grow outward the
// way a sound wave would. The space for `maxWaves` is reserved in the layout
// even when fewer are showing, so the body stays put instead of sliding as the
// count changes.
// ---------------------------------------------------------------------------
Item {
    id: root

    property color color: LcarsUi.violet
    property int waves: 2
    property int maxWaves: 4
    property real weight: 0.115        // stroke, as a fraction of the body height

    // The glyph sizes off its height and the drawing comes out about 1.6x as
    // wide, so it fits whatever box it is given without distorting.
    readonly property real h: Math.max(1, Math.min(height, width / 1.6))
    readonly property real cy: height / 2
    readonly property real r0: h * 0.58
    readonly property real dr: h * 0.155
    readonly property real stroke: Math.max(1, h * weight)
    readonly property real span: 46 * Math.PI / 180

    readonly property real bodyW: h * 0.50
    readonly property real fullW: bodyW + (r0 + (maxWaves - 1) * dr) + stroke
    readonly property real ox: (width - fullW) / 2

    function bodyPath() {
        const c = root.cy
        const s = root.h
        const x = root.ox
        return "M " + x + " " + (c - 0.16 * s)
             + " L " + (x + 0.22 * s) + " " + (c - 0.16 * s)
             + " L " + (x + 0.50 * s) + " " + (c - 0.42 * s)
             + " L " + (x + 0.50 * s) + " " + (c + 0.42 * s)
             + " L " + (x + 0.22 * s) + " " + (c + 0.16 * s)
             + " L " + x + " " + (c + 0.16 * s)
             + " Z"
    }

    function wavePath() {
        let p = ""
        const cx = root.ox + root.bodyW
        for (let i = 0; i < root.waves; i++) {
            const r = root.r0 + i * root.dr
            const x0 = cx + r * Math.cos(-root.span)
            const y0 = root.cy + r * Math.sin(-root.span)
            const x1 = cx + r * Math.cos(root.span)
            const y1 = root.cy + r * Math.sin(root.span)
            p += "M " + x0 + " " + y0
               + " A " + r + " " + r + " 0 0 1 " + x1 + " " + y1 + " "
        }
        return p
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        antialiasing: true

        // the cone
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg { path: root.bodyPath() }
        }

        // the waves
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.stroke
            PathSvg { path: root.wavePath() }
        }
    }
}
