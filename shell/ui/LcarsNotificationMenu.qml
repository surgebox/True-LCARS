pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Io
import Quickshell.Services.Notifications
import "../theme"

FocusScope {
    id: root
    property bool open: false
    property real originY: LcarsUi.u(66)
    property real reveal: 0
    property bool backendEnabled: true
    property var items: []
    property bool dnd: false
    property bool showingRecent: false
    readonly property var displayedItems: items.filter(item => item.active !== showingRecent)
    readonly property int notificationCount: items.length
    readonly property string script: Qt.resolvedUrl("../scripts/notifications.py").toString().replace(/^file:\/\//, "")
    property var liveRefs: ({})
    property var deadlines: ({})
    property int nextKey: 0
    property bool historyLoaded: false
    visible: open || reveal > 0
    enabled: open
    z: 1900
    onOpenChanged: reveal = open ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 320; easing.type: Easing.InOutCubic }
    }

    function show() {
        open = true
        showingRecent = !items.some(item => item.active)
        forceActiveFocus()
    }
    function close() { open = false }
    function toggle() { if (open) close(); else show() }
    Keys.onEscapePressed: event => { close(); event.accepted = true }

    function plain(value) {
        return String(value || "").replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "").replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"").trim()
    }
    function snapshot(notification, key, timestamp) {
        return {
            key: key, app: plain(notification.appName || "SYSTEM"),
            summary: plain(notification.summary || "Notification"),
            body: plain(notification.body), timestamp: timestamp,
            urgency: notification.urgency, active: true,
            transient: !!notification.transient
        }
    }
    function persist() {
        if (!historyLoaded || !reader.running) return
        reader.write(JSON.stringify({op: "save", dnd: dnd,
            history: items.filter(item => !item.active).slice(0, 30)}) + "\n")
    }
    function archive(key) {
        const row = items.find(item => item.key === key)
        delete liveRefs[key]
        delete deadlines[key]
        if (!row) return
        const remaining = items.filter(item => item.key !== key)
        const live = remaining.filter(item => item.active)
        const recent = remaining.filter(item => !item.active)
        items = live.concat(row.transient ? recent.slice(0, 30)
            : [Object.assign({}, row, {active: false})].concat(recent).slice(0, 30))
        persist()
    }
    function receive(notification) {
        const key = Date.now() + "-" + (++nextKey)
        const row = snapshot(notification, key, Date.now())
        if (dnd) {
            if (!row.transient) {
                items = items.filter(item => item.active).concat(
                    [Object.assign({}, row, {active: false})],
                    items.filter(item => !item.active).slice(0, 29))
                persist()
            }
            return
        }
        notification.tracked = true
        liveRefs[key] = notification
        if (notification.urgency !== NotificationUrgency.Critical) {
            const seconds = notification.expireTimeout > 0
                ? Math.max(5, Math.min(30, notification.expireTimeout)) : 8
            deadlines[key] = Date.now() + seconds * 1000
        }
        notification.closed.connect(function() { root.archive(key) })
        const update = function() {
            root.items = root.items.map(item => item.key === key
                ? root.snapshot(notification, key, item.timestamp) : item)
        }
        notification.summaryChanged.connect(update)
        notification.bodyChanged.connect(update)
        notification.appNameChanged.connect(update)
        items = [row].concat(items)
        if (open && showingRecent) showingRecent = false
    }
    function dismiss(key) {
        const ref = liveRefs[key]
        if (ref) ref.dismiss()
        else { items = items.filter(item => item.key !== key); persist() }
    }
    function clearAll() {
        if (showingRecent) {
            items = items.filter(item => item.active)
            persist()
        } else {
            Object.keys(liveRefs).forEach(key => liveRefs[key].dismiss())
        }
    }
    function activate(key) {
        const ref = liveRefs[key]
        if (!ref) return
        for (const action of ref.actions) {
            if (action.identifier === "default") {
                const resident = ref.resident
                action.invoke()
                if (!resident && liveRefs[key]) liveRefs[key].dismiss()
                close()
                return
            }
        }
    }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        bodyMarkupSupported: false
        onNotification: notification => root.receive(notification)
    }

    Process {
        id: reader
        command: ["python3", root.script]
        stdinEnabled: true
        running: root.backendEnabled
        stdout: SplitParser {
            onRead: line => {
                try {
                    const state = JSON.parse(line)
                    if (state.op !== "loaded") return
                    const existing = new Set(root.items.map(item => item.key))
                    const live = root.items.filter(item => item.active)
                    const recent = root.items.filter(item => !item.active).concat(
                        (state.history || []).filter(item => !existing.has(item.key)))
                    recent.sort((a, b) => b.timestamp - a.timestamp)
                    root.items = live.concat(recent.slice(0, 30))
                    if (!root.historyLoaded) root.dnd = !!state.dnd
                    root.historyLoaded = true
                    root.persist()
                } catch (e) { /* retain the last good snapshot */ }
            }
        }
    }
    Timer {
        interval: 5000
        running: root.backendEnabled
        repeat: true
        onTriggered: { if (!reader.running) reader.running = true }
    }
    Timer {
        interval: 1000
        running: root.backendEnabled
        repeat: true
        onTriggered: {
            for (const key of Object.keys(root.deadlines)) {
                if (root.deadlines[key] <= Date.now() && root.liveRefs[key])
                    root.liveRefs[key].expire()
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        id: revealMask
        x: 0
        y: root.originY
        width: LcarsUi.u(540)
        readonly property real fullHeight: Math.max(0, root.height - y)
        height: fullHeight * root.reveal
        clip: true
        scale: Math.min(1, root.width / width)
        transformOrigin: Item.TopLeft

        Item {
        id: panel
        objectName: "notificationPanel"
        readonly property real spineWidth: LcarsUi.u(80)
        readonly property real contentLeft: LcarsUi.u(100)
        x: 0
        y: 0
        width: revealMask.width
        height: revealMask.fullHeight

        Rectangle {
            anchors.fill: parent
            color: LcarsUi.black
        }
        MouseArea { anchors.fill: parent } // contain taps within the popout

        // The bell cap's square lower edge continues to the screen bottom.
        Rectangle {
            width: panel.spineWidth
            height: revealMask.height
            color: LcarsUi.yellow
        }
        Item {
            anchors.fill: parent
            opacity: Math.max(0, Math.min(1, (root.reveal - 0.72) / 0.28))
            enabled: opacity > 0.5
        Item {
            x: 0; y: LcarsUi.u(88)
            width: panel.spineWidth; height: LcarsUi.u(270)
            LcarsLabel {
                anchors.centerIn: parent
                width: LcarsUi.u(270); height: LcarsUi.u(42)
                rotation: -90
                text: "NOTIFICATIONS"
                color: LcarsUi.shade; size: 31; fit: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Item {
            x: 0; y: Math.max(LcarsUi.u(390), panel.height - LcarsUi.u(240))
            width: panel.spineWidth; height: LcarsUi.u(176)
            Rectangle {
                anchors.centerIn: parent
                width: LcarsUi.u(156); height: LcarsUi.u(44)
                rotation: -90
                radius: height / 2
                color: root.dnd ? LcarsUi.red : LcarsUi.green
                Behavior on color { ColorAnimation { duration: 180 } }
                LcarsLabel {
                    x: root.dnd ? LcarsUi.u(42) : LcarsUi.u(8)
                    width: parent.width - LcarsUi.u(50)
                    height: parent.height
                    text: root.dnd ? "SILENCED" : "ACTIVE"
                    color: LcarsUi.shade; size: 20; fit: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    x: root.dnd ? LcarsUi.u(6) : parent.width - width - LcarsUi.u(6)
                    y: LcarsUi.u(6)
                    width: LcarsUi.u(32); height: parent.height - LcarsUi.u(12)
                    radius: height / 2
                    color: LcarsUi.shade
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.dnd = !root.dnd; root.persist() }
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: "Do not disturb"
                    Accessible.checked: root.dnd
                }
            }
        }
        LcarsLabel {
            x: panel.contentLeft; y: LcarsUi.u(18)
            width: panel.width - x - LcarsUi.u(18)
            height: LcarsUi.u(28)
            text: root.displayedItems.length + (root.showingRecent ? " RECENT" : " LIVE") + " TRANSMISSIONS"
            color: LcarsUi.lilac; size: 19; tracking: true
        }

        Row {
            x: panel.contentLeft; y: LcarsUi.u(55)
            spacing: LcarsUi.u(8)
            Repeater {
                model: [
                    { label: "LIVE", recent: false, color: LcarsUi.violet },
                    { label: "RECENT", recent: true, color: LcarsUi.sky }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: LcarsUi.u(206); height: LcarsUi.u(34)
                    radius: height / 2
                    color: root.showingRecent === modelData.recent ? modelData.color : LcarsUi.grey
                    LcarsLabel {
                        anchors.fill: parent
                        text: parent.modelData.label
                        color: LcarsUi.shade; size: 19
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showingRecent = parent.modelData.recent
                    }
                }
            }
        }

        Flickable {
            id: feed
            objectName: "notificationFeed"
            x: panel.contentLeft; y: LcarsUi.u(105)
            width: panel.width - x - LcarsUi.u(18)
            height: Math.max(0, panel.height - y - LcarsUi.u(80))
            contentWidth: width
            contentHeight: messages.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: messages
                width: feed.width
                spacing: LcarsUi.u(8)
                Repeater {
                    model: root.displayedItems
                    delegate: Item {
                        id: message
                        required property var modelData
                        width: feed.width
                        height: LcarsUi.u(91)
                        Rectangle {
                            width: LcarsUi.u(5); height: parent.height
                            color: message.modelData.urgency === 2 ? LcarsUi.salmon
                                : message.modelData.active ? LcarsUi.gold : LcarsUi.violet
                        }
                        LcarsLabel {
                            x: LcarsUi.u(15); y: 0
                            width: parent.width - LcarsUi.u(125); height: LcarsUi.u(23)
                            text: message.modelData.app || "SYSTEM"
                            color: LcarsUi.sky; size: 17; elide: Text.ElideRight
                        }
                        LcarsLabel {
                            anchors.right: parent.right; y: 0
                            anchors.rightMargin: LcarsUi.u(38)
                            width: LcarsUi.u(64); height: LcarsUi.u(23)
                            text: Qt.formatTime(new Date(message.modelData.timestamp), "hh:mm")
                            color: LcarsUi.mauve; size: 16
                            horizontalAlignment: Text.AlignRight
                        }
                        LcarsLabel {
                            x: LcarsUi.u(15); y: LcarsUi.u(24)
                            width: parent.width - x - LcarsUi.u(39)
                            height: LcarsUi.u(29)
                            text: message.modelData.summary || "Notification"
                            color: LcarsUi.ice; size: 22; caps: false
                            elide: Text.ElideRight
                        }
                        Text {
                            x: LcarsUi.u(15); y: LcarsUi.u(55)
                            width: parent.width - x; height: LcarsUi.u(32)
                            text: message.modelData.body
                            color: LcarsUi.lilac
                            font.family: LcarsUi.fontMono
                            font.pixelSize: Math.round(LcarsUi.u(15))
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            x: LcarsUi.u(15)
                            width: parent.width - x; height: LcarsUi.u(1)
                            color: LcarsUi.grey
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: message.modelData.active
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(message.modelData.key)
                        }
                        Rectangle {
                            x: parent.width - LcarsUi.u(35); y: 0
                            width: LcarsUi.u(35); height: LcarsUi.u(35)
                            radius: height / 2
                            color: LcarsUi.mauve
                            LcarsLabel {
                                anchors.fill: parent
                                text: "×"; size: 24; color: LcarsUi.shade
                                horizontalAlignment: Text.AlignHCenter
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismiss(message.modelData.key)
                            }
                        }
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
        LcarsLabel {
            visible: root.displayedItems.length === 0
            x: panel.contentLeft + LcarsUi.u(4); y: LcarsUi.u(125)
            width: panel.width - x - LcarsUi.u(18)
            text: root.showingRecent ? "NO RECENT NOTIFICATIONS" : "NO LIVE NOTIFICATIONS"
            size: 23; color: LcarsUi.lilac; fit: true
        }
        LcarsLabel {
            x: panel.contentLeft; y: panel.height - LcarsUi.u(55)
            width: LcarsUi.u(250); height: LcarsUi.u(26)
            text: "LCARS / RECENT ACTIVITY"
            color: LcarsUi.lilac
            size: 17; tracking: true; fit: true
        }
        Rectangle {
            visible: root.displayedItems.length > 0
            x: panel.width - LcarsUi.u(158)
            y: panel.height - LcarsUi.u(56)
            width: LcarsUi.u(140); height: LcarsUi.u(34)
            radius: height / 2
            color: LcarsUi.sky
            LcarsLabel {
                anchors.fill: parent
                text: "CLEAR ALL"
                color: LcarsUi.shade; size: 18
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAll()
            }
        }
        }
        }
    }
}
