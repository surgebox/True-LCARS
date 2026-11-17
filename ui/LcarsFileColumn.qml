import QtQuick
import QtQuick.Controls.Basic
import "../theme"

Rectangle {
    id: root
    property var directory: ({entries: []})
    property string filter: ""
    property int columnIndex: 0
    readonly property var headerPalette: [LcarsUi.amber, LcarsUi.peach, LcarsUi.mauve,
        LcarsUi.sky, LcarsUi.gold, LcarsUi.lilac, LcarsUi.rust]
    readonly property color headerColor: headerPalette[columnIndex % headerPalette.length]
    readonly property var sourceEntries: directory.entries || []
    readonly property var entries: sourceEntries.filter(e => e.name.toLowerCase().indexOf(filter.toLowerCase()) >= 0)
    signal chosen(var entry)
    signal openFile(var entry)
    signal moveFocus(int direction)
    color: "#0d0b12"
    radius: LcarsUi.u(18)
    border.color: list.activeFocus ? root.headerColor : "#4a394b"
    border.width: list.activeFocus ? 2 : 1

    function focusList() { list.forceActiveFocus() }
    onFilterChanged: list.contentY = 0

    Rectangle {
        id: heading
        x: LcarsUi.u(3); y: LcarsUi.u(3)
        width: parent.width - LcarsUi.u(6)
        height: LcarsUi.u(58)
        radius: height / 2
        color: root.headerColor
        LcarsLabel {
            x: LcarsUi.u(22); width: parent.width - LcarsUi.u(44)
            height: parent.height
            text: (root.columnIndex + 1).toString().padStart(2, "0")
                + "  /  " + (root.directory.name || "HOME")
            size: 27; fit: true
            color: LcarsUi.black
            elide: Text.ElideMiddle
        }
    }
    ListView {
        id: list
        objectName: "fileEntryList"
        anchors {
            top: heading.bottom; topMargin: LcarsUi.u(14)
            bottom: foot.top; bottomMargin: LcarsUi.u(8)
            left: parent.left; leftMargin: LcarsUi.u(8)
            right: parent.right; rightMargin: LcarsUi.u(8)
        }
        clip: true
        model: root.entries
        spacing: LcarsUi.u(7)
        currentIndex: -1
        onModelChanged: currentIndex = -1
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Keys.onRightPressed: {
            if (currentIndex >= 0 && root.entries[currentIndex].directory)
                root.chosen(root.entries[currentIndex])
            root.moveFocus(1)
        }
        Keys.onLeftPressed: root.moveFocus(-1)
        Keys.onReturnPressed: {
            if (currentIndex >= 0) {
                const entry = root.entries[currentIndex]
                if (entry.directory) { root.chosen(entry); root.moveFocus(1) }
                else root.openFile(entry)
            }
        }
        Keys.onUpPressed: {
            currentIndex = Math.max(0, currentIndex - 1)
            if (root.entries.length) root.chosen(root.entries[currentIndex])
        }
        Keys.onDownPressed: {
            currentIndex = Math.min(count - 1, currentIndex + 1)
            if (currentIndex >= 0) root.chosen(root.entries[currentIndex])
        }
        delegate: Rectangle {
            id: entryRow
            required property var modelData
            required property int index
            readonly property bool selectedEntry: modelData.path === root.directory.selected
            width: list.width - LcarsUi.u(3)
            height: LcarsUi.u(68)
            radius: LcarsUi.u(10)
            color: selectedEntry ? "#2b2432" : (hover.containsMouse ? "#1b1822" : "#15121b")
            border.color: selectedEntry ? root.headerColor : "#392e3e"
            border.width: selectedEntry ? 2 : 1
            Rectangle {
                x: 0; y: 0; width: LcarsUi.u(9); height: parent.height
                radius: LcarsUi.u(5)
                color: entryRow.modelData.directory ? root.headerColor : LcarsUi.violet
            }
            Text {
                x: LcarsUi.u(25); y: LcarsUi.u(7)
                width: parent.width - LcarsUi.u(73); height: LcarsUi.u(32)
                text: entryRow.modelData.name
                font.family: "sans-serif"; font.pixelSize: LcarsUi.u(21)
                color: LcarsUi.ice; elide: Text.ElideMiddle
                verticalAlignment: Text.AlignVCenter
            }
            LcarsLabel {
                x: LcarsUi.u(26); y: LcarsUi.u(39)
                width: parent.width - LcarsUi.u(74); height: LcarsUi.u(20)
                text: entryRow.modelData.directory ? "DIRECTORY" : entryRow.modelData.symlink ? "LINK" : "FILE"
                size: 15; color: entryRow.modelData.directory ? root.headerColor : LcarsUi.mauve
            }
            LcarsLabel {
                anchors.right: parent.right; anchors.rightMargin: LcarsUi.u(14)
                anchors.verticalCenter: parent.verticalCenter
                text: entryRow.modelData.directory ? "›" : "↗"
                color: root.headerColor; size: 32
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { list.currentIndex = index; list.forceActiveFocus(); root.chosen(entryRow.modelData) }
                onDoubleClicked: { if (!entryRow.modelData.directory) root.openFile(entryRow.modelData) }
            }
            Accessible.role: Accessible.Button
            Accessible.name: entryRow.modelData.name + (entryRow.modelData.directory ? ", directory" : ", file")
        }
        LcarsLabel {
            anchors.centerIn: parent
            width: parent.width - LcarsUi.u(24)
            text: root.directory.loading ? "READING DIRECTORY…"
                : (root.directory.error || (root.filter ? "NO MATCHING NAMES" : "EMPTY DIRECTORY"))
            visible: list.count === 0
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: root.directory.error ? LcarsUi.salmon : LcarsUi.mauve
            size: 21
        }
    }
    LcarsLabel {
        id: foot
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: LcarsUi.u(14) }
        height: LcarsUi.u(30)
        text: root.directory.truncated ? "FIRST 10,000 ITEMS / REFINE LOCATION" : list.count + " ITEMS"
        color: LcarsUi.mauve; size: 18
    }
}
