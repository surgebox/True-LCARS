import QtQuick
import "../theme"

// Keyboard position controller. The shell's bottom-band chevron drives its
// pointer methods; opening from rest reveals every key, dragging down peeks.
Item {
    id: root
    property bool open: false
    property var target: null
    property string targetLabel: ""
    property color frameColor: LcarsUi.mauve
    property real contentLeft: 0
    property real contentWidth: width
    property real minimumTop: LcarsUi.u(80)
    property real offset: 0
    property bool dragging: false
    property real dragTop: 0
    property real dragStartTop: 0
    property real dragStartPointer: 0
    property bool dragWasOpen: false

    readonly property real bottomMargin: 0
    readonly property real keyboardHeight: keyboard.height
    readonly property real naturalKeyboardHeight: keyboard.implicitHeight
    readonly property real spareRowHeight: keyboard.keyHeight + keyboard.keyGap
    readonly property real normalTop: height - naturalKeyboardHeight - bottomMargin - LcarsUi.u(8)
    readonly property real raisedTop: Math.max(minimumTop, normalTop - spareRowHeight)
    readonly property real peekTop: normalTop + naturalKeyboardHeight - LcarsUi.u(72)
    readonly property real hiddenTop: height
    readonly property real coveredTop: sheet.y

    signal enterPressed()

    function show(field, label) {
        target = field || null
        targetLabel = label || ""
        offset = 0
        open = true
    }
    function close() {
        open = false
        offset = 0
    }
    function toggle() {
        if (open) close()
        else { offset = 0; open = true }
    }
    function clearTarget(field) {
        if (target !== field) return
        target = null
        targetLabel = ""
        close()
    }
    function beginDrag(pointerY) {
        dragWasOpen = open
        dragStartPointer = pointerY
        dragStartTop = sheet.y
        dragTop = sheet.y
        dragging = true
    }
    function updateDrag(pointerY) {
        if (!dragging) return
        dragTop = Math.max(raisedTop, Math.min(hiddenTop,
            dragStartTop + pointerY - dragStartPointer))
    }
    function cancelDrag() { dragging = false }
    function endDrag(pointerY) {
        if (!dragging) return
        updateDrag(pointerY)
        const travel = pointerY - dragStartPointer
        const top = dragTop
        if (Math.abs(travel) < LcarsUi.u(12)) {
            toggle()
            dragging = false
            return
        }
        if (top > peekTop + LcarsUi.u(38)
            || (!dragWasOpen && top > hiddenTop - LcarsUi.u(70))) {
            close()
            dragging = false
            return
        }
        offset = Math.max(raisedTop - normalTop,
            Math.min(dragWasOpen ? peekTop - normalTop : 0, top - normalTop))
        open = true
        dragging = false
    }

    Item {
        id: sheet
        x: 0
        y: root.dragging ? root.dragTop : root.open
            ? Math.max(root.raisedTop, Math.min(root.peekTop, root.normalTop + root.offset))
            : root.hiddenTop
        width: root.width
        height: keyboard.height
        Behavior on y {
            enabled: !root.dragging
            NumberAnimation { duration: 280; easing.type: Easing.InOutQuad }
        }

        LcarsKeyboard {
            id: keyboard
            x: root.contentLeft + (root.contentWidth - width) / 2
            y: 0
            width: Math.min(implicitWidth, Math.max(0, root.contentWidth - LcarsUi.u(60)))
            // Stretch the two frame columns down to the fixed lower band when
            // the keys are raised. The key rows keep their natural top layout.
            height: Math.max(implicitHeight, root.height - root.bottomMargin - sheet.y)
            target: root.target
            targetLabel: root.targetLabel
            frameColor: root.frameColor
            onEnterPressed: root.enterPressed()
        }
    }
}
