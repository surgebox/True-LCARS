import QtQuick
import QtQuick.Window
import Quickshell
import "ui"

// Offline design preview. No network changes or NetworkManager process.
Window {
    id: preview
    width: 1440; height: 1000; visible: true; color: "#17141f"
    title: "LCARS network console · offline preview"
    LcarsNetworkMenu {
        id: menu
        anchors.fill: parent
        backendEnabled: false
        open: true
        ready: true
        trafficHistory: Array.from({length: 24}, (_, i) => ({
            rx: 21000 + 17000 * Math.sin(i * 0.55) ** 2 + (i % 5 === 0 ? 18000 : 0),
            tx: 6000 + 8500 * Math.cos(i * 0.42) ** 2
        }))
        connectionInfo: ({iface: "wlan0", type: "wifi", ip: "192.168.0.53", prefix: "24",
            gateway: "192.168.0.1", freq: "5240", bitrate: "867 Mbit/s",
            internet_ping_ms: "15", downloadBps: 234496, uploadBps: 18432})
        networkState: ({radio: true, connectivity: "full",
            devices: [{iface: "wlan0", type: "wifi", state: "connected", name: "STARBASE 47"}],
            networks: [
                {ssid: "STARBASE 47", bssid: "01", iface: "wlan0", active: true, signal: 94, security: "WPA2", secured: true, uuid: "saved"},
                {ssid: "USS Enterprise", bssid: "02", iface: "wlan0", active: false, signal: 78, security: "WPA2", secured: true, uuid: ""},
                {ssid: "Deep Space Nine", bssid: "03", iface: "wlan0", active: false, signal: 65, security: "WPA2 WPA3", secured: true, uuid: "saved2"},
                {ssid: "Federation Guest", bssid: "04", iface: "wlan0", active: false, signal: 43, security: "--", secured: false, uuid: ""},
                {ssid: "Science Division", bssid: "05", iface: "wlan0", active: false, signal: 28, security: "WPA2 802.1X", secured: true, enterprise: true, uuid: ""}
            ]})
        Component.onCompleted: choose(networkState.networks[1])
    }
    Timer {
        interval: 1000; running: Quickshell.env("LCARS_CAPTURE") === "1"
        onTriggered: menu.grabToImage(result => { result.saveToFile("/tmp/lcars-network-preview.png"); Qt.quit() })
    }
}
