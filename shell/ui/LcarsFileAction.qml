import QtQuick
import "../theme"

Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    signal clicked()
    implicitWidth: Math.max(LcarsUi.u(56), caption.implicitWidth + LcarsUi.u(36))
    implicitHeight: LcarsUi.u(54)
    radius: LcarsUi.u(16)
    color: selected ? LcarsUi.violet : (mouse.containsMouse ? LcarsUi.amber : LcarsUi.peach)
    opacity: enabled ? 1 : 0.35
    LcarsLabel {
        id: caption
        anchors.centerIn: parent
        text: root.text
        size: 23
        color: LcarsUi.black
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Accessible.role: Accessible.Button
    Accessible.name: root.text
}
