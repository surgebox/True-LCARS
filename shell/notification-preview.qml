import QtQuick
import QtQuick.Window
import Quickshell
import "ui"
import "theme"

Window {
    id: preview
    width: 1440; height: 900; visible: true; color: "#000000"
    title: "LCARS notifications · offline preview"
    LcarsTextBar {
        id: topBar
        x: 0; y: LcarsUi.u(10)
        width: preview.width
        height: LcarsUi.u(56)
        text: "HELLO HENRY"
        notificationOpen: menu.open
        onNotificationsClicked: menu.toggle()
    }
    LcarsNotificationMenu {
        id: menu
        anchors.fill: parent
        originY: topBar.y + topBar.height
        backendEnabled: false
        open: true
        showingRecent: true
        items: [
            {app: "OMARCHY", summary: "System update available", body: "12 packages are ready to install.", timestamp: Date.now(), urgency: 1, active: true},
            {app: "MESSAGES", summary: "Incoming transmission", body: "Meet us at the starbase in twenty minutes.", timestamp: Date.now() - 360000, urgency: 1, active: false},
            {app: "SYSTEM", summary: "Battery low", body: "Connect power to continue working.", timestamp: Date.now() - 720000, urgency: 2, active: false},
            {app: "CALENDAR", summary: "Mission briefing", body: "Conference room, deck 4.", timestamp: Date.now() - 950000, urgency: 1, active: false},
            {app: "DOWNLOADS", summary: "Transfer complete", body: "The archive is ready to open.", timestamp: Date.now() - 1200000, urgency: 1, active: false}
        ]
    }
    Timer {
        interval: 1000; running: Quickshell.env("LCARS_CAPTURE") === "1"
        onTriggered: preview.contentItem.grabToImage(result => { result.saveToFile("/tmp/lcars-notification-preview.png"); Qt.quit() })
    }
}
