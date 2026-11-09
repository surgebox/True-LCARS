import QtQuick
import QtQuick.Effects
import "../theme"

// Companion to volume: same full-height compact segments, with a charge sweep.
Item {
    id: root
    property bool vertical: true
    property bool present: false
    property int percent: 0
    property bool plugged: false
    property string status: "UNAVAILABLE"
    readonly property real level: present ? Math.max(0, Math.min(1, percent / 100)) : 0
    readonly property color levelColor: !present ? LcarsUi.grey
        : percent <= 20 ? LcarsUi.red : "#ffffff"
    readonly property string reading: present ? percent + "%" : "--"
    readonly property bool charging: present && plugged
    readonly property bool lowBattery: present && percent <= 30
    readonly property color textColor: charging ? "#66ff99" : levelColor
    readonly property string statusText: charging
        ? (status === "FULL" ? "FULL · AC" : status === "ON AC" ? "ON AC" : "CHARGING")
        : status
    readonly property string expandedStatusText: statusText === "DISCHARGING"
        ? "DRAINING" : statusText
    property real chargeProgress: 0
    readonly property real animatedLevel: level + (1 - level) * chargeProgress

    // The real reading stays lit underneath. A five-second white sweep plays
    // once per 30-second cycle, then holds full and glowing until the next sweep.
    SequentialAnimation {
        running: root.charging && root.visible && root.opacity > 0
        loops: Animation.Infinite
        PropertyAction { target: root; property: "chargeProgress"; value: 0 }
        NumberAnimation { target: root; property: "chargeProgress"; from: 0; to: 1; duration: 5000; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 25000 }
    }

    Text {
        objectName: "batteryIcon"
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? LcarsUi.u(124) : 0
        width: LcarsUi.u(22)
        height: root.vertical ? LcarsUi.u(28) : root.height
        // Font Awesome battery levels, matching the speaker's icon family.
        text: !root.present || root.percent < 10 ? "\uf244"
            : root.percent < 35 ? "\uf243" : root.percent < 65 ? "\uf242"
            : root.percent < 90 ? "\uf241" : "\uf240"
        font.family: "Font Awesome 7 Free Solid"
        font.pixelSize: LcarsUi.u(root.vertical ? 18 : 22)
        color: root.levelColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    Item {
        id: meter
        objectName: "batteryMeter"
        x: root.vertical ? 0 : LcarsUi.u(28)
        width: root.vertical ? root.width : Math.max(0, root.width - LcarsUi.u(72))
        height: root.vertical ? LcarsUi.u(120) : root.height
        readonly property int count: root.vertical ? 16 : 5
        readonly property real gap: LcarsUi.u(2)
        readonly property real segment: Math.max(0, ((root.vertical ? height : width) - gap * (count - 1)) / count)
        Repeater {
            model: meter.count
            delegate: Item {
                id: segment
                required property int index
                readonly property real start: index * (meter.segment + meter.gap)
                readonly property real extent: Math.max(0, Math.min(meter.segment,
                    root.animatedLevel * (root.vertical ? meter.height : meter.width) - start))
                x: root.vertical ? 0 : start
                y: root.vertical ? meter.height - start - meter.segment : 0
                width: root.vertical ? meter.width : meter.segment
                height: root.vertical ? meter.segment : meter.height
                Rectangle {
                    anchors.fill: parent
                    color: root.levelColor
                    opacity: root.present && segment.index < Math.ceil(root.level * meter.count) ? 1 : 0.18
                }
                Rectangle {
                    id: toppingUp
                    objectName: "batteryChargeFill"
                    x: 0
                    y: root.vertical ? segment.height - height : 0
                    width: root.vertical ? segment.width : segment.extent
                    height: root.vertical ? segment.extent : segment.height
                    color: "#ffffff"
                    visible: root.charging && segment.extent > 0
                }
                // Native glow skirts keep the charge sweep visible with the
                // software renderer too; MultiEffect softens it on the GPU.
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        anchors.fill: toppingUp
                        anchors.margins: -LcarsUi.u(2 + index * 3)
                        radius: LcarsUi.u(3 + index * 3)
                        color: "#ffffff"
                        opacity: 0.10 - index * 0.03
                        visible: toppingUp.visible
                        z: -1
                    }
                }
                MultiEffect {
                    source: toppingUp
                    anchors.fill: toppingUp
                    visible: toppingUp.visible
                    shadowEnabled: true
                    shadowColor: "#ffffff"
                    shadowBlur: 1
                    shadowOpacity: 0.8
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 12
                }
            }
        }
    }
    // Read-only telemetry: touching it reveals the state without changing power settings.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tipTimer.restart()
        LcarsLabel {
            objectName: "batteryStatus"
            anchors.top: parent.bottom
            anchors.topMargin: root.vertical ? 0 : LcarsUi.u(4)
            x: root.vertical ? (root.width - width) / 2 : 0
            width: root.vertical ? LcarsUi.u(68) : root.width
            height: LcarsUi.u(root.vertical ? 26 : 18)
            text: root.vertical
                ? root.reading + "\n" + root.expandedStatusText
                : root.reading + " · " + root.statusText
            size: root.vertical ? 12 : 14
            fit: true
            lineHeight: root.vertical ? 0.92 : 1
            lineHeightMode: Text.ProportionalHeight
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: parent.containsMouse || tipTimer.running || root.lowBattery || root.charging
            Rectangle { anchors.fill: parent; color: "black"; z: -1 }
        }
    }
    Timer { id: tipTimer; interval: 3000 }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: "Battery " + reading + ", " + statusText
}
