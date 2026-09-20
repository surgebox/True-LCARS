pragma Singleton

import QtQuick

//LcarsStyle - single source for palette, type and scale
//

QtObject{
    id:ui

    property real scale: 1.0

    function u(v) {return v * ui.scale} //workaround for presumed resolution consistency

    //--Custom fonts loader from local folder---
    property FontLoader _antonio: FontLoader {
        source: "../fonts/Antonio-VariableFont_wght.ttf"
    }

    property FontLoader _FinalFrontier: FontLoader{
        source: "../fonts/FinalFrontier-BEd.ttf"
    }


    //--Font--- Note: .name used for safety against mismatches.
    readonly property string antFont: _antonio.name
    readonly property string frontFont: _FinalFrontier.name 
    readonly property var fontFamilies: [antFont, frontFont, serifFont] //used as fallback if previous two fonts don't load

    //--Palette
    //--Mains--
    readonly property color black:    "#000000"
    readonly property color orange:   "#ff7700"
    readonly property color altOrange:"#c2570a" //readable orange on top of orange
    readonly property color amber:    "#ffcc66"
    readonly property color gold:     "#ffcc00"
    //Secondary
    readonly property color yellow:   "#ffb800"
    readonly property color honey:    "#ffc865"
    readonly property color peach:    "#ff9966"
    readonly property color salmon:   "#cc6666"
    readonly property color pink:     "#ef9a9a"
    readonly property color ember:    "#7a3a00"   // readable on the NET orange
    readonly property color brick:    "#b04a4a"
    readonly property color red:      "#cc3b3b"   // mute / cut-out
    readonly property color grey:     "#55555f"   // dormant: nothing to show
    readonly property color plum:     "#4e3579"   // the stardate, against the cap
    readonly property color rust:     "#c87a44"
    readonly property color violet:   "#9999ff"
    readonly property color lilac:    "#b3a6e0"
    readonly property color mauve:    "#cc99cc"
    readonly property color olive:    "#808040"
    readonly property color ice:      "#ccddff"
    readonly property color sky:      "#99ccff"
    //pkchallenge's lcars color guide:
    readonly property color spaceWhite:     "#f5f6fa"
    readonly property color bluey:     "#7788ff"
    readonly property color mars:     "#ff2200"
    readonly property color link: "#cc33ff"
    readonly property color magenta: "#cc4499"
    readonly property color almond:     "#ffaa90"

    //text on light
    readonly property color ink : "#2b1b4d"
    //text on saturated button
    readonly property color shade: "#1a1a1a"
}
