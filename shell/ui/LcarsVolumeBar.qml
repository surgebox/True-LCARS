import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsVolumeBar - a vertical LCARS level meter you can drag.
//
// A stack of pills, green at the bottom climbing through yellow to red at the
// top, so "loud" reads red the way a VU meter does. A pill is lit when the
// level reaches it; the rest stay as a dim tint of their own hue, so the whole
// scale stays visible and the widget reads as a gauge rather than a bar chart.
//
// Dragging sets the level absolutely (jump to where you pressed, then follow),
// and the level is reported live on every move - the caller decides when to
// actually push it to the audio server, which it should only do on release.
// ---------------------------------------------------------------------------
Item {
    id: root

    property real level: 0.5      // 0..1
    property int bars: 12
    property real gap: 3          // design units between pills
    property real radius: 3
    property bool muted: false    // draws at zero without losing the level

    signal moved(real level)
    signal committed(real level)   // released - now push it to the audio server

    readonly property real gapPx: LcarsUi.u(gap)

    // How many boxes the level lights. The topmost lit box is what defines the
    // meter's current colour.
    readonly property int litCount:
        Math.max(0, Math.min(bars, Math.round(shown * bars)))

    // The colour of the topmost lit box - exposed so anything else that wants to
    // agree with the meter (the speaker glyph, say) asks the meter rather than
    // reimplementing the ramp and drifting from it.
    //
    // With nothing lit there is no "topmost" box to quote, so it goes dormant
    // grey rather than the bottom of the ramp: a green speaker at zero volume
    // reads as "quiet", when it should read as "off".
    readonly property color levelColor: {
        if (litCount <= 0 || bars <= 1)
            return LcarsUi.grey
        const frac = (litCount - 1) / (bars - 1)
        return Qt.hsla(120 * (1 - frac) / 360, 1.0, 0.5, 1)
    }
    readonly property real barH: Math.max(1, (height - gapPx * (bars - 1)) / bars)
    // what the meter actually shows: muting empties it
    readonly property real shown: muted ? 0 : Math.max(0, Math.min(1, level))

    Repeater {
        model: root.bars

        delegate: Rectangle {
            // index 0 is the bottom pill
            readonly property real frac: root.bars > 1 ? index / (root.bars - 1) : 0

            x: 0
            y: root.height - (index + 1) * root.barH - index * root.gapPx
            width: root.width
            height: root.barH
            radius: LcarsUi.u(root.radius)

            // hue 120 (green) at the bottom -> 0 (red) at the top
            readonly property color hue: Qt.hsla(120 * (1 - frac) / 360, 1.0, 0.5, 1)
            color: (index + 1) <= root.litCount
                   ? hue
                   : Qt.hsla(120 * (1 - frac) / 360, 1.0, 0.5, 0.18)
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeVerCursor
        preventStealing: true

        function report(y) {
            root.moved(Math.max(0, Math.min(1, 1 - y / root.height)))
        }

        onPressed: (m) => report(m.y)
        onPositionChanged: (m) => {
            if (pressed)
                report(m.y)
        }
        // push once on release, not on every pixel of the drag
        onReleased: root.committed(root.level)
    }
}
