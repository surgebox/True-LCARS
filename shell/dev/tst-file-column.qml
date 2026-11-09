import QtQuick
import QtTest
import "../ui"

TestCase {
    id: test
    name: "FileColumn"
    width: 500
    height: 600
    visible: true
    when: windowShown
    property string selectedPath: ""
    property var sampleEntries: [
        {name: "Alpha", path: "/Alpha", directory: true},
        {name: "Beta", path: "/Beta", directory: true},
        {name: "notes.txt", path: "/notes.txt", directory: false}
    ]
    LcarsFileColumn {
        id: column
        width: 400
        height: 500
        onChosen: entry => {
            test.selectedPath = entry.path
            directory = Object.assign({}, directory, {selected: entry.path})
        }
    }
    SignalSpy { id: opened; target: column; signalName: "openFile" }
    SignalSpy { id: moved; target: column; signalName: "moveFocus" }
    function init() {
        selectedPath = ""
        column.filter = ""
        column.directory = ({name: "ROOT", entries: sampleEntries, selected: ""})
        opened.clear()
        moved.clear()
        column.focusList()
    }
    function test_keyboardSelectionSurvivesPreviewUpdates() {
        keyClick(Qt.Key_Down)
        compare(selectedPath, "/Alpha")
        keyClick(Qt.Key_Down)
        compare(selectedPath, "/Beta")
        keyClick(Qt.Key_Up)
        compare(selectedPath, "/Alpha")
        keyClick(Qt.Key_Right)
        compare(moved.signalArguments[0][0], 1)
        keyClick(Qt.Key_Left)
        compare(moved.signalArguments[1][0], -1)
    }
    function test_filterAndExternalOpen() {
        column.filter = "NOTES"
        compare(column.entries.length, 1)
        keyClick(Qt.Key_Down)
        compare(selectedPath, "/notes.txt")
        keyClick(Qt.Key_Return)
        compare(opened.count, 1)
        compare(opened.signalArguments[0][0].path, "/notes.txt")
    }
    function test_touchSizedRowSelectsFolder() {
        const list = findChild(column, "fileEntryList")
        list.positionViewAtBeginning()
        wait(0)
        mouseClick(list, 90, 35)
        compare(selectedPath, "/Alpha")
        verify(column.directory.selected === "/Alpha")
    }
    function test_emptyColumn() {
        column.filter = "no matches"
        keyClick(Qt.Key_Down)
        keyClick(Qt.Key_Return)
        compare(selectedPath, "")
        compare(opened.count, 0)
    }
}
