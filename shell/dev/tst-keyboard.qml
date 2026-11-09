import QtQuick
import QtTest
import QtQuick.Controls.Basic
import "../ui"

TestCase {
    id: test
    name: "LcarsKeyboard"
    width: 1500
    height: 500
    visible: true
    when: windowShown

    TextInput { id: input; text: "" }
    TextField { id: password; echoMode: TextInput.Password }
    LcarsKeyboard { id: keyboard; target: input }
    SignalSpy { id: entered; target: keyboard; signalName: "enterPressed" }
    SignalSpy { id: activated; target: keyboard; signalName: "keyActivated" }

    function init() {
        input.text = ""
        input.cursorPosition = 0
        password.text = ""
        keyboard.target = input
        keyboard.shifted = false
        keyboard.symbols = false
        entered.clear()
        activated.clear()
    }

    function test_typingAndModes() {
        keyboard.pressKey("h")
        keyboard.pressKey("i")
        keyboard.pressKey("space")
        keyboard.pressKey("shift")
        keyboard.pressKey("Q")
        compare(input.text, "hi Q")
        compare(keyboard.shifted, false)
        keyboard.pressKey("mode")
        keyboard.pressKey("7")
        compare(input.text, "hi Q7")
        keyboard.pressKey("shift")
        keyboard.pressKey("~")
        compare(input.text, "hi Q7~")
        compare(keyboard.shifted, false)
        keyboard.pressKey("mode")
        compare(keyboard.symbols, false)
    }

    function test_selectionCursorAndBackspace() {
        input.text = "alpha"
        input.select(1, 4)
        keyboard.pressKey("Z")
        compare(input.text, "aza")
        compare(input.cursorPosition, 2)
        keyboard.pressKey("left")
        keyboard.pressKey("backspace")
        compare(input.text, "za")
        keyboard.pressKey("right")
        keyboard.pressKey("backspace")
        compare(input.text, "a")
    }

    function test_actionSignals() {
        keyboard.pressKey("enter")
        compare(entered.count, 1)
    }

    function test_touchAndPasswordField() {
        keyboard.target = password
        password.forceActiveFocus()
        mouseClick(keyboard, 130, 90)
        compare(activated.count, 1)
        compare(password.text, "q")
        compare(password.activeFocus, true)
        password.select(0, 1)
        keyboard.pressKey("shift")
        keyboard.pressKey("R")
        compare(password.text, "R")
    }
}
