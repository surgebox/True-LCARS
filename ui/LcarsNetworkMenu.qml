import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import Quickshell.Io
import "../theme"

FocusScope {
    id: root
    property bool open: false
    property bool busy: false
    property bool refreshing: false
    property bool ready: false
    property bool backendEnabled: true
    property bool telemetryActive: false
    // The rail view uses the same controls across the full application field.
    // The header capsule keeps the original centered modal layout.
    property bool embedded: false
    property string metricFocus: ""
    property real reservedBottom: 0
    readonly property var passwordField: password
    property var networkState: ({radio: false, devices: [], networks: [], connectivity: "unknown"})
    // Interface state includes wired links; Wi-Fi radio state alone is not a link.
    readonly property bool hasActiveConnection: networkState.devices.some(
        device => device.state === "connected" || device.state === "connected (externally)")
    property var connectionInfo: ({})
    property var trafficHistory: []
    function recordTraffic(details) {
        if (details.iface && connectionInfo.iface && details.iface !== connectionInfo.iface)
            trafficHistory = []
        if (details.iface && details.downloadBps !== null && details.downloadBps !== undefined
            && details.uploadBps !== null && details.uploadBps !== undefined) {
            trafficHistory = trafficHistory.concat([{
                rx: Math.max(0, details.downloadBps), tx: Math.max(0, details.uploadBps)
            }]).slice(-24)
        }
    }
    function trafficPath(channel, width, height) {
        const samples = trafficHistory
        if (samples.length < 2) return ""
        const peak = Math.max(1024, ...samples.map(sample => Math.max(sample.rx, sample.tx)))
        return samples.map((sample, i) =>
            (i ? "L " : "M ") + (i * width / (samples.length - 1)).toFixed(1) + " "
            + (height - 2 - (Math.min(peak, Math.max(0, sample[channel])) / peak) * (height - 4)).toFixed(1)
        ).join(" ")
    }
    readonly property var liveInfo: hasActiveConnection ? connectionInfo : ({})
    function rate(value) {
        if (value === undefined || value === null) return "--"
        if (value < 1024) return Math.round(value) + " B/s"
        if (value < 1048576) return (value / 1024).toFixed(1) + " KB/s"
        return (value / 1048576).toFixed(1) + " MB/s"
    }
    function metric(value, suffix) { return value === undefined || value === null || value === "" ? "--" : value + (suffix || "") }
    readonly property string metricReadout: {
        switch (metricFocus) {
        case "download": return "DOWNLOAD / " + rate(liveInfo.downloadBps)
        case "upload": return "UPLOAD / " + rate(liveInfo.uploadBps)
        case "frequency": return "FREQUENCY / " + metric(liveInfo.freq, " MHz")
        case "speed": return "LINK SPEED / " + (liveInfo.bitrate || metric(liveInfo.speed, " Mbit/s"))
        case "ping": return "PING / " + metric(liveInfo.internet_ping_ms, " ms")
        default: return ""
        }
    }
    property var selected: null
    property string error: ""
    property string activity: ""
    readonly property var selection: {
        if (!selected) return null
        return networkState.networks.find(n => n.bssid === selected.bssid && n.iface === selected.iface) || null
    }
    readonly property string script: Qt.resolvedUrl("../scripts/network.py").toString().replace(/^file:\/\//, "")
    signal dismissed()
    signal inputFocused(var field, string label)
    signal inputBlurred(var field)
    visible: open
    enabled: open
    z: 2000

    function show() { open = true; forceActiveFocus(); if (!service.running && backendEnabled) service.running = true; request("status") }
    function close() { password.text = ""; selected = null; open = false; dismissed() }
    function request(op, values) {
        if (!ready || busy || (op === "status" && refreshing)) return
        if (op === "status") {
            refreshing = true
        } else {
            busy = true
            error = ""
            activity = op === "scan" ? "SCANNING FREQUENCIES" : op === "connect"
                ? "ESTABLISHING LINK" : "UPDATING INTERFACE"
        }
        service.write(JSON.stringify(Object.assign({op: op}, values || {})) + "\n")
    }
    function choose(network) { selected = network; password.text = ""; error = "" }
    function connectSelected() {
        if (!selection || busy) return
        request("connect", {bssid: selection.bssid, iface: selection.iface, password: password.text})
        password.text = ""
    }
    onOpenChanged: {
        if (open) forceActiveFocus()
        else {
            // A FocusScope otherwise restores its last focused child on reopen,
            // which raises the touch keyboard before the user taps the field.
            password.focus = false
            password.text = ""
            selected = null
            trafficHistory = []
        }
    }
    Keys.onEscapePressed: event => { if (root.embedded) root.dismissed(); else root.close(); event.accepted = true }
    Keys.onBacktabPressed: event => { event.accepted = true }
    // Consume keyboard navigation at the modal boundary.
    Keys.onPressed: event => { if (event.key === Qt.Key_Tab && !password.activeFocus) event.accepted = true }

    Process {
        id: service
        command: ["python3", root.script]
        stdinEnabled: true
        running: root.backendEnabled
        onStarted: { root.ready = true; if (root.open) root.request("status") }
        onRunningChanged: {
            if (!running) {
                root.ready = false
                root.busy = false
                root.refreshing = false
                root.error = "Network service stopped. Close and reopen to retry."
            }
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line)
                    if (result.op === "status") root.refreshing = false
                    else { root.busy = false; root.activity = "" }
                    if (result.ok) {
                        root.networkState = result.data
                        if (result.op !== "status") root.error = ""
                    } else if (result.op !== "status" || root.networkState.devices.length === 0) {
                        root.error = result.error
                    }
                } catch (e) {
                    root.busy = false
                    root.refreshing = false
                    root.error = "Invalid response from network service."
                }
            }
        }
    }
    Process {
        id: metricsService
        command: ["python3", Qt.resolvedUrl("../scripts/network-metrics.py").toString().replace(/^file:\/\//, "")]
        running: (root.open || root.telemetryActive) && root.backendEnabled
        onRunningChanged: { if (!running) root.connectionInfo = ({}) }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const details = JSON.parse(line)
                    root.recordTraffic(details)
                    root.connectionInfo = details
                } catch (e) { root.connectionInfo = ({}) }
            }
        }
    }
    Timer {
        interval: 4000
        running: (root.open || root.telemetryActive) && root.backendEnabled
        repeat: true
        onTriggered: { if (!metricsService.running) metricsService.running = true }
    }
    Timer {
        interval: 10000
        running: root.open && root.backendEnabled
        repeat: true
        onTriggered: { if (!service.running) service.running = true; else root.request("status") }
    }
    Rectangle { anchors.fill: parent; color: "#c9000000"; visible: !root.embedded }
    MouseArea { anchors.fill: parent; visible: !root.embedded; onClicked: root.close() }

    Item {
        id: panel
        objectName: "networkPanel"
        x: root.embedded ? 0 : (root.width - width) / 2
        y: root.embedded ? 0 : (root.height - root.reservedBottom - height) / 2
        width: root.embedded ? root.width : LcarsUi.u(1100)
        height: root.embedded ? root.height : LcarsUi.u(800)
        // Preserve the entire console on narrow windows.
        scale: root.embedded ? 1 : Math.min(1, (root.width - 24) / width,
            Math.max(1, root.height - root.reservedBottom - 24) / height)
        Rectangle { anchors.fill: parent; color: LcarsUi.black }
        MouseArea { anchors.fill: parent } // absorb clicks inside the console

        LcarsElbow {
            visible: !root.embedded
            width: panel.width - LcarsUi.u(170); height: LcarsUi.u(190)
            columnThickness: LcarsUi.u(126); barThickness: LcarsUi.u(72)
            outerRadius: LcarsUi.u(64); innerRadius: LcarsUi.u(46)
            // The quarter-circle spans the full 72-to-36 step, so its tangent
            // meets the arm's underside without a short vertical tail.
            armEndThickness: LcarsUi.u(36)
            armEndRadius: LcarsUi.u(36)
            color: LcarsUi.gold
        }
        LcarsLabel {
            visible: !root.embedded
            x: LcarsUi.u(164); y: LcarsUi.u(4)
            height: LcarsUi.u(62); width: LcarsUi.u(600)
            text: "NETWORK // COMMUNICATIONS"; color: LcarsUi.shade; size: 34
            fit: true
        }
        Rectangle {
            visible: !root.embedded
            objectName: "networkConnectionStatus"
            x: panel.width - LcarsUi.u(156)
            width: LcarsUi.u(156); height: LcarsUi.u(72)
            radius: height / 2
            color: root.hasActiveConnection ? "#66cc99" : LcarsUi.salmon
            LcarsLabel {
                anchors.fill: parent
                text: root.hasActiveConnection ? "CONNECTED" : "INACTIVE"
                size: 27; color: LcarsUi.shade
                horizontalAlignment: Text.AlignHCenter
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: root.hasActiveConnection ? "Connected" : "Inactive"
        }
        // Interrupted spine and a reverse elbow close the console around the data.
        LcarsLabel {
            visible: !root.embedded
            x: LcarsUi.u(14); y: LcarsUi.u(100); width: LcarsUi.u(94); height: LcarsUi.u(64)
            text: (root.liveInfo.type === "wifi" ? "WI-FI" : root.liveInfo.type === "ethernet" ? "WIRED" : "NO LINK")
                + "\n" + (root.liveInfo.iface || "--"); size: 21; fit: true; color: LcarsUi.shade
            horizontalAlignment: Text.AlignRight
        }
        Repeater {
            model: [
                {y: 200, h: 92, c: LcarsUi.sky, label: "DOWNLOAD", value: root.rate(root.liveInfo.downloadBps)},
                {y: 302, h: 92, c: LcarsUi.violet, label: "UPLOAD", value: root.rate(root.liveInfo.uploadBps)},
                {y: 404, h: 92, c: LcarsUi.rust, label: "FREQUENCY", value: root.metric(root.liveInfo.freq, " MHz")},
                {y: 506, h: 104, c: LcarsUi.peach, label: "LINK SPEED", value: root.liveInfo.bitrate || root.metric(root.liveInfo.speed, " Mbit/s")}
            ]
            delegate: Rectangle {
                required property var modelData
                visible: !root.embedded
                y: LcarsUi.u(modelData.y); width: LcarsUi.u(126); height: LcarsUi.u(modelData.h)
                color: modelData.c
                LcarsLabel {
                    x: LcarsUi.u(10); y: LcarsUi.u(14)
                    width: parent.width - LcarsUi.u(20); height: LcarsUi.u(24)
                    text: modelData.label; color: LcarsUi.shade; size: 17
                    horizontalAlignment: Text.AlignRight
                }
                LcarsLabel {
                    x: LcarsUi.u(8); y: LcarsUi.u(44)
                    width: parent.width - LcarsUi.u(18); height: LcarsUi.u(34)
                    text: modelData.value; color: LcarsUi.shade; size: 25; fit: true; caps: false
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
        LcarsElbow {
            visible: !root.embedded
            y: LcarsUi.u(620); width: panel.width; height: LcarsUi.u(180)
            corner: "bottomLeft"; columnThickness: LcarsUi.u(126)
            barThickness: LcarsUi.u(32); outerRadius: LcarsUi.u(32); innerRadius: LcarsUi.u(56)
            armEndThickness: LcarsUi.u(58); color: LcarsUi.mauve
        }
        LcarsLabel {
            visible: !root.embedded
            x: LcarsUi.u(12); y: LcarsUi.u(646)
            width: LcarsUi.u(98); height: LcarsUi.u(26)
            text: "PING"; size: 18; color: LcarsUi.shade
            horizontalAlignment: Text.AlignRight
        }
        LcarsLabel {
            visible: !root.embedded
            x: LcarsUi.u(12); y: LcarsUi.u(682)
            width: LcarsUi.u(98); height: LcarsUi.u(36)
            text: root.metric(root.liveInfo.internet_ping_ms, " ms")
            size: 26; color: LcarsUi.shade; fit: true; caps: false
            horizontalAlignment: Text.AlignRight
        }
        LcarsLabel {
            x: root.embedded ? LcarsUi.u(18) : LcarsUi.u(164)
            y: panel.height - LcarsUi.u(32)
            width: root.embedded ? panel.width - LcarsUi.u(36) : LcarsUi.u(700)
            height: LcarsUi.u(32)
            text: "GATEWAY " + root.metric(root.liveInfo.gateway)
                + "    /    IP " + root.metric(root.liveInfo.ip) + (root.liveInfo.prefix ? "/" + root.liveInfo.prefix : "")
                + "    /    " + root.networkState.connectivity
            size: 18; color: root.embedded ? LcarsUi.mauve : LcarsUi.shade
            tracking: true; fit: true
        }

        Item {
            id: content
            x: LcarsUi.u(root.embedded ? 18 : 164)
            y: LcarsUi.u(root.embedded ? 18 : 94)
            width: panel.width - x - LcarsUi.u(root.embedded ? 18 : 24)
            height: panel.height - y - LcarsUi.u(root.embedded ? 44 : 76)
            LcarsLabel {
                width: parent.width - LcarsUi.u(430); height: LcarsUi.u(56)
                text: root.busy ? root.activity : root.networkState.radio ? "WIRELESS ACCESS" : "WIRELESS OFFLINE"
                size: 28; fit: true; color: LcarsUi.sky
            }
            Row {
                anchors.right: parent.right; spacing: LcarsUi.u(12)
                LcarsButton {
                    objectName: "networkRadio"
                    width: LcarsUi.u(210); height: LcarsUi.u(56); size: 24
                    text: root.networkState.radio ? "WI-FI · ON" : "WI-FI · OFF"
                    color: root.networkState.radio ? LcarsUi.violet : LcarsUi.grey
                    enabled: root.ready && !root.busy; opacity: enabled ? 1 : 0.45
                    radiusTL: LcarsUi.u(28); radiusBL: LcarsUi.u(28)
                    onClicked: root.request("radio", {enabled: !root.networkState.radio})
                }
                LcarsButton {
                    objectName: "networkScan"
                    width: LcarsUi.u(180); height: LcarsUi.u(56); size: 24; text: "SCAN"
                    color: LcarsUi.amber
                    radiusTR: LcarsUi.u(28); radiusBR: LcarsUi.u(28)
                    enabled: root.ready && !root.busy && root.networkState.radio; opacity: enabled ? 1 : 0.45
                    onClicked: root.request("scan")
                }
            }
            LcarsLabel {
                y: LcarsUi.u(64); width: parent.width; height: LcarsUi.u(32)
                text: root.networkState.devices.filter(d => d.state === "connected").map(d => d.iface + " · " + d.name).join("    /    ") || "NO ACTIVE LINK"
                size: 20; color: LcarsUi.sky; elide: Text.ElideRight; caps: false
            }
            LcarsLabel {
                visible: root.embedded && root.metricFocus !== ""
                x: parent.width * 0.55; y: LcarsUi.u(64)
                width: parent.width * 0.45; height: LcarsUi.u(32)
                text: root.metricReadout; size: 20; color: LcarsUi.gold; fit: true
                horizontalAlignment: Text.AlignRight
            }
            ListView {
                id: networks
                objectName: "networkList"
                y: LcarsUi.u(112); width: parent.width
                height: root.embedded ? Math.max(LcarsUi.u(82), content.height - LcarsUi.u(300)) : LcarsUi.u(300)
                model: root.networkState.networks
                spacing: LcarsUi.u(10); clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Item {
                    id: networkRow
                    required property var modelData
                    width: networks.width - LcarsUi.u(14); height: LcarsUi.u(82)
                    readonly property color categoryColor: modelData.active ? "#66cc99"
                        : modelData.uuid ? LcarsUi.violet : LcarsUi.peach
                    readonly property bool chosen: !!root.selection && root.selection.bssid === modelData.bssid && root.selection.iface === modelData.iface
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(networkRow.categoryColor.r, networkRow.categoryColor.g, networkRow.categoryColor.b, networkRow.chosen ? 0.22 : 0.09)
                        border.color: networkRow.chosen ? networkRow.categoryColor : "transparent"
                        border.width: 2
                    }
                    LcarsElbow {
                        width: LcarsUi.u(72); height: parent.height
                        columnThickness: LcarsUi.u(12); barThickness: LcarsUi.u(10)
                        outerRadius: LcarsUi.u(10); innerRadius: LcarsUi.u(16)
                        color: networkRow.categoryColor
                    }
                    LcarsLabel {
                        x: LcarsUi.u(30); y: LcarsUi.u(10)
                        width: parent.width - LcarsUi.u(250); height: LcarsUi.u(36)
                        text: networkRow.modelData.ssid; caps: false; elide: Text.ElideRight
                        size: 27; color: networkRow.categoryColor
                    }
                    LcarsLabel {
                        x: LcarsUi.u(30); y: LcarsUi.u(46)
                        width: parent.width - LcarsUi.u(250); height: LcarsUi.u(26)
                        text: (networkRow.modelData.active ? "CURRENT" : networkRow.modelData.uuid ? "SAVED" : "NEW") + "  /  "
                            + (networkRow.modelData.secured ? networkRow.modelData.security : "OPEN NETWORK")
                        size: 17; color: networkRow.categoryColor; elide: Text.ElideRight
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: LcarsUi.u(26)
                        anchors.verticalCenter: parent.verticalCenter; spacing: LcarsUi.u(6)
                        Repeater {
                            model: 5
                            Rectangle {
                                required property int index
                                width: LcarsUi.u(14); height: LcarsUi.u(12 + index * 6)
                                y: LcarsUi.u(40) - height
                                color: networkRow.modelData.signal >= (index + 1) * 20 ? networkRow.categoryColor : "#302b40"
                            }
                        }
                        LcarsLabel { text: networkRow.modelData.signal + "%"; size: 23; color: networkRow.categoryColor; width: LcarsUi.u(64); height: LcarsUi.u(40); horizontalAlignment: Text.AlignRight }
                    }
                    MouseArea {
                        anchors.fill: parent; enabled: !root.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(networkRow.modelData)
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.ssid + (modelData.active ? ", connected" : ", " + modelData.signal + " percent signal")
                }
                LcarsLabel {
                    anchors.fill: parent; visible: networks.count === 0
                    text: root.busy ? "ACQUIRING NETWORK DATA…" : !root.ready ? "NETWORK SERVICE UNAVAILABLE"
                        : !root.networkState.radio ? "ENABLE WI-FI TO DISCOVER NETWORKS" : "NO NETWORKS IN RANGE · TAP SCAN"
                    horizontalAlignment: Text.AlignHCenter; size: 25; color: LcarsUi.mauve
                }
            }
            Item {
                id: selectionControls
                y: root.embedded ? networks.y + networks.height + LcarsUi.u(12) : LcarsUi.u(426)
                width: parent.width; height: LcarsUi.u(112)
                visible: !!root.selection
                LcarsLabel {
                    width: parent.width - LcarsUi.u(230); height: LcarsUi.u(38)
                    text: root.selection ? root.selection.ssid : ""; caps: false
                    elide: Text.ElideRight; size: 28
                    color: root.selection ? (root.selection.active ? "#66cc99"
                        : root.selection.uuid ? LcarsUi.violet : LcarsUi.peach) : LcarsUi.ice
                }
                TextField {
                    id: password
                    objectName: "networkPassword"
                    y: LcarsUi.u(46); width: parent.width - LcarsUi.u(230); height: LcarsUi.u(62)
                    visible: !!root.selection && root.selection.secured && !root.selection.active && !root.selection.enterprise
                    enabled: !root.busy
                    placeholderText: root.selection && root.selection.uuid ? "Saved credentials · or enter a replacement password" : "Wi-Fi password"
                    echoMode: TextInput.Password
                    color: LcarsUi.ice; placeholderTextColor: LcarsUi.mauve
                    font.family: LcarsUi.fontMono; font.pixelSize: LcarsUi.u(18)
                    leftPadding: LcarsUi.u(16)
                    background: Rectangle { color: "#15121c"; border.color: password.activeFocus ? LcarsUi.peach : LcarsUi.plum; border.width: 2 }
                    onActiveFocusChanged: {
                        if (activeFocus) root.inputFocused(password, "WI-FI PASSWORD")
                        else root.inputBlurred(password)
                    }
                    onAccepted: root.connectSelected()
                }
                LcarsLabel {
                    y: LcarsUi.u(42); width: parent.width - LcarsUi.u(230); height: LcarsUi.u(66)
                    visible: !password.visible
                    text: root.selection && root.selection.active ? "LINK ESTABLISHED · " + root.selection.iface
                        : root.selection && root.selection.enterprise ? "ENTERPRISE · CONFIGURE WITH SYSTEM NETWORK SETTINGS" : "OPEN NETWORK · NO PASSWORD REQUIRED"
                    size: 19; color: LcarsUi.mauve; wrapMode: Text.Wrap
                }
                LcarsButton {
                    objectName: "networkConnect"
                    anchors.right: parent.right; y: LcarsUi.u(46)
                    width: LcarsUi.u(210); height: LcarsUi.u(62); size: 27
                    text: root.selection && root.selection.active ? "DISCONNECT" : "CONNECT"
                    color: root.selection && root.selection.active ? LcarsUi.salmon : LcarsUi.peach
                    radiusTR: LcarsUi.u(31); radiusBR: LcarsUi.u(31)
                    enabled: !root.busy && !!root.selection
                        && (!root.selection.enterprise || !!root.selection.uuid)
                        && (root.selection.active || !root.selection.secured || !!root.selection.uuid || password.text.length > 0)
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        if (root.selection.active) root.request("disconnect", {iface: root.selection.iface})
                        else root.connectSelected()
                    }
                }
            }
            LcarsLabel {
                y: selectionControls.y; width: parent.width; height: LcarsUi.u(100)
                visible: !root.selection
                text: "SELECT A NETWORK TO ESTABLISH OR MANAGE A LINK"
                size: 24; color: LcarsUi.mauve; wrapMode: Text.Wrap
            }
            LcarsLabel {
                y: root.embedded ? selectionControls.y + LcarsUi.u(116) : LcarsUi.u(548)
                width: parent.width - LcarsUi.u(270); height: LcarsUi.u(76)
                text: root.error || (root.busy ? root.activity + "…" : "")
                color: root.error ? LcarsUi.salmon : LcarsUi.mauve
                size: 19; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            }
            Row {
                y: root.embedded ? selectionControls.y + LcarsUi.u(132) : LcarsUi.u(568)
                spacing: LcarsUi.u(24)
                visible: !root.error && !root.busy
                Repeater {
                    model: [{text: "CURRENT", color: "#66cc99"}, {text: "SAVED", color: LcarsUi.violet}, {text: "NEW / UNSAVED", color: LcarsUi.peach}]
                    LcarsLabel {
                        required property var modelData
                        text: "● " + modelData.text; color: modelData.color; size: 20
                    }
                }
            }
            Item {
                id: trafficGraph
                objectName: "networkTrafficGraph"
                anchors.right: parent.right
                y: root.embedded ? selectionControls.y + LcarsUi.u(116) : LcarsUi.u(548)
                width: LcarsUi.u(250); height: LcarsUi.u(66)
                Rectangle {
                    anchors.fill: parent
                    color: "#111523"
                    border.color: LcarsUi.violet
                    border.width: Math.max(1, LcarsUi.u(1))
                }
                LcarsLabel {
                    x: LcarsUi.u(8); y: LcarsUi.u(2)
                    text: "LIVE TRAFFIC"; size: 15; color: LcarsUi.mauve
                }
                LcarsLabel {
                    anchors.right: parent.right; anchors.rightMargin: LcarsUi.u(8)
                    y: LcarsUi.u(2); text: "RX  /  TX"; size: 15; color: LcarsUi.sky
                }
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        x: LcarsUi.u(7)
                        y: LcarsUi.u(34 + index * 12)
                        width: trafficGraph.width - LcarsUi.u(14)
                        height: Math.max(1, LcarsUi.u(1))
                        color: "#344158"
                    }
                }
                Shape {
                    id: chart
                    x: LcarsUi.u(7); y: LcarsUi.u(25)
                    width: parent.width - LcarsUi.u(14)
                    height: parent.height - LcarsUi.u(31)
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: LcarsUi.sky; strokeWidth: LcarsUi.u(2)
                        fillColor: "transparent"
                        PathSvg { path: root.trafficPath("rx", chart.width, chart.height) }
                    }
                    ShapePath {
                        strokeColor: LcarsUi.mauve; strokeWidth: LcarsUi.u(2)
                        fillColor: "transparent"
                        PathSvg { path: root.trafficPath("tx", chart.width, chart.height) }
                    }
                }
                LcarsLabel {
                    anchors.fill: parent
                    visible: root.trafficHistory.length < 2
                    text: root.hasActiveConnection ? "COLLECTING ACTIVITY…" : "NO ACTIVE LINK"
                    size: 17; color: LcarsUi.mauve
                    horizontalAlignment: Text.AlignHCenter
                }
                Accessible.role: Accessible.Chart
                Accessible.name: "Live network traffic, download " + root.rate(root.liveInfo.downloadBps)
                    + ", upload " + root.rate(root.liveInfo.uploadBps)
            }

        }
    }

}
