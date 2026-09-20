pragma Singleton

import QtQuick

// ---------------------------------------------------------------------------
// LcarsUi - the single source of truth for palette, type and scale.
//
// `scale` is written by the root window (height / 1152) so every component can
// express itself in *design units* for a 2048x1152 canvas and still look right
// on any resolution. Read it as `LcarsUi.scale`, or use the `u()` helper.
// ---------------------------------------------------------------------------
QtObject {
    id: ui

    // -- scale -----------------------------------------------------------------
    property real scale: 1.0

    // design units -> device pixels
    function u(v) { return v * ui.scale }

    // -- material --------------------------------------------------------------
    // One switch for the whole shell: solid painted blocks, or backlit glass.
    // Flipping this restyles every strip, elbow, button and capsule at once,
    // because they all derive their face from these four functions.
    property bool glass: true

    // Blend two colours; t = 0 gives a, t = 1 gives b.
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t)
    }

    // Soften: pull the saturation down a little and leave the value alone, so a
    // block that was a bold solid reads as a tinted pane rather than paint.
    // Deliberately gentle - stained glass is rich, it is the *lighting* that
    // changes, not the pigment.
    function glassFace(c) {
        return Qt.hsla(c.hslHue,
                       Math.max(0, Math.min(1, c.hslSaturation * 0.86)),
                       Math.max(0, Math.min(1, c.hslLightness * 1.02)),
                       c.a)
    }

    // The top of a pane catches the light...
    function glassHi(c) {
        const f = glassFace(c)
        // capped: without a ceiling the pale alloys (lilac, pink, ice) blow all
        // the way out to white and the whole column goes milky
        return Qt.hsla(f.hslHue,
                       Math.max(0, Math.min(1, f.hslSaturation * 0.78)),
                       Math.min(0.88, f.hslLightness * 1.26),
                       f.a)
    }

    // ...and the bottom sits in its own shadow, which is what gives the block a
    // front and a back instead of reading flat.
    function glassLo(c) {
        const f = glassFace(c)
        return Qt.hsla(f.hslHue,
                       Math.max(0, Math.min(1, f.hslSaturation * 1.0)),
                       Math.max(0, Math.min(1, f.hslLightness * 0.66)),
                       f.a)
    }

    // The light that escapes around the edge onto the black behind it. This is
    // the part that actually sells "there is a lamp behind this".
    function glassGlow(c, a) {
        const f = glassFace(c)
        return Qt.rgba(f.r, f.g, f.b, a === undefined ? 0.6 : a)
    }

    // How much of the treatment a block of this height gets. A 16-unit band has
    // barely any surface to catch light, so it stays nearly flat; a tall panel
    // gets the full rendering. Without this every short bar would smear
    // light-to-dark across its own height and read as mud.
    function glassDepth(px) {
        return Math.max(0, Math.min(1, px / (glassDepthRef * scale)))
    }
    readonly property real glassDepthRef: 78

    // -- type ------------------------------------------------------------------
    readonly property string font: "Antonio"
    readonly property string fontMono: "JetBrainsMono NF"

    // -- palette ---------------------------------------------------------------
    // Classic LCARS: a warm orange core, surrounded by saturated pastel blocks.
    readonly property color black:    "#000000"
    readonly property color orange:   "#ff9c00"   // signature LCARS orange
    readonly property color orangeDk: "#c2570a"   // orange readable on orange
    readonly property color amber:    "#ffcc66"
    readonly property color gold:     "#ffcc00"
    // Project-Eve's header-bar pair: the bar's own yellow and its title ink,
    // which is a touch lighter so the floating title reads against it.
    readonly property color yellow:   "#ffb800"
    readonly property color honey:    "#ffc865"
    readonly property color peach:    "#ff9966"
    readonly property color salmon:   "#cc6666"
    readonly property color pink:     "#ef9a9a"
    readonly property color ember:    "#7a3a00"   // readable on the NET orange
    readonly property color brick:    "#b04a4a"
    readonly property color rust:     "#c87a44"
    readonly property color violet:   "#9999ff"
    readonly property color lilac:    "#b3a6e0"
    readonly property color mauve:    "#cc99cc"
    readonly property color olive:    "#808040"
    readonly property color ice:      "#ccddff"
    readonly property color sky:      "#99ccff"

    // text on a light cap
    readonly property color ink:      "#2b1b4d"
    // text on a saturated button
    readonly property color shade:    "#1a1a1a"
}
