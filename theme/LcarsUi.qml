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
    readonly property color red:      "#cc3b3b"   // mute / cut-out
    readonly property color green:    "#55cc88"   // active / enabled
    readonly property color grey:     "#55555f"   // dormant: nothing to show
    readonly property color plum:     "#4e3579"   // the stardate, against the cap
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
