import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../theme"

// ---------------------------------------------------------------------------
// LcarsRect - a rectangle with four independent corner radii, an optional
// outline, and an optional hit area.
//
// LCARS blocks are almost never uniformly rounded: a cap is rounded on its
// outer edge only, a strip is square, a footer segment is rounded on the end
// that faces the screen edge. QtQuick's Rectangle can't express that, so this
// wraps a Shape whose path is generated as SVG.
//
// `glass` swaps the flat fill for a backlit-pane treatment:
//
//   * the face is softened (see LcarsUi.glassFace) - less saturation, a touch
//     lighter, so it reads as tinted glass rather than paint
//   * a vertical gradient gives it a lit top and a shadowed bottom, so the
//     block has a front and a back instead of being flat
//   * a specular band across the top reads as a reflection
//   * a coloured glow bleeds light onto the black behind it
//   * a hair of blur softens the edge off the pixel grid
//
// The glow is the expensive part: it needs an offscreen layer per shape. Turn
// `LcarsUi.glass` off and none of it is allocated.
// ---------------------------------------------------------------------------
Shape {
    id: root

    property color color: "#ff9c00"
    property real radiusTL: 0
    property real radiusTR: 0
    property real radiusBR: 0
    property real radiusBL: 0

    property color borderColor: "transparent"
    property real borderWidth: 0

    property bool glass: LcarsUi.glass
    property real gloss: 0.20      // specular strength
    property real glow: 0.30       // how much light spills onto the black

    preferredRendererType: Shape.CurveRenderer
    asynchronous: false
    antialiasing: true

    // ---- material ----------------------------------------------------------
    readonly property real depth: LcarsUi.glassDepth(height)
    readonly property color face: glass ? LcarsUi.glassFace(color) : color
    readonly property color faceTop:
        glass ? LcarsUi.mix(face, LcarsUi.glassHi(color), depth) : color
    readonly property color faceBottom:
        glass ? LcarsUi.mix(face, LcarsUi.glassLo(color), depth) : color
    // the highlight and shadow bands are a fixed depth rather than a fixed
    // fraction, so every block is lit the same way regardless of its height
    readonly property real hiStop:
        Math.max(0.02, Math.min(0.5, LcarsUi.u(22) / Math.max(1, height)))
    readonly property real loStop: Math.max(hiStop + 0.02, 1 - LcarsUi.u(16) / Math.max(1, height))

    layer.enabled: glass
    layer.effect: MultiEffect {
        autoPaddingEnabled: true
        blurEnabled: true
        blur: 0.05
        blurMax: 20
        shadowEnabled: true
        shadowColor: LcarsUi.glassGlow(root.color, root.glow)
        shadowBlur: 0.55
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    // radii clamped so they can never exceed the box (or each other)
    readonly property real _lim: Math.min(width, height) / 2
    readonly property real tl: Math.max(0, Math.min(radiusTL, _lim))
    readonly property real tr: Math.max(0, Math.min(radiusTR, _lim))
    readonly property real br: Math.max(0, Math.min(radiusBR, _lim))
    readonly property real bl: Math.max(0, Math.min(radiusBL, _lim))

    function pathString() {
        const w = width
        const h = height
        let p = "M " + tl + " 0 "
        p += "L " + (w - tr) + " 0 "
        if (tr > 0) p += "A " + tr + " " + tr + " 0 0 1 " + w + " " + tr + " "
        p += "L " + w + " " + (h - br) + " "
        if (br > 0) p += "A " + br + " " + br + " 0 0 1 " + (w - br) + " " + h + " "
        p += "L " + bl + " " + h + " "
        if (bl > 0) p += "A " + bl + " " + bl + " 0 0 1 0 " + (h - bl) + " "
        p += "L 0 " + tl + " "
        if (tl > 0) p += "A " + tl + " " + tl + " 0 0 1 " + tl + " 0 "
        p += "Z"
        return p
    }

    // ---- the pane ----------------------------------------------------------
    ShapePath {
        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: 0
            y2: root.height
            GradientStop { position: 0.00; color: root.faceTop }
            GradientStop { position: root.hiStop; color: root.face }
            GradientStop { position: root.loStop; color: root.face }
            GradientStop { position: 1.00; color: root.faceBottom }
        }
        strokeColor: root.borderColor
        strokeWidth: root.borderWidth
        joinStyle: ShapePath.MiterJoin
        PathSvg { path: root.pathString() }
    }

    // ---- the reflection ----------------------------------------------------
    ShapePath {
        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: 0
            y2: root.height
            GradientStop {
                position: 0.00
                color: root.glass ? Qt.rgba(1, 1, 1, root.gloss * root.depth) : "transparent"
            }
            GradientStop { position: 0.34; color: "transparent" }
        }
        PathSvg { path: root.pathString() }
    }
}
