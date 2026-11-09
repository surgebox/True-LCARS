import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsCapsule - the small readout button from the top-right of the reference:
// a saturated pill carrying a short label on the left and a value on the right,
// both in LCARS orange.
//
//   ( CPU                       9888-234 )
//
// `radius` is a fraction of the height so the pill keeps its shape at any size.
// ---------------------------------------------------------------------------
Item {
    id: root

    property string label: "CPU"
    property string value: "0000-000"
    property color color: LcarsUi.violet
    property color labelColor: LcarsUi.orange
    property color valueColor: LcarsUi.orange
    property real radiusFactor: 0.42
    property real labelSize: 30
    property real valueSize: 30
    property real padLeft: 22
    property real padRight: 22
    // Give the value a fixed share of the pill and shrink it to fit: a long
    // value (a wifi SSID, say) would otherwise run under the caption.
    property bool valueFit: true

    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    LcarsRect {
        anchors.fill: parent
        color: root.color
        radiusTL: height * root.radiusFactor
        radiusTR: height * root.radiusFactor
        radiusBR: height * root.radiusFactor
        radiusBL: height * root.radiusFactor
        opacity: root.pressed ? 0.72 : (root.hovered ? 0.88 : 1.0)

        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    LcarsLabel {
        id: caption
        anchors.left: parent.left
        anchors.leftMargin: LcarsUi.u(root.padLeft)
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.labelColor
        size: root.labelSize
    }

    LcarsLabel {
        anchors.right: parent.right
        anchors.rightMargin: LcarsUi.u(root.padRight)
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueFit ? root.width * 0.64 : implicitWidth
        horizontalAlignment: root.valueFit ? Text.AlignRight : Text.AlignLeft
        text: root.value
        color: root.valueColor
        size: root.valueSize
        fit: root.valueFit
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
