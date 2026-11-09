import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsVolumeBarH - the collapsed panel's volume control.
//
// Idle it is a single block whose colour *is* the reading.Click it and it
// becomes a horizontal meter you can drag - the same ramp as the vertical one
// (green at the quiet end, red at the loud), laid on its side. It folds back to
// the block on its own after `idleMs` of no interaction.
//
// This component owns both its `open` state and its own width, because the
// layout around it depends on how wide it currently is: it exposes
// `designWidth`, which the shell uses to place whatever sits to its right, so
// the neighbours ride along as it opens rather than being overlapped.
// ---------------------------------------------------------------------------
Item {
    id: root

    property real level: 0.5
    property bool muted: false

    property int boxes: 12
    property int idleBoxes: 4   // the idle block, cut into this many segments
    property real gap: 2
    property int idleMs: 5000

    // open state and geometry, in design units
    property bool open: false
    property real compactW: 46
    property real openW: 200
    property real designWidth: open ? openW : compactW

    signal moved(real level)
    signal committed(real level)

    width: LcarsUi.u(designWidth)

    Behavior on designWidth {
        NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
    }

    readonly property real gapPx: LcarsUi.u(gap)
    readonly property real boxW: Math.max(1, (width - gapPx * (boxes - 1)) / boxes)
    // what the meter actually shows: muting empties it
    readonly property real shown: muted ? 0 : Math.max(0, Math.min(1, level))
    readonly property int litCount: Math.max(0, Math.min(boxes, Math.round(shown * boxes)))

    // the colour of the highest lit box, so the speaker and the block agree
    readonly property color levelColor: {
        if (litCount <= 0 || boxes <= 1)
            return LcarsUi.grey
        const frac = (litCount - 1) / (boxes - 1)
        return Qt.hsla(120 * (1 - frac) / 360, 1.0, 0.5, 1)
    }

    // Collapse again once the user stops touching it.
    Timer {
        id: idle
        interval: root.idleMs
        onTriggered: root.open = false
    }

    function touch() {
        if (root.open)
            idle.restart()
    }

    // ---- idle: one block, cut into segments so it reads as boxes ---------
    // Deliberately 4 rather than the meter's 12: at 46 wide, 12 segments would
    // leave more gap than box and it would read as a comb, not a block.
    Repeater {
        model: root.idleBoxes

        delegate: Rectangle {
            readonly property real segW:
                (root.width - root.gapPx * (root.idleBoxes - 1)) / root.idleBoxes

            x: index * (segW + root.gapPx)
            width: segW
            height: root.height
            // A slight lightness ramp across the segments - the same colour, but
            // not one flat slab, so it reads as four boxes rather than a hole
            // punched in the black.
            color: {
                const base = root.levelColor
                const t = root.idleBoxes > 1 ? index / (root.idleBoxes - 1) : 0
                return Qt.hsla(base.hslHue, base.hslSaturation,
                               Math.max(0, Math.min(1, base.hslLightness * (0.84 + 0.32 * t))),
                               base.a)
            }
            opacity: root.open ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // ---- open: the ramp, on its side ------------------------------------
    Repeater {
        model: root.boxes

        delegate: Rectangle {
            readonly property real frac: root.boxes > 1 ? index / (root.boxes - 1) : 0

            x: index * (root.boxW + root.gapPx)
            width: root.boxW
            height: root.height
            color: (index + 1) <= root.litCount
                   ? Qt.hsla(120 * (1 - frac) / 360, 1.0, 0.5, 1)
                   : Qt.hsla(120 * (1 - frac) / 360, 1.0, 0.5, 0.18)
            // cross-fade rather than a hard swap, so the block dissolves into
            // the meter as the width animates
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.open ? Qt.SizeHorCursor : Qt.PointingHandCursor

        function report(x) {
            root.moved(Math.max(0, Math.min(1, x / root.width)))
        }

        onPressed: (m) => {
            if (!root.open) {
                // first click just opens it - it must not also jump the volume
                // to wherever the cursor happened to land
                root.open = true
                idle.restart()
                return
            }
            report(m.x)
            touch()
        }
        onPositionChanged: (m) => {
            if (pressed && root.open) {
                report(m.x)
                touch()
            }
        }
        // push once on release, not on every pixel of the drag
        onReleased: {
            if (root.open) {
                root.committed(root.level)
                touch()
            }
        }
    }
}
