import QtQuick
import QtQuick.Window
import "dev"

// Run with: qs -p network-test.qml (no hardware or network changes).
Window {
    width: 1400; height: 1000; visible: true
    NetworkMenuTest { anchors.fill: parent }
}
