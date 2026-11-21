import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Io
import "../theme"

FocusScope {
    id: root
    property bool open: false
    property bool ready: false
    property string tab: "my"
    property var apps: []
    property var pendingRemoval: null
    property var results: []
    property var selectedResult: null
    property var selectedRemovalApp: null
    property string error: ""
    property string activity: ""
    property bool installing: false
    property string operation: "install"
    property string terminalOutput: ""
    property string terminalTitle: "READY"
    property bool passwordPrompt: false
    property bool terminalPendingReturn: false
    property bool terminalFollowOutput: true
    property int terminalProgress: -1
    property int terminalPulse: 0
    readonly property var searchField: searchBox
    readonly property var terminalField: terminalInput
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../scripts/launcher.py").toString().replace(/^file:\/\//, ""))
    readonly property var visibleApps: {
        const query = searchBox.text.toLowerCase().trim()
        const items = apps.filter(app =>
            (tab === "all" || tab === "uninstall" || app.pinned || app.lastUsed > 0)
            && (app.name + " " + app.description).toLowerCase().includes(query))
        if (tab === "my") items.sort((a, b) =>
            Number(b.pinned) - Number(a.pinned)
            || b.lastUsed - a.lastUsed || a.name.localeCompare(b.name))
        else items.sort((a, b) => a.name.localeCompare(b.name))
        return items
    }
    signal launched()
    signal inputFocused(var field, string label)
    signal inputBlurred(var field)

    visible: open
    enabled: open
    clip: true
    onOpenChanged: {
        if (open) {
            if (!installing) {
                setTab("my")
                searchBox.clear()
            }
            if (ready) request({op: "apps"})
        }
        if (!open) {
            if (searchBox.activeFocus) searchBox.focus = false
            if (terminalInput.activeFocus) terminalInput.focus = false
            root.inputBlurred(searchBox)
            root.inputBlurred(terminalInput)
        }
    }
    function request(data) {
        if (ready) service.write(JSON.stringify(data) + "\n")
    }
    function setTab(value) {
        if (tab === value) return
        tab = value
        searchTimer.stop()
        searchBox.clear()
        selectedResult = null
        selectedRemovalApp = null
        error = ""
        activity = ""
        if (value !== "install") {
            results = []
            request({op: "search", query: ""})
            request({op: "apps"})
        }
    }
    function refresh() {
        if (tab !== "install") request({op: "apps"})
        else if (searchBox.text.trim().length >= 2) request({op: "search", query: searchBox.text})
    }
    function submitTerminalInput() {
        if (!installing) return
        request({op: "install_input", text: terminalInput.text})
        terminalInput.clear()
        passwordPrompt = false
    }
    function appendTerminalOutput(value) {
        // Package managers redraw progress with CR. Keep only the latest
        // version of that line, including when CR and its text cross chunks.
        let output = terminalOutput
        const atBottom = terminalScroll.contentY >= terminalScroll.contentHeight
            - terminalScroll.height - LcarsUi.u(20)
        for (let i = 0; i < value.length; i++) {
            const ch = value[i]
            if (ch === "\r") {
                terminalPendingReturn = true
                continue
            }
            if (ch === "\n") {
                terminalPendingReturn = false
                output += "\n"
                continue
            }
            if (terminalPendingReturn) {
                output = output.slice(0, output.lastIndexOf("\n") + 1)
                terminalPendingReturn = false
            }
            if (ch === "\b") {
                if (output.length && output[output.length - 1] !== "\n")
                    output = output.slice(0, -1)
            } else output += ch
        }
        const percentPattern = /(\d{1,3})%/g
        const recentOutput = output.slice(-500)
        let percentMatch
        let latestPercent = null
        while ((percentMatch = percentPattern.exec(recentOutput)) !== null)
            latestPercent = Number(percentMatch[1])
        if (latestPercent !== null)
            terminalProgress = Math.max(0, Math.min(100, latestPercent))
        terminalFollowOutput = atBottom
        terminalOutput = output.slice(-40000)
    }
    onTerminalOutputChanged: Qt.callLater(() => {
        if (terminalFollowOutput)
            terminalScroll.contentY = Math.max(0, terminalScroll.contentHeight - terminalScroll.height)
    })
    Timer {
        interval: 180
        repeat: true
        running: root.installing && root.terminalProgress < 0
        onTriggered: root.terminalPulse = (root.terminalPulse + 1) % 16
    }

    Process {
        id: service
        command: ["python3", "-u", root.script]
        stdinEnabled: true
        running: root.open || root.installing
        onStarted: { root.ready = true; root.request({op: "apps"}) }
        onExited: { root.ready = false; if (root.open) root.error = "Launcher service stopped. Reopen LAUNCH to retry." }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const message = JSON.parse(line)
                    if (message.op === "apps") {
                        root.apps = message.apps || []
                        if (root.selectedRemovalApp && !root.apps.some(app => app.id === root.selectedRemovalApp.id))
                            root.selectedRemovalApp = null
                    }
                    else if (message.op === "search") {
                        root.results = message.results || []
                        root.error = message.error || ""
                        root.activity = ""
                    } else if (message.op === "launch") {
                        root.error = message.error || ""
                        if (!message.error) root.launched()
                    } else if (message.op === "install_started") {
                        root.installing = true
                        root.operation = message.action || "install"
                        root.terminalPendingReturn = false
                        root.terminalFollowOutput = true
                        root.terminalProgress = -1
                        root.terminalPulse = 0
                        root.terminalOutput = (root.operation === "uninstall" ? "Removing " : "Installing ")
                            + message.name + " // " + message.source + "...\n\n"
                        root.terminalTitle = message.name
                        root.error = ""
                        root.activity = root.operation === "uninstall"
                            ? "REMOVAL IN PROGRESS" : "INSTALLATION IN PROGRESS"
                    } else if (message.op === "install_output") {
                        root.appendTerminalOutput(message.text || "")
                        root.passwordPrompt = /password|passphrase/i.test(root.terminalOutput.slice(-160))
                    } else if (message.op === "install_finished") {
                        root.installing = false
                        root.passwordPrompt = false
                        if (message.code === 0) root.terminalProgress = 100
                        root.appendTerminalOutput("\nProcess exited with code " + message.code + ".\n")
                        root.activity = message.code === 0
                            ? (root.operation === "uninstall" ? "REMOVAL COMPLETE" : "INSTALLATION COMPLETE")
                            : (root.operation === "uninstall" ? "REMOVAL ENDED WITH ERROR" : "INSTALLATION ENDED WITH ERROR")
                        if (root.tab === "install" && searchBox.text.trim().length >= 2) root.refresh()
                    } else if (message.op === "uninstall_prepared") {
                        root.error = message.error || ""
                        if (!message.error) root.pendingRemoval = message
                    } else if (message.op === "install" || message.op === "uninstall"
                               || message.op === "toggle_pin") {
                        root.error = message.error || ""
                    } else if (message.error) root.error = message.error
                } catch (e) { root.error = "Invalid launcher response." }
            }
        }
    }
    Timer {
        id: searchTimer
        interval: 350
        onTriggered: {
            root.results = []
            root.selectedResult = null
            root.error = ""
            if (searchBox.text.trim().length >= 2) {
                root.activity = "SEARCHING SOFTWARE SOURCES..."
                root.request({op: "search", query: searchBox.text.trim()})
            } else root.activity = "Enter at least two characters to search."
        }
    }

    Rectangle { anchors.fill: parent; color: LcarsUi.black }
    LcarsLabel {
        x: LcarsUi.u(25); y: LcarsUi.u(10)
        width: parent.width - LcarsUi.u(50); height: LcarsUi.u(46)
        text: "LAUNCH // APPLICATION ACCESS"; color: LcarsUi.peach; size: 35
    }
    Row {
        id: tabs
        x: LcarsUi.u(25); y: LcarsUi.u(62)
        spacing: LcarsUi.u(10)
        LcarsFileAction {
            width: LcarsUi.u(160); height: LcarsUi.u(48)
            text: "MY APPS"; selected: root.tab === "my"
            onClicked: root.setTab("my")
        }
        LcarsFileAction {
            width: LcarsUi.u(160); height: LcarsUi.u(48)
            text: "ALL APPS"; selected: root.tab === "all"
            onClicked: root.setTab("all")
        }
        LcarsFileAction {
            width: LcarsUi.u(160); height: LcarsUi.u(48)
            text: "INSTALL"; selected: root.tab === "install"
            onClicked: root.setTab("install")
        }
        LcarsFileAction {
            width: LcarsUi.u(160); height: LcarsUi.u(48)
            text: "UNINSTALL"; selected: root.tab === "uninstall"
            onClicked: root.setTab("uninstall")
        }
    }
    TextField {
        id: searchBox
        x: LcarsUi.u(25); y: LcarsUi.u(125)
        width: Math.max(0, parent.width - LcarsUi.u(50)); height: LcarsUi.u(55)
        placeholderText: root.tab === "my" ? "SEARCH MY APPS"
            : root.tab === "all" ? "SEARCH ALL INSTALLED APPS"
            : root.tab === "uninstall" ? "SEARCH INSTALLED APPS TO REMOVE"
            : "SEARCH FLATHUB AND FEDORA PACKAGES"
        color: LcarsUi.ice; placeholderTextColor: LcarsUi.mauve
        font.family: LcarsUi.font; font.pixelSize: LcarsUi.u(25)
        leftPadding: LcarsUi.u(15)
        onTextChanged: {
            if (root.tab === "install") {
                root.selectedResult = null
                searchTimer.restart()
            } else if (root.tab === "uninstall") root.selectedRemovalApp = null
        }
        onActiveFocusChanged: {
            if (activeFocus) root.inputFocused(searchBox, "APP SEARCH")
            else root.inputBlurred(searchBox)
        }
        background: Rectangle {
            color: "#1b1620"
            border.color: searchBox.activeFocus ? LcarsUi.peach : LcarsUi.mauve
            border.width: searchBox.activeFocus ? 2 : 1
            radius: LcarsUi.u(8)
        }
    }
    LcarsLabel {
        x: LcarsUi.u(25); y: LcarsUi.u(192)
        width: parent.width - LcarsUi.u(50); height: LcarsUi.u(32)
        text: root.tab === "my" ? root.visibleApps.length + " RECENT AND PINNED APPS"
            : root.tab === "all" ? root.visibleApps.length + " INSTALLED APPLICATIONS"
            : root.tab === "uninstall" ? root.visibleApps.length + " INSTALLED APPLICATIONS // SELECT TO REMOVE"
            : root.results.length + " RESULTS // FLATHUB + FEDORA"
        color: LcarsUi.violet; size: 20
    }
    GridView {
        id: appsGrid
        visible: root.tab === "my" || root.tab === "all"
        x: LcarsUi.u(25); y: LcarsUi.u(230)
        width: parent.width - LcarsUi.u(50)
        height: Math.max(0, parent.height - y - LcarsUi.u(52))
        clip: true
        cellWidth: width / 2
        cellHeight: LcarsUi.u(94)
        model: root.visibleApps
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Item {
            id: appCell
            required property var modelData
            width: appsGrid.cellWidth; height: appsGrid.cellHeight
            Rectangle {
                anchors.fill: parent; anchors.margins: LcarsUi.u(4)
                radius: LcarsUi.u(12)
                color: appHover.containsMouse ? "#211922" : "#100d14"
                border.color: appCell.modelData.pinned ? LcarsUi.gold : "#58475d"
                border.width: 1
                Rectangle {
                    x: LcarsUi.u(13); anchors.verticalCenter: parent.verticalCenter
                    width: LcarsUi.u(58); height: LcarsUi.u(58)
                    radius: LcarsUi.u(11); color: "#292031"
                    LcarsLabel {
                        anchors.centerIn: parent
                        text: appCell.modelData.name.slice(0, 1)
                        color: LcarsUi.peach; size: 31
                    }
                    Image {
                        anchors.centerIn: parent
                        width: LcarsUi.u(48); height: LcarsUi.u(48)
                        sourceSize.width: 96; sourceSize.height: 96
                        source: appCell.modelData.iconUrl || ""
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                }
                LcarsLabel {
                    x: LcarsUi.u(82); y: LcarsUi.u(10)
                    width: parent.width - x - LcarsUi.u(75); height: LcarsUi.u(31)
                    text: appCell.modelData.name; color: LcarsUi.peach; size: 25
                    elide: Text.ElideRight
                }
                LcarsLabel {
                    x: LcarsUi.u(82); y: LcarsUi.u(41)
                    width: parent.width - x - LcarsUi.u(75); height: LcarsUi.u(29)
                    text: appCell.modelData.description || "OPEN APPLICATION"
                    color: LcarsUi.ice; size: 18; caps: false
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: appHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.request({op: "launch", id: appCell.modelData.id})
                }
                Rectangle {
                    x: parent.width - width - LcarsUi.u(13)
                    anchors.verticalCenter: parent.verticalCenter
                    width: LcarsUi.u(52); height: LcarsUi.u(52)
                    radius: LcarsUi.u(10)
                    color: appCell.modelData.pinned ? LcarsUi.gold : "#292031"
                    border.color: appCell.modelData.pinned ? LcarsUi.gold : LcarsUi.mauve
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "★"
                        color: appCell.modelData.pinned ? LcarsUi.black : LcarsUi.mauve
                        font.family: "DejaVu Sans"
                        font.pixelSize: LcarsUi.u(31)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: (appCell.modelData.pinned ? "Unpin " : "Pin ") + appCell.modelData.name
                        onClicked: root.request({op: "toggle_pin", id: appCell.modelData.id})
                    }
                }
            }
        }
    }
    LcarsLabel {
        visible: (root.tab === "my" || root.tab === "all") && appsGrid.count === 0
        anchors.centerIn: appsGrid
        width: appsGrid.width; height: LcarsUi.u(50)
        horizontalAlignment: Text.AlignHCenter
        text: root.tab === "my" && !searchBox.text
            ? "NO RECENT APPS // OPEN OR PIN ONE FROM ALL APPS"
            : "NO MATCHING APPS"
        color: LcarsUi.mauve; size: 25
    }
    ListView {
        id: installList
        visible: root.tab === "install"
        x: LcarsUi.u(25); y: LcarsUi.u(230)
        width: Math.max(LcarsUi.u(310), (parent.width - LcarsUi.u(70)) * 0.43)
        height: Math.max(0, parent.height - y - LcarsUi.u(132))
        clip: true; spacing: LcarsUi.u(7)
        model: root.results
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Rectangle {
            id: resultRow
            required property var modelData
            width: installList.width - LcarsUi.u(12); height: LcarsUi.u(76)
            radius: LcarsUi.u(12)
            color: root.selectedResult && root.selectedResult.key === modelData.key
                ? "#302336" : (resultHover.containsMouse ? "#211922" : "#100d14")
            border.color: root.selectedResult && root.selectedResult.key === modelData.key
                ? LcarsUi.peach : "#58475d"
            border.width: 1
            LcarsLabel {
                x: LcarsUi.u(15); y: LcarsUi.u(7)
                width: parent.width - LcarsUi.u(30); height: LcarsUi.u(32)
                text: resultRow.modelData.name; color: LcarsUi.peach; size: 25
                elide: Text.ElideRight
            }
            LcarsLabel {
                x: LcarsUi.u(15); y: LcarsUi.u(39)
                width: parent.width - LcarsUi.u(30); height: LcarsUi.u(26)
                text: resultRow.modelData.source + " // " + (resultRow.modelData.description || "")
                color: LcarsUi.ice; size: 18; caps: false
                elide: Text.ElideRight
            }
            MouseArea {
                id: resultHover
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedResult = resultRow.modelData
            }
        }
    }
    LcarsLabel {
        visible: root.tab === "install" && installList.count === 0
        anchors.centerIn: installList
        width: installList.width; height: LcarsUi.u(50)
        horizontalAlignment: Text.AlignHCenter
        text: "SEARCH FOR AN APP TO INSTALL"; color: LcarsUi.mauve; size: 25
    }
    Rectangle {
        visible: root.tab === "install"
        x: installList.x; y: parent.height - LcarsUi.u(120)
        width: installList.width; height: LcarsUi.u(64)
        color: "#171119"; radius: LcarsUi.u(12)
        LcarsLabel {
            x: LcarsUi.u(16); width: parent.width - installButton.width - LcarsUi.u(40)
            height: parent.height
            text: root.selectedResult ? root.selectedResult.name + " // " + root.selectedResult.source
                + (root.selectedResult.installed ? " // INSTALLED" : "")
                : ""
            color: LcarsUi.ice; size: 22; elide: Text.ElideRight
        }
        LcarsFileAction {
            id: installButton
            anchors.right: parent.right; anchors.rightMargin: LcarsUi.u(8)
            anchors.verticalCenter: parent.verticalCenter
            width: LcarsUi.u(126); height: LcarsUi.u(48)
            enabled: !!root.selectedResult && !root.selectedResult.installed && !root.installing
            text: "INSTALL"
            onClicked: root.request({op: "install", key: root.selectedResult.key})
        }
    }
    ListView {
        id: uninstallList
        visible: root.tab === "uninstall"
        x: LcarsUi.u(25); y: LcarsUi.u(230)
        width: Math.max(LcarsUi.u(310), (parent.width - LcarsUi.u(70)) * 0.43)
        height: Math.max(0, parent.height - y - LcarsUi.u(132))
        clip: true; spacing: LcarsUi.u(7)
        model: root.visibleApps
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Rectangle {
            id: removalRow
            required property var modelData
            width: uninstallList.width - LcarsUi.u(12); height: LcarsUi.u(76)
            radius: LcarsUi.u(12)
            color: root.selectedRemovalApp && root.selectedRemovalApp.id === modelData.id
                ? "#302336" : (removalHover.containsMouse ? "#211922" : "#100d14")
            border.color: root.selectedRemovalApp && root.selectedRemovalApp.id === modelData.id
                ? LcarsUi.salmon : "#58475d"
            border.width: 1
            Rectangle {
                x: LcarsUi.u(9); anchors.verticalCenter: parent.verticalCenter
                width: LcarsUi.u(52); height: LcarsUi.u(52)
                radius: LcarsUi.u(10); color: "#292031"
                LcarsLabel {
                    anchors.centerIn: parent
                    text: removalRow.modelData.name.slice(0, 1)
                    color: LcarsUi.peach; size: 29
                }
                Image {
                    anchors.centerIn: parent
                    width: LcarsUi.u(44); height: LcarsUi.u(44)
                    sourceSize.width: 88; sourceSize.height: 88
                    source: removalRow.modelData.iconUrl || ""
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
            }
            LcarsLabel {
                x: LcarsUi.u(72); y: LcarsUi.u(7)
                width: parent.width - x - LcarsUi.u(12); height: LcarsUi.u(32)
                text: removalRow.modelData.name; color: LcarsUi.peach; size: 25
                elide: Text.ElideRight
            }
            LcarsLabel {
                x: LcarsUi.u(72); y: LcarsUi.u(39)
                width: parent.width - x - LcarsUi.u(12); height: LcarsUi.u(26)
                text: removalRow.modelData.description || "INSTALLED APPLICATION"
                color: LcarsUi.ice; size: 18; caps: false
                elide: Text.ElideRight
            }
            MouseArea {
                id: removalHover
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedRemovalApp = removalRow.modelData
            }
        }
    }
    LcarsLabel {
        visible: root.tab === "uninstall" && uninstallList.count === 0
        anchors.centerIn: uninstallList
        width: uninstallList.width; height: LcarsUi.u(50)
        horizontalAlignment: Text.AlignHCenter
        text: "NO MATCHING INSTALLED APPS"; color: LcarsUi.mauve; size: 25
    }
    Rectangle {
        visible: root.tab === "uninstall"
        x: uninstallList.x; y: parent.height - LcarsUi.u(120)
        width: uninstallList.width; height: LcarsUi.u(64)
        color: "#171119"; radius: LcarsUi.u(12)
        LcarsLabel {
            x: LcarsUi.u(16); width: parent.width - uninstallButton.width - LcarsUi.u(40)
            height: parent.height
            text: root.selectedRemovalApp ? root.selectedRemovalApp.name : "SELECT AN APP TO REMOVE"
            color: LcarsUi.ice; size: 22; elide: Text.ElideRight
        }
        LcarsFileAction {
            id: uninstallButton
            anchors.right: parent.right; anchors.rightMargin: LcarsUi.u(8)
            anchors.verticalCenter: parent.verticalCenter
            width: LcarsUi.u(146); height: LcarsUi.u(48)
            enabled: !!root.selectedRemovalApp && !root.installing
            text: "UNINSTALL"
            onClicked: root.request({op: "prepare_uninstall", id: root.selectedRemovalApp.id})
        }
    }
    Rectangle {
        id: terminalPanel
        visible: root.tab === "install" || root.tab === "uninstall"
        readonly property real frameWidth: LcarsUi.u(10)
        x: (root.tab === "uninstall" ? uninstallList.x + uninstallList.width
            : installList.x + installList.width) + LcarsUi.u(12)
        y: LcarsUi.u(230)
        width: Math.max(0, parent.width - x - LcarsUi.u(25))
        height: Math.max(0, parent.height - y - LcarsUi.u(52))
        color: LcarsUi.black
        LcarsRect {
            x: 0; y: consoleHeader.height - 1
            width: terminalPanel.frameWidth
            height: Math.max(0, terminalPanel.height - y)
            color: LcarsUi.lilac; radiusBL: width / 2
        }
        LcarsRect {
            x: terminalPanel.width - width; y: consoleHeader.height - 1
            width: terminalPanel.frameWidth
            height: Math.max(0, terminalPanel.height - y)
            color: LcarsUi.salmon; radiusBR: width / 2
        }
        LcarsRect {
            x: 0; y: terminalPanel.height - height
            width: Math.max(0, (terminalPanel.width - LcarsUi.u(8)) / 2)
            height: terminalPanel.frameWidth
            color: LcarsUi.lilac; radiusBL: height / 2
        }
        LcarsRect {
            x: (terminalPanel.width + LcarsUi.u(8)) / 2
            y: terminalPanel.height - height
            width: Math.max(0, (terminalPanel.width - LcarsUi.u(8)) / 2)
            height: terminalPanel.frameWidth
            color: LcarsUi.salmon; radiusBR: height / 2
        }
        Item {
            id: consoleHeader
            width: parent.width; height: LcarsUi.u(48)
            LcarsRect {
                id: consoleLeftCap
                width: Math.min(LcarsUi.u(70), consoleHeader.width / 6)
                height: parent.height
                color: LcarsUi.lilac; radiusTL: height / 2
            }
            Rectangle {
                x: consoleLeftCap.width
                width: Math.max(0, statusSegment.x - x)
                height: parent.height
                color: LcarsUi.black
            }
            LcarsLabel {
                x: consoleLeftCap.width + LcarsUi.u(10)
                width: Math.max(0, statusSegment.x - x - LcarsUi.u(8))
                height: parent.height
                text: (root.operation === "uninstall" ? "REMOVE CONSOLE // " : "INSTALL CONSOLE // ")
                    + root.terminalTitle
                color: LcarsUi.gold; size: 25; elide: Text.ElideRight
            }
            Rectangle {
                id: statusSegment
                x: Math.max(consoleLeftCap.width + LcarsUi.u(195), consoleHeader.width * 0.47)
                width: Math.max(0, stopCap.x - x - LcarsUi.u(5))
                height: parent.height
                color: LcarsUi.gold
                LcarsLabel {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.installing
                        ? (root.operation === "uninstall" ? "REMOVING" : "INSTALLING")
                        : "STANDBY"
                    color: LcarsUi.black; size: 23
                }
            }
            LcarsRect {
                id: stopCap
                x: parent.width - width
                width: Math.min(LcarsUi.u(92), consoleHeader.width / 5)
                height: parent.height
                color: LcarsUi.salmon; radiusTR: height / 2
                opacity: root.installing ? 1 : 0.65
                LcarsLabel {
                    anchors.centerIn: parent
                    text: "STOP"; color: LcarsUi.black; size: 23
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.installing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.request({op: "install_cancel"})
                    Accessible.role: Accessible.Button
                    Accessible.name: "Stop installation"
                }
            }
        }
        Item {
            id: progressReadout
            x: LcarsUi.u(22)
            y: consoleHeader.height + LcarsUi.u(9)
            width: parent.width - LcarsUi.u(44)
            height: LcarsUi.u(28)
            LcarsLabel {
                id: progressCaption
                width: LcarsUi.u(100); height: parent.height
                text: root.terminalProgress < 0
                    ? (root.installing ? "WORKING" : "PROGRESS")
                    : root.terminalProgress + "%"
                color: LcarsUi.mauve; size: 19
            }
            Row {
                x: progressCaption.width + LcarsUi.u(5)
                width: Math.max(0, parent.width - x)
                height: LcarsUi.u(19)
                anchors.verticalCenter: parent.verticalCenter
                spacing: LcarsUi.u(3)
                Repeater {
                    model: 16
                    delegate: Rectangle {
                        required property int index
                        width: Math.max(1, (progressReadout.width - progressCaption.width
                            - LcarsUi.u(5) - LcarsUi.u(45)) / 16)
                        height: LcarsUi.u(19)
                        color: root.terminalProgress < 0
                            ? (root.installing && (index - root.terminalPulse + 16) % 16 < 4
                                ? LcarsUi.gold : LcarsUi.grey)
                            : (index < Math.ceil(root.terminalProgress * 16 / 100)
                                ? LcarsUi.gold : LcarsUi.grey)
                    }
                }
            }
        }
        Flickable {
            id: terminalScroll
            x: LcarsUi.u(22); y: progressReadout.y + progressReadout.height + LcarsUi.u(8)
            width: parent.width - LcarsUi.u(44)
            height: Math.max(0, parent.height - y - LcarsUi.u(68))
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, terminalText.paintedHeight + LcarsUi.u(12))
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: LcarsUi.u(7)
                    radius: width / 2
                    color: LcarsUi.violet
                }
            }
            Text {
                id: terminalText
                width: terminalScroll.width - LcarsUi.u(12)
                text: root.terminalOutput
                    ? root.terminalOutput.replace(/[\u2580-\u259f]{2,}/g, "")
                    : "Select an app and press INSTALL.\nPackage prompts and progress will appear here."
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: root.terminalOutput ? LcarsUi.honey : LcarsUi.mauve
                font.family: LcarsUi.font
                font.pixelSize: Math.max(13, LcarsUi.u(21))
                font.weight: Font.Medium
                font.letterSpacing: LcarsUi.u(0.3)
                lineHeight: 1.15
                lineHeightMode: Text.ProportionalHeight
            }
        }
        TextField {
            id: terminalInput
            x: LcarsUi.u(22); y: parent.height - LcarsUi.u(58)
            width: parent.width - LcarsUi.u(164); height: LcarsUi.u(42)
            enabled: root.installing
            placeholderText: root.passwordPrompt ? "PASSWORD" : "TYPE A RESPONSE AND PRESS ENTER"
            echoMode: root.passwordPrompt ? TextInput.Password : TextInput.Normal
            color: LcarsUi.amber; placeholderTextColor: LcarsUi.mauve
            font.family: LcarsUi.font; font.pixelSize: LcarsUi.u(24)
            font.weight: Font.DemiBold
            leftPadding: LcarsUi.u(10)
            onAccepted: root.submitTerminalInput()
            onActiveFocusChanged: {
                if (activeFocus) root.inputFocused(terminalInput, "INSTALL INPUT")
                else root.inputBlurred(terminalInput)
            }
            background: Rectangle {
                color: "#171119"; radius: LcarsUi.u(7)
                border.color: terminalInput.activeFocus ? LcarsUi.peach : LcarsUi.mauve
            }
        }
        LcarsFileAction {
            anchors.right: parent.right; anchors.rightMargin: LcarsUi.u(22)
            y: terminalInput.y; width: LcarsUi.u(108); height: LcarsUi.u(42)
            text: "SEND"; enabled: root.installing
            onClicked: root.submitTerminalInput()
        }
    }
    LcarsLabel {
        x: LcarsUi.u(25); y: parent.height - LcarsUi.u(47)
        width: parent.width - LcarsUi.u(50); height: LcarsUi.u(35)
        text: root.error || root.activity
        color: root.error ? LcarsUi.salmon : LcarsUi.mauve
        size: 19; caps: false; elide: Text.ElideRight
    }
    Rectangle {
        id: uninstallOverlay
        anchors.fill: parent
        z: 100
        visible: !!root.pendingRemoval
        color: Qt.rgba(0, 0, 0, 0.78)
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - LcarsUi.u(40), LcarsUi.u(680))
            height: LcarsUi.u(285)
            color: LcarsUi.black
            border.color: LcarsUi.salmon; border.width: LcarsUi.u(3)
            radius: LcarsUi.u(20)
            LcarsLabel {
                x: LcarsUi.u(24); y: LcarsUi.u(14)
                width: parent.width - LcarsUi.u(48); height: LcarsUi.u(42)
                text: "CONFIRM UNINSTALL"
                color: LcarsUi.salmon; size: 33
            }
            LcarsLabel {
                x: LcarsUi.u(24); y: LcarsUi.u(69)
                width: parent.width - LcarsUi.u(48); height: LcarsUi.u(35)
                text: root.pendingRemoval ? root.pendingRemoval.name : ""
                color: LcarsUi.honey; size: 28; elide: Text.ElideRight
            }
            LcarsLabel {
                x: LcarsUi.u(24); y: LcarsUi.u(107)
                width: parent.width - LcarsUi.u(48); height: LcarsUi.u(30)
                text: root.pendingRemoval
                    ? root.pendingRemoval.source + " // " + root.pendingRemoval.package : ""
                color: LcarsUi.ice; size: 21; caps: false; elide: Text.ElideRight
            }
            LcarsLabel {
                x: LcarsUi.u(24); y: LcarsUi.u(151)
                width: parent.width - LcarsUi.u(48); height: LcarsUi.u(34)
                text: "PACKAGE CHANGES WILL APPEAR IN THE CONSOLE"
                color: LcarsUi.mauve; size: 20; elide: Text.ElideRight
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: LcarsUi.u(24)
                y: parent.height - LcarsUi.u(69)
                spacing: LcarsUi.u(12)
                LcarsFileAction {
                    width: LcarsUi.u(130); height: LcarsUi.u(48)
                    text: "CANCEL"
                    onClicked: {
                        root.pendingRemoval = null
                        root.request({op: "cancel_uninstall"})
                    }
                }
                LcarsFileAction {
                    width: LcarsUi.u(160); height: LcarsUi.u(48)
                    text: "UNINSTALL"
                    onClicked: {
                        const token = root.pendingRemoval.token
                        root.pendingRemoval = null
                        root.request({op: "confirm_uninstall", token: token})
                    }
                }
            }
        }
    }
}
