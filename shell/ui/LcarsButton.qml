import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsButton - a large LCARS button bar (BACK / OPEN / DELETE).
//
// Radii are exposed per corner so the layout can round only the ends that face
// the screen edge, which is what makes the footer read as one continuous bar.
// ---------------------------------------------------------------------------
Item {
    id: root

    property string text: "BUTTON"
    property color color: LcarsUi.violet
    property color textColor: LcarsUi.shade
    property real radiusTL: 0
    property real radiusTR: 0
    property real radiusBR: 0
    property real radiusBL: 0
    property int align: Text.AlignHCenter
    property real padLeft: 26
    property real padRight: 26
    property real size: 34

    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    LcarsRect {
        id: bar
        anchors.fill: parent
        color: root.color
        radiusTL: root.radiusTL
        radiusTR: root.radiusTR
        radiusBR: root.radiusBR
        radiusBL: root.radiusBL
        opacity: root.pressed ? 0.72 : (root.hovered ? 0.88 : 1.0)

        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    LcarsLabel {
        anchors.fill: parent
        anchors.leftMargin: LcarsUi.u(root.padLeft)
        anchors.rightMargin: LcarsUi.u(root.padRight)
        text: root.text
        color: root.textColor
        size: root.size
        horizontalAlignment: root.align
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
