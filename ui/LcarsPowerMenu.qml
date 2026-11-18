pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../theme"

FocusScope {
    id: root
    visible: open && !powerAction.running
    z: 5000
    property bool open: false
    property real originY: 0
    property var selectedAction: null
    property string error: ""
    readonly property var actions: [
        {label: "Power Off", method: "PowerOff", confirm: true},
        {label: "Restart", method: "Reboot", confirm: true},
        {label: "Sleep", method: "Suspend", confirm: false},
        {label: "Log Out", method: "logout", confirm: true}
    ]

    function show() {
        selectedAction = null
        error = ""
        open = true
        cancelButton.forceActiveFocus()
    }

    function close() {
        if (!powerAction.running) open = false
    }

    function execute(action) {
        if (powerAction.running) return
        error = ""
        if (action.method === "logout") {
            const session = Quickshell.env("XDG_SESSION_ID")
            if (!session) {
                error = "The current login session could not be identified."
                return
            }
            powerAction.command = ["loginctl", "terminate-session", session]
        } else {
            powerAction.command = ["busctl", "--system", "--timeout=120s",
                "--allow-interactive-authorization=yes", "call",
                "org.freedesktop.login1", "/org/freedesktop/login1",
                "org.freedesktop.login1.Manager", action.method, "b", "true"]
        }
        powerAction.running = true
    }

    Process {
        id: powerAction
        stderr: StdioCollector { id: details }
        onExited: (code, status) => {
            if (code === 0 && status === 0) {
                root.open = false
            } else {
                root.error = details.text.trim() || "Fedora could not complete the requested action."
                cancelButton.forceActiveFocus()
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.rightMargin: LcarsUi.u(10)
        y: root.originY + LcarsUi.u(10)
        width: Math.min(root.width - LcarsUi.u(20), LcarsUi.u(360))
        height: controls.implicitHeight + LcarsUi.u(32)
        color: LcarsUi.shade
        border.color: LcarsUi.yellow
        border.width: Math.max(1, LcarsUi.u(2))
        radius: LcarsUi.u(20)

        MouseArea { anchors.fill: parent }

        Column {
            id: controls
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: LcarsUi.u(16) }
            spacing: LcarsUi.u(8)
            enabled: !powerAction.running

            component MenuButton: Button {
                id: button
                property color accent: LcarsUi.yellow
                width: controls.width
                implicitHeight: LcarsUi.u(44)
                background: Rectangle {
                    color: button.down ? LcarsUi.honey : button.accent
                    radius: height / 2
                    border.width: button.activeFocus || button.hovered ? 2 : 0
                    border.color: LcarsUi.ink
                }
                contentItem: LcarsLabel {
                    text: button.text
                    size: 24
                    color: LcarsUi.shade
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            LcarsLabel {
                width: parent.width
                height: LcarsUi.u(40)
                size: 27
                text: root.selectedAction ? root.selectedAction.label + "?" : "Power Options"
                color: LcarsUi.honey
            }

            Repeater {
                model: root.selectedAction ? [] : root.actions
                delegate: MenuButton {
                    required property var modelData
                    text: modelData.label
                    onClicked: {
                        if (modelData.confirm) {
                            root.error = ""
                            root.selectedAction = modelData
                            cancelButton.forceActiveFocus()
                        } else {
                            root.execute(modelData)
                        }
                    }
                }
            }

            MenuButton {
                visible: root.selectedAction !== null
                text: root.selectedAction ? root.selectedAction.label : ""
                accent: LcarsUi.peach
                onClicked: root.execute(root.selectedAction)
            }

            Text {
                visible: root.error.length > 0
                width: parent.width
                text: root.error
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.pixelSize: Math.max(12, LcarsUi.u(18))
                color: LcarsUi.peach
            }

            MenuButton {
                id: cancelButton
                text: "Cancel"
                accent: LcarsUi.violet
                onClicked: root.close()
            }
        }
    }
}
