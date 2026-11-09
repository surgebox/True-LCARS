import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsDeviceMenu - the popup behind the volume button's long press.
//
// A list of audio outputs, the current default marked with a block. Picking one
// emits picked(index); the shell turns that into `audio.sh default <index>`.
//
// It is deliberately a passive list: it does not fetch anything itself. The
// shell owns the process, so there is exactly one place that knows how to talk
// to the audio server.
// ---------------------------------------------------------------------------
Item {
    id: root

    property var items: []          // [{ isDefault, index, label }, ...]
    property string title: "AUDIO OUTPUT"
    property bool open: false

    property real rowH: 34
    property real pad: 10

    signal picked(int index)
    signal dismissed()

    implicitWidth: LcarsUi.u(360)
    implicitHeight: LcarsUi.u(titleH + pad * 2 + rowH * Math.max(1, items.length))
    readonly property real titleH: 30

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 110 } }

    LcarsRect {
        anchors.fill: parent
        color: "#0b0e13"
        borderColor: LcarsUi.orange
        borderWidth: Math.max(1, LcarsUi.u(2))
        radiusTL: LcarsUi.u(20)
        radiusTR: LcarsUi.u(20)
        radiusBR: LcarsUi.u(20)
        radiusBL: LcarsUi.u(20)
    }

    LcarsLabel {
        id: heading
        x: LcarsUi.u(root.pad + 6)
        y: LcarsUi.u(root.pad)
        width: root.width - LcarsUi.u(root.pad * 2 + 12)
        height: LcarsUi.u(root.titleH)
        text: root.title
        color: LcarsUi.orange
        size: 20
        tracking: true
        horizontalAlignment: Text.AlignLeft
    }

    Column {
        id: rows
        x: LcarsUi.u(root.pad)
        y: LcarsUi.u(root.pad + root.titleH)
        width: root.width - LcarsUi.u(root.pad * 2)
        spacing: LcarsUi.u(4)

        Repeater {
            model: root.items

            delegate: Item {
                width: rows.width
                height: LcarsUi.u(root.rowH)

                LcarsRect {
                    anchors.fill: parent
                    color: modelData.isDefault ? LcarsUi.violet : "#1b2029"
                    radiusTL: LcarsUi.u(8)
                    radiusTR: LcarsUi.u(8)
                    radiusBR: LcarsUi.u(8)
                    radiusBL: LcarsUi.u(8)
                    opacity: rowMouse.containsMouse ? 0.85 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }

                // the block marks the output sound is currently going to
                LcarsRect {
                    visible: modelData.isDefault
                    x: LcarsUi.u(9)
                    anchors.verticalCenter: parent.verticalCenter
                    width: LcarsUi.u(10)
                    height: LcarsUi.u(10)
                    color: LcarsUi.orange
                }

                LcarsLabel {
                    x: LcarsUi.u(26)
                    width: parent.width - LcarsUi.u(36)
                    height: parent.height
                    text: modelData.label
                    color: modelData.isDefault ? LcarsUi.shade : LcarsUi.amber
                    size: 18
                    caps: false
                    horizontalAlignment: Text.AlignLeft
                    fit: true
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.index)
                }
            }
        }
    }
}
