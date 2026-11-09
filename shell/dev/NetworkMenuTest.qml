import QtQuick
import QtTest
import "../ui"

TestCase {
    id: test
    name: "NetworkMenu"
    width: 1400; height: 1000
    visible: true
    when: true
    function initTestCase() { wait(200) }
    function cleanupTestCase() {
        console.log("NETWORK TESTS: " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed")
        Qt.exit(qtest_results.failCount > 0 ? 1 : 0)
    }
    property var sample: [
        {ssid: "Connected", bssid: "01", iface: "wlan0", active: true, signal: 90, secured: true, security: "WPA2", uuid: "saved"},
        {ssid: "New Wi-Fi", bssid: "02", iface: "wlan0", active: false, signal: 70, secured: true, security: "WPA2", uuid: ""},
        {ssid: "Guest", bssid: "03", iface: "wlan0", active: false, signal: 50, secured: false, security: "--", uuid: ""}
    ]
    LcarsNetworkMenu { id: menu; anchors.fill: parent; backendEnabled: false; ready: true }
    function init() {
        menu.close()
        menu.embedded = false
        menu.networkState = {radio: true, devices: [], networks: sample, connectivity: "full"}
        menu.busy = false
        menu.open = true
        menu.forceActiveFocus()
    }
    function test_centeredAndTouchTargets() {
        const panel = findChild(menu, "networkPanel")
        compare(panel.x + panel.width / 2, menu.width / 2)
        compare(panel.y + panel.height / 2, menu.height / 2)
        verify(findChild(menu, "networkRadio").height >= 48)
        verify(findChild(menu, "networkConnect").height >= 48)
        const list = findChild(menu, "networkList")
        mouseClick(list, 70, 35)
        compare(menu.selection.ssid, "Connected")
        verify(findChild(menu, "networkConnect").enabled)
    }
    function test_embeddedViewSpansAvailableWidth() {
        menu.embedded = true
        const panel = findChild(menu, "networkPanel")
        compare(panel.x, 0)
        compare(panel.width, menu.width)
        compare(panel.height, menu.height)
        compare(panel.scale, 1)
        verify(findChild(menu, "networkList").width > 1100)
    }
    function test_passwordRequiredOnlyForNewSecuredNetwork() {
        const connect = findChild(menu, "networkConnect")
        const password = findChild(menu, "networkPassword")
        menu.choose(sample[1])
        verify(password.visible)
        verify(!connect.enabled)
        password.text = "somepassword"
        verify(connect.enabled)
        menu.choose(sample[2])
        compare(password.text, "")
        verify(!password.visible)
        verify(connect.enabled)
    }
    function test_busyDisablesChanges() {
        menu.choose(sample[0])
        menu.busy = true
        verify(!findChild(menu, "networkConnect").enabled)
        verify(!findChild(menu, "networkRadio").enabled)
        verify(!findChild(menu, "networkScan").enabled)
    }
    function test_escapeClearsPasswordAndCloses() {
        menu.choose(sample[1])
        const password = findChild(menu, "networkPassword")
        password.text = "secret"
        password.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        compare(menu.open, false)
        compare(password.text, "")
        compare(menu.selected, null)
    }
    function test_reopenDoesNotRefocusPassword() {
        menu.choose(sample[1])
        const password = findChild(menu, "networkPassword")
        password.forceActiveFocus()
        verify(password.activeFocus)
        menu.close()
        menu.open = true
        verify(!password.activeFocus)
        menu.choose(sample[1])
        password.forceActiveFocus()
        verify(password.activeFocus)
    }
    function test_outsideTapDismissesInsideTapDoesNot() {
        const panel = findChild(menu, "networkPanel")
        mouseClick(panel, 40, 100)
        compare(menu.open, true)
        mouseClick(menu, 5, 5)
        compare(menu.open, false)
    }
}
