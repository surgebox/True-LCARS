import QtQuick
import "../theme"

// Touch keyboard panel. The host owns its position and visibility; `target` is
// any TextInput or TextField with insert(), remove(), and cursorPosition.
Item {
    id: root

    property var target: null
    property string targetLabel: ""
    property color frameColor: LcarsUi.mauve
    property bool shifted: false
    property bool symbols: false
    readonly property real keyGap: LcarsUi.u(8)
    readonly property real keyHeight: LcarsUi.u(64)
    readonly property var letterRows: [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]
    readonly property var symbolRows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["@", "#", "$", "%", "&", "-", "+", "(", ")"],
        ["*", "\"", "'", ":", ";", "!", "?"]
    ]
    readonly property var alternateSymbolRows: [
        ["~", "`", "|", "\\", "^", "=", "{", "}", "[", "]"],
        ["_", "<", ">", "/", "*", "\"", "'", ":", ";"],
        ["+", "-", "!", "?", "@", "#", "$"]
    ]

    signal enterPressed()
    signal keyActivated(string key)

    implicitWidth: LcarsUi.u(1640)
    implicitHeight: LcarsUi.u(348)
    width: implicitWidth
    height: implicitHeight

    function replaceSelection(value) {
        if (!target || typeof target.insert !== "function" || typeof target.remove !== "function")
            return
        const start = Math.min(target.selectionStart, target.selectionEnd)
        const end = Math.max(target.selectionStart, target.selectionEnd)
        if (start >= 0 && end > start) {
            target.remove(start, end)
            target.cursorPosition = start
        }
        const position = target.cursorPosition
        target.insert(position, value)
        target.cursorPosition = position + value.length
    }

    function pressKey(key) {
        keyActivated(key)
        if (key === "shift") { shifted = !shifted; return }
        if (key === "mode") { symbols = !symbols; shifted = false; return }
        if (key === "enter") { enterPressed(); return }
        if (!target || typeof target.insert !== "function" || typeof target.remove !== "function")
            return

        if (key === "backspace") {
            const start = Math.min(target.selectionStart, target.selectionEnd)
            const end = Math.max(target.selectionStart, target.selectionEnd)
            if (start >= 0 && end > start) {
                target.remove(start, end)
                target.cursorPosition = start
            } else if (target.cursorPosition > 0) {
                const pos = target.cursorPosition
                target.remove(pos - 1, pos)
                target.cursorPosition = pos - 1
            }
            return
        }
        if (key === "left" || key === "right") {
            target.cursorPosition = Math.max(0, Math.min(target.text.length,
                target.cursorPosition + (key === "left" ? -1 : 1)))
            return
        }
        replaceSelection(key === "space" ? " " : (shifted && !symbols ? key : key.toLowerCase()))
        if (shifted) shifted = false
    }

    Rectangle { anchors.fill: parent; color: LcarsUi.black }
    MouseArea { anchors.fill: parent } // prevent touches between keys reaching content behind

    // Both elbows share the shell's lower-band color and frame the keys.
    LcarsElbow {
        x: 0; y: 0
        width: LcarsUi.u(420); height: root.height - LcarsUi.u(8)
        columnThickness: LcarsUi.u(58)
        barThickness: LcarsUi.u(42)
        outerRadius: LcarsUi.u(32)
        innerRadius: LcarsUi.u(16)
        color: root.frameColor
    }
    LcarsLabel {
        x: LcarsUi.u(76); y: 0
        width: LcarsUi.u(330); height: LcarsUi.u(42)
        text: root.target ? (root.targetLabel || root.target.objectName || "TEXT INPUT")
            : "NO FIELD SELECTED"
        color: LcarsUi.shade; size: 25; fit: true
    }
    LcarsStrip {
        x: LcarsUi.u(418); y: 0
        width: Math.max(0, root.width - LcarsUi.u(836)); height: LcarsUi.u(42)
        color: root.frameColor
    }
    LcarsElbow {
        x: root.width - LcarsUi.u(420); y: 0
        width: LcarsUi.u(420); height: root.height - LcarsUi.u(8)
        corner: "topRight"
        columnThickness: LcarsUi.u(58)
        barThickness: LcarsUi.u(42)
        outerRadius: LcarsUi.u(32)
        innerRadius: LcarsUi.u(16)
        color: root.frameColor
    }
    LcarsLabel {
        x: LcarsUi.u(428); y: 0
        width: root.width - x - LcarsUi.u(78); height: LcarsUi.u(42)
        text: root.symbols ? (root.shifted ? "EXTENDED / SYMBOLS" : "NUMERIC / SYMBOLS")
            : "ALPHANUMERIC / QWERTY"
        color: LcarsUi.shade; size: 24
        horizontalAlignment: Text.AlignRight
    }
    Column {
        id: keyRows
        x: LcarsUi.u(74); y: LcarsUi.u(60)
        width: root.width - x - LcarsUi.u(74)
        spacing: root.keyGap

        Repeater {
            model: 4
            delegate: Item {
                id: row
                required property int index
                readonly property var keys: {
                    if (index === 0) return root.symbols
                        ? (root.shifted ? root.alternateSymbolRows[0] : root.symbolRows[0]) : root.letterRows[0]
                    if (index === 1) return root.symbols
                        ? (root.shifted ? root.alternateSymbolRows[1] : root.symbolRows[1]) : root.letterRows[1]
                    if (index === 2) return ["shift"].concat(root.symbols
                        ? (root.shifted ? root.alternateSymbolRows[2] : root.symbolRows[2])
                        : root.letterRows[2], ["backspace"])
                    return ["mode", ",", "space", ".", "left", "right", "enter"]
                }
                readonly property real inset: index === 1 ? LcarsUi.u(40) : 0
                readonly property real totalUnits: index === 2 ? 9.8 : index === 3 ? 10.9 : keys.length
                width: keyRows.width
                height: root.keyHeight

                Row {
                    x: row.inset
                    width: row.width - row.inset
                    height: parent.height
                    spacing: root.keyGap
                    Repeater {
                        model: row.keys
                        delegate: Rectangle {
                            id: keycap
                            required property string modelData
                            readonly property string key: modelData
                            readonly property real weight: key === "space" ? 4.3
                                : key === "mode" ? 1.35
                                : key === "shift" || key === "backspace" ? 1.4
                                : key === "enter" ? 1.45
                                : key === "left" || key === "right" ? 0.9 : 1
                            width: (row.width - row.inset - root.keyGap * (row.keys.length - 1))
                                * weight / row.totalUnits
                            height: root.keyHeight
                            radius: Math.min(height / 2, LcarsUi.u(22))
                            color: key === "enter" ? LcarsUi.orange
                                : key === "backspace" ? LcarsUi.salmon
                                : key === "shift" ? (root.shifted ? LcarsUi.gold : LcarsUi.peach)
                                : key === "mode" ? (root.symbols ? LcarsUi.gold : LcarsUi.violet)
                                : key === "space" ? LcarsUi.gold
                                : row.index === 3 ? LcarsUi.violet
                                : root.symbols ? LcarsUi.lilac : LcarsUi.sky
                            opacity: touch.pressed ? 0.63 : 1
                            Behavior on opacity { NumberAnimation { duration: 80 } }

                            LcarsLabel {
                                anchors.fill: parent
                                text: keycap.key === "shift" ? (root.symbols ? "2/2" : "SHIFT")
                                    : keycap.key === "backspace" ? "⌫"
                                    : keycap.key === "mode" ? (root.symbols ? "ABC" : "?123")
                                    : keycap.key === "space" ? "SPACE"
                                    : keycap.key === "left" ? "◀"
                                    : keycap.key === "right" ? "▶"
                                    : keycap.key === "enter" ? "ENTER"
                                    : root.symbols || root.shifted ? keycap.key : keycap.key.toLowerCase()
                                caps: false
                                color: LcarsUi.shade
                                size: keycap.key.length > 1 ? 25 : 34
                                horizontalAlignment: Text.AlignHCenter
                                fit: true
                            }
                            MouseArea {
                                id: touch
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pressKey(keycap.key)
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: keycap.key === "backspace" ? "Backspace" : keycap.key
                        }
                    }
                }
            }
        }
    }
}
