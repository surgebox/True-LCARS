import QtQuick
import QtTest
import "../ui"

TestCase {
    id: test
    name: "LcarsKeyboardDock"
    width: 2048
    height: 1152
    visible: true
    when: windowShown

    LcarsKeyboardDock { id: dock; anchors.fill: parent }

    function init() {
        dock.close()
        dock.target = null
        dock.targetLabel = ""
        wait(300)
    }

    function test_tapRevealsEveryKey() {
        compare(dock.coveredTop, dock.height)
        dock.beginDrag(dock.hiddenTop)
        dock.endDrag(dock.hiddenTop)
        compare(dock.open, true)
        compare(dock.offset, 0)
        wait(320)
        compare(dock.normalTop + dock.keyboardHeight + dock.bottomMargin, dock.height)
        dock.beginDrag(dock.coveredTop)
        dock.endDrag(dock.coveredTop)
        compare(dock.open, false)
    }

    function test_bottomButtonToggle() {
        dock.toggle()
        compare(dock.open, true)
        dock.toggle()
        compare(dock.open, false)
    }

    function test_raisePeekAndSwipeClosed() {
        dock.open = true
        wait(320)
        compare(dock.normalTop - dock.raisedTop, dock.spareRowHeight)
        const start = dock.coveredTop + 20
        dock.beginDrag(start)
        dock.endDrag(start - 120)
        compare(dock.open, true)
        compare(dock.offset, -dock.spareRowHeight)
        wait(320)
        const raised = dock.coveredTop + 20
        dock.beginDrag(raised)
        dock.endDrag(raised + 230)
        compare(dock.open, true)
        verify(dock.offset > 0)
        wait(320)
        const peek = dock.coveredTop + 20
        dock.beginDrag(peek)
        dock.endDrag(peek + 400)
        compare(dock.open, false)
    }

}
