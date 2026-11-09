import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsIconButton - a bare glyph button, with two gestures and two states.
//
//   click       -> clicked()      on release, if the hold never fired
//   press+hold  -> held()         once, after `holdMs`
//
// Releasing after a hold does NOT also fire clicked(). That matters: a menu
// opening and then immediately toggling the thing would be maddening.
//
// Visually there is no button until there is something to say. Idle, it is just
// a coloured glyph sitting on the black. `active` (muted, in the volume widget)
// brings up a solid block behind it and cuts the glyph through with a bar - so
// the control only asserts itself when the state is not the default one.
//
// The glyph uses an icon font (Font Awesome), not the LCARS display face, so it
// takes its own font family.
// ---------------------------------------------------------------------------
Item {
    id: root

    property string glyph: "\uf025"                  // Font Awesome fallback
    property string iconFont: "Font Awesome 7 Free Solid"
    // Supply a component here to draw the icon instead of typing a glyph - the
    // volume speaker needs a wave count that no font provides.
    property Component icon: null
    property real glyphSize: 24

    property color iconColor: LcarsUi.violet         // the idle glyph

    property bool active: false                      // e.g. muted
    property color activeColor: LcarsUi.red          // the block that appears
    property color activeIconColor: LcarsUi.shade
    property real slashWidth: 4                      // the bar that cuts through

    property int holdMs: 450

    signal clicked()
    signal held()

    // internal: did the hold already fire for this press?
    property bool holdFired: false

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    Item {
        id: content
        anchors.fill: parent
        opacity: root.pressed ? 0.55 : (root.hovered ? 0.82 : 1.0)

        Behavior on opacity { NumberAnimation { duration: 90 } }

        // ---- the block: only exists while active ---------------------------
        LcarsRect {
            anchors.fill: parent
            visible: root.active
            color: root.activeColor
            radiusTL: height * 0.18
            radiusTR: height * 0.18
            radiusBR: height * 0.18
            radiusBL: height * 0.18
        }

        // ---- the glyph -----------------------------------------------------
        Loader {
            anchors.centerIn: parent
            sourceComponent: root.icon
        }

        Text {
            id: icon
            visible: root.icon === null
            anchors.centerIn: parent
            // nudge onto the optical centre of the box
            anchors.verticalCenterOffset: Math.round(LcarsUi.u(root.glyphSize) * 0.04)
            text: root.glyph
            color: root.active ? root.activeIconColor : root.iconColor
            font.family: root.iconFont
            font.pixelSize: Math.round(LcarsUi.u(root.glyphSize))
        }

        // ---- the cut -------------------------------------------------------
        // Drawn rather than swapped for a "muted headphones" glyph: Font Awesome
        // has no such thing, and a bar over the icon reads as crossed out
        // whatever the icon happens to be.
        Rectangle {
            visible: root.active
            anchors.centerIn: parent
            width: LcarsUi.u(root.glyphSize) * 1.6   // spans the glyph, waves and all
            height: LcarsUi.u(root.slashWidth)
            radius: 0
            rotation: -45
            color: root.activeIconColor
            antialiasing: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: {
            root.holdFired = false
            hold.start()
        }
        onReleased: {
            hold.stop()
            if (!root.holdFired)
                root.clicked()
        }
        onCanceled: hold.stop()
    }

    Timer {
        id: hold
        interval: root.holdMs
        onTriggered: {
            root.holdFired = true
            root.held()
        }
    }
}
