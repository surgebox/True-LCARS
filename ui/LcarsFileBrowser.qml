import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    color: LcarsUi.black
    clip: true
    property var columns: []
    property var preview: ({})
    property bool previewLoading: false
    property bool showHidden: false
    property string homePath: ""
    property string selectedPath: ""
    property string serviceError: ""
    property int nextId: 0
    property int previewId: -1
    property var history: []
    property int historyIndex: -1
    property bool ready: false
    readonly property string currentPath: columns.length ? columns[columns.length - 1].path : ""
    readonly property bool canGoBack: ready && historyIndex > 0
    readonly property bool canGoForward: ready && historyIndex + 1 < history.length
    readonly property bool canGoUp: ready && currentPath !== "" && currentPath !== "/"
    readonly property real gap: LcarsUi.u(10)
    readonly property real previewWidth: Math.min(width * (columns.length < 2 ? 0.49 : 0.36),
        Math.max(LcarsUi.u(280), width - LcarsUi.u(330)))

    function send(op, path, page) {
        const id = ++nextId
        service.write(JSON.stringify({id: id, op: op, path: path, hidden: showHidden, page: page || 1}) + "\n")
        return id
    }
    function record(path) {
        if (historyIndex >= 0 && history[historyIndex] === path) return
        const copy = history.slice(0, historyIndex + 1)
        copy.push(path)
        history = copy
        historyIndex = copy.length - 1
    }
    function makeColumn(path) {
        return {path: path, name: path.split("/").pop() || "/", entries: [], selected: "", loading: true,
                request: send("list", path)}
    }
    function navigate(path, remember) {
        if (!ready) return
        previewId = -1
        preview = ({})
        previewLoading = false
        selectedPath = ""
        nameFilter.text = ""
        columns = [makeColumn(path)]
        if (remember !== false) record(path)
        columnScroll.contentX = 0
    }
    function focusLocation() {
        directoryPath.text = currentPath
        directoryPath.forceActiveFocus()
        directoryPath.selectAll()
    }
    function submitLocation() {
        const path = directoryPath.text.trim()
        if (!path) return
        navigate(path)
        focusColumn(0)
    }
    onCurrentPathChanged: {
        if (!directoryPath.activeFocus) directoryPath.text = currentPath
    }
    function up() {
        if (!currentPath || currentPath === "/") return
        const path = currentPath.substring(0, currentPath.lastIndexOf("/")) || "/"
        if (columns.length > 1) {
            columns = columns.slice(0, -1)
            previewId = -1; preview = ({}); previewLoading = false; selectedPath = ""
            record(path)
        } else navigate(path)
    }
    function goBack() {
        if (!canGoBack) return
        historyIndex--
        navigate(history[historyIndex], false)
    }
    function goForward() {
        if (!canGoForward) return
        historyIndex++
        navigate(history[historyIndex], false)
    }
    function toggleHidden() {
        showHidden = !showHidden
        refresh()
    }
    function inspect(path, page) {
        selectedPath = path
        previewLoading = true
        if (!page) preview = ({name: path.split("/").pop()})
        previewId = send("preview", path, page)
    }
    function choose(column, entry) {
        const copy = columns.slice(0, column + 1)
        copy[column] = Object.assign({}, copy[column], {selected: entry.path})
        if (entry.directory) {
            copy.push(makeColumn(entry.path))
            record(entry.path)
        }
        columns = copy
        inspect(entry.path)
        revealTimer.restart()
    }
    function revealLast() {
        columnScroll.contentX = Math.max(0, columnScroll.contentWidth - columnScroll.width)
    }
    function focusColumn(index) {
        const column = columnRepeater.itemAt(Math.max(0, Math.min(columns.length - 1, index))) as LcarsFileColumn
        if (column) column.focusList()
    }
    function openFile(entry) {
        // Build a file URL without treating filename characters as URI syntax.
        Qt.openUrlExternally("file://" + entry.path.split("/").map(encodeURIComponent).join("/"))
    }
    function refresh() {
        const copy = columns.map(c => Object.assign({}, c, {loading: true, error: "", request: send("list", c.path)}))
        columns = copy
        if (selectedPath) inspect(selectedPath)
    }
    function receive(message) {
        if (message.op === "list") {
            const index = columns.findIndex(c => c.request === message.id)
            if (index < 0) return
            const copy = columns.slice()
            copy[index] = Object.assign({}, copy[index], message, {loading: false,
                name: message.path.split("/").pop() || "/"})
            columns = copy
            if (!homePath) homePath = message.path
            revealTimer.restart()
        } else if (message.id === previewId) {
            preview = message
            previewLoading = false
        }
    }

    Process {
        id: service
        command: ["python3", "-u", decodeURIComponent(Qt.resolvedUrl("../scripts/files.py").toString().replace(/^file:\/\//, ""))]
        stdinEnabled: true
        running: true
        onStarted: { root.ready = true; root.serviceError = ""; root.navigate(root.currentPath || "") }
        onExited: {
            root.ready = false
            root.previewLoading = false
            root.serviceError = "File service stopped. Select RECONNECT to retry."
        }
        stdout: SplitParser {
            onRead: data => {
                try { root.receive(JSON.parse(data)) }
                catch (error) { root.serviceError = "Could not read a file-service response: " + error }
            }
        }
    }

    signal inputFocused(var field, string label)
    signal inputBlurred(var field)
    readonly property var filterField: nameFilter
    readonly property var locationField: directoryPath
    Shortcut { sequence: "Ctrl+L"; enabled: root.visible; onActivated: root.focusLocation() }
    Shortcut { sequence: "Alt+Up"; enabled: root.visible; onActivated: root.up() }
    Shortcut { sequence: "Alt+Left"; enabled: root.visible && root.canGoBack; onActivated: root.goBack() }
    Shortcut { sequence: "Alt+Right"; enabled: root.visible && root.canGoForward; onActivated: root.goForward() }
    Shortcut { sequence: "Ctrl+H"; enabled: root.visible; onActivated: root.toggleHidden() }
    Shortcut { sequence: "F5"; enabled: root.visible; onActivated: root.refresh() }

    Timer { id: revealTimer; interval: 310; onTriggered: root.revealLast() }

    Rectangle {
        id: toolbar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        readonly property bool compact: width < LcarsUi.u(1100)
        height: compact ? LcarsUi.u(122) : LcarsUi.u(66)
        color: "#131016"
        border.color: "#513627"
        border.width: 1

        Rectangle { width: LcarsUi.u(10); height: parent.height; color: LcarsUi.rust }
        LcarsLabel {
            x: LcarsUi.u(24); y: 0; width: LcarsUi.u(150); height: LcarsUi.u(66)
            text: "FILTER /"; color: LcarsUi.peach; size: 25
        }
        TextField {
            id: nameFilter
            x: LcarsUi.u(178)
            y: LcarsUi.u(7)
            width: toolbar.compact ? Math.max(LcarsUi.u(120), toolbar.width - x - LcarsUi.u(80))
                : Math.min(LcarsUi.u(620), toolbar.width * 0.38)
            height: LcarsUi.u(52)
            placeholderText: "FILTER FILES / FOLDERS"
            color: LcarsUi.ice
            placeholderTextColor: LcarsUi.mauve
            font.family: LcarsUi.font
            font.pixelSize: LcarsUi.u(24)
            leftPadding: LcarsUi.u(15)
            onActiveFocusChanged: {
                if (activeFocus) root.inputFocused(nameFilter, "FILE FILTER")
                else root.inputBlurred(nameFilter)
            }
            background: Rectangle {
                color: "#1b1620"
                border.color: nameFilter.activeFocus ? LcarsUi.violet : "#5d465c"
                border.width: nameFilter.activeFocus ? 2 : 1
                radius: LcarsUi.u(8)
            }
        }
        LcarsFileAction {
            id: clearFilter
            x: nameFilter.x + nameFilter.width + LcarsUi.u(8)
            y: LcarsUi.u(7)
            width: LcarsUi.u(58); height: LcarsUi.u(52)
            text: "×"; visible: nameFilter.text.length > 0
            onClicked: nameFilter.clear()
            Accessible.role: Accessible.Button
            Accessible.name: "Clear file filter"
        }
        LcarsLabel {
            id: pathLabel
            x: toolbar.compact ? LcarsUi.u(24) : clearFilter.x + clearFilter.width + LcarsUi.u(16)
            y: toolbar.compact ? LcarsUi.u(56) : 0
            width: LcarsUi.u(100); height: LcarsUi.u(66)
            text: "PATH /"; color: LcarsUi.peach; size: 25
        }
        TextField {
            id: directoryPath
            objectName: "directoryPath"
            x: toolbar.compact ? LcarsUi.u(178) : pathLabel.x + pathLabel.width
            y: toolbar.compact ? LcarsUi.u(63) : LcarsUi.u(7)
            width: Math.max(0, toolbar.width - x - LcarsUi.u(12))
            height: LcarsUi.u(52)
            enabled: root.ready
            text: root.currentPath
            placeholderText: "DIRECTORY PATH"
            color: LcarsUi.ice
            placeholderTextColor: LcarsUi.mauve
            selectionColor: LcarsUi.violet
            selectedTextColor: LcarsUi.black
            font.family: LcarsUi.font
            font.pixelSize: LcarsUi.u(23)
            leftPadding: LcarsUi.u(15)
            selectByMouse: true
            onAccepted: root.submitLocation()
            onActiveFocusChanged: {
                if (activeFocus) root.inputFocused(directoryPath, "DIRECTORY PATH")
                else root.inputBlurred(directoryPath)
            }
            background: Rectangle {
                color: "#1b1620"
                border.color: directoryPath.activeFocus ? LcarsUi.violet : "#5d465c"
                border.width: directoryPath.activeFocus ? 2 : 1
                radius: LcarsUi.u(8)
            }
        }
    }
    Flickable {
        id: columnScroll
        anchors { top: toolbar.bottom; left: parent.left; right: previewPane.left; bottom: footer.top; topMargin: root.gap; rightMargin: root.gap; bottomMargin: root.gap }
        clip: true
        contentWidth: columnRow.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        Row {
            id: columnRow
            height: columnScroll.height - LcarsUi.u(12)
            spacing: root.gap
            Repeater {
                id: columnRepeater
                model: root.columns.length
                delegate: LcarsFileColumn {
                    width: Math.max(LcarsUi.u(300), (columnScroll.width
                        - root.gap * (Math.min(3, root.columns.length) - 1))
                        / Math.min(3, Math.max(1, root.columns.length)))
                    Behavior on width { NumberAnimation { duration: 270; easing.type: Easing.InOutQuad } }
                    height: columnRow.height
                    directory: root.columns[index]
                    columnIndex: index
                    filter: nameFilter.text
                    onChosen: entry => root.choose(index, entry)
                    onOpenFile: entry => root.openFile(entry)
                    onMoveFocus: direction => root.focusColumn(index + direction)
                }
            }
        }
    }
    LcarsFilePreview {
        id: previewPane
        anchors { top: columnScroll.top; bottom: columnScroll.bottom; right: parent.right }
        width: root.previewWidth
        Behavior on width { NumberAnimation { duration: 270; easing.type: Easing.InOutQuad } }
        file: root.preview
        loading: root.previewLoading
        browserVisible: root.visible
        onPageRequested: page => root.inspect(root.selectedPath, page)
        onOpenRequested: Qt.openUrlExternally(root.preview.url)
    }
    Rectangle {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: LcarsUi.u(root.serviceError ? 56 : 42)
        color: "#17121a"
        Rectangle { width: parent.width; height: LcarsUi.u(3); color: LcarsUi.rust }
        LcarsFileAction {
            x: LcarsUi.u(10); anchors.verticalCenter: parent.verticalCenter
            height: LcarsUi.u(48)
            text: "RECONNECT"; visible: !!root.serviceError
            onClicked: service.running = true
        }
        LcarsLabel {
            x: root.serviceError ? LcarsUi.u(160) : LcarsUi.u(16)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - LcarsUi.u(16)
            text: root.serviceError || (root.columns.length + " COLUMNS   /   TAP A FOLDER TO EXPAND   /   TAP A FILE TO PREVIEW   /   SWIPE TO SCROLL")
            color: root.serviceError ? LcarsUi.salmon : LcarsUi.mauve
            size: 18; fit: true
        }
    }
}
