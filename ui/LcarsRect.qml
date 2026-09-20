import QtQuick
import QtQuick.Shapes

// ---------------------------------------------------------------------------
// LcarsRect - a rectangle with four independent corner radii, an optional
// outline, and an optional hit area.
//
// LCARS blocks are almost never uniformly rounded: a cap is rounded on its
// outer edge only, a strip is square, a footer segment is rounded on the end
// that faces the screen edge. QtQuick's Rectangle can't express that, so this
// wraps a Shape whose path is generated as SVG.
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

    preferredRendererType: Shape.CurveRenderer
    asynchronous: false
    antialiasing: true

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

    ShapePath {
        fillColor: root.color
        strokeColor: root.borderColor
        strokeWidth: root.borderWidth
        joinStyle: ShapePath.MiterJoin
        PathSvg { path: root.pathString() }
    }
}
