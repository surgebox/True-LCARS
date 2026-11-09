import QtQuick
import QtQuick.Controls.Basic
import QtMultimedia
import "../theme"

Rectangle {
    id: root
    property var file: ({})
    property bool loading: false
    property bool browserVisible: true
    signal pageRequested(int page)
    signal openRequested()
    readonly property bool media: file.kind === "audio" || file.kind === "video"
    color: "#0d0b12"
    radius: LcarsUi.u(18)
    border.color: "#4a394b"
    onFileChanged: player.stop()
    onBrowserVisibleChanged: { if (!browserVisible) player.stop() }

    function bytes(value) {
        if (value === undefined) return ""
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let n = value
        let u = 0
        while (n >= 1024 && u < units.length - 1) { n /= 1024; u++ }
        return n.toFixed(u ? 1 : 0) + " " + units[u]
    }
    function time(ms) { return Math.floor(ms / 60000) + ":" + Math.floor(ms / 1000 % 60).toString().padStart(2, "0") }

    Rectangle {
        id: heading
        x: LcarsUi.u(3)
        y: LcarsUi.u(3)
        width: parent.width - LcarsUi.u(6)
        height: LcarsUi.u(58)
        radius: height / 2
        color: LcarsUi.violet
        LcarsLabel {
            x: LcarsUi.u(22); width: parent.width - LcarsUi.u(44)
            height: parent.height
            text: "ANALYSIS / PREVIEW"; size: 27; color: LcarsUi.black
        }
    }
    Column {
        id: details
        visible: !!root.file.name || root.loading
        anchors {
            top: heading.bottom; topMargin: LcarsUi.u(18)
            left: parent.left; leftMargin: LcarsUi.u(20)
            right: parent.right; rightMargin: LcarsUi.u(20)
        }
        spacing: LcarsUi.u(10)
        Text {
            width: parent.width
            text: root.file.name || "SELECT A FILE"
            color: LcarsUi.amber
            font.pixelSize: LcarsUi.u(30)
            font.family: LcarsUi.font
            elide: Text.ElideMiddle
        }
        Text {
            width: parent.width
            text: root.file.mime ? "TYPE  " + root.file.mime + "    /    SIZE  " + root.bytes(root.file.size)
                + "\nMODIFIED  " + root.file.modified + "    /    ACCESS  " + root.file.permissions
                : "SELECT A FILE OR FOLDER IN THE COLUMNS"
            color: LcarsUi.mauve
            font.family: LcarsUi.font
            font.pixelSize: LcarsUi.u(22)
            wrapMode: Text.WrapAnywhere
        }
    }
    Item {
        id: content
        anchors {
            top: details.visible ? details.bottom : heading.bottom
            topMargin: LcarsUi.u(18)
            bottom: controls.top; bottomMargin: LcarsUi.u(16)
            left: parent.left; leftMargin: LcarsUi.u(20)
            right: parent.right; rightMargin: LcarsUi.u(20)
        }
        clip: true
        Rectangle {
            anchors.fill: parent
            visible: !root.loading && !root.file.kind
            color: "#14111a"; radius: LcarsUi.u(12)
            border.color: "#3b3043"
            LcarsLabel {
                anchors.centerIn: parent
                width: parent.width - LcarsUi.u(50)
                text: "TAP A FILE TO PREVIEW"
                color: LcarsUi.mauve; size: 25; fit: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Image {
            id: picture
            anchors.fill: parent
            visible: player.playbackState === MediaPlayer.StoppedState && (root.file.kind === "image" || !!root.file.image)
            source: root.file.image || (root.file.kind === "image" ? root.file.url : "")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: 1600
            sourceSize.height: 1200
            cache: false
        }
        VideoOutput { id: video; anchors.fill: parent; visible: root.file.kind === "video" && player.playbackState !== MediaPlayer.StoppedState }
        Flickable {
            id: textScroll
            anchors.fill: parent
            visible: root.file.kind === "text" || root.file.kind === "markdown"
            contentWidth: width
            contentHeight: document.height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            onVisibleChanged: contentY = 0
            TextEdit {
                id: document
                width: textScroll.width - LcarsUi.u(10)
                text: root.file.text || ""
                textFormat: root.file.kind === "markdown" ? TextEdit.MarkdownText : TextEdit.PlainText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: LcarsUi.ice
                selectedTextColor: LcarsUi.black
                selectionColor: LcarsUi.violet
                font.family: root.file.kind === "markdown" ? "sans-serif" : LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(19)
                onTextChanged: textScroll.contentY = 0
                // Markdown links are opened only by an explicit click.
                onLinkActivated: link => { if (/^(https?:|mailto:)/i.test(link)) Qt.openUrlExternally(link) }
            }
        }
        Text {
            anchors.centerIn: parent
            width: parent.width
            text: root.loading ? "READING FILE…" : (root.file.error ||
                  (picture.status === Image.Error && root.file.kind === "image" ? "Image format unavailable in this Qt installation." :
                  (root.file.message || (root.file.kind === "audio" ? "AUDIO RECORD\nPress Play to listen." : ""))))
            visible: root.loading || !!root.file.error || !!root.file.message || root.file.kind === "audio" || picture.status === Image.Error
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: root.file.error ? LcarsUi.salmon : LcarsUi.amber
            font.family: LcarsUi.font
            font.pixelSize: LcarsUi.u(21)
        }
    }
    Column {
        id: controls
        anchors {
            bottom: parent.bottom; bottomMargin: LcarsUi.u(16)
            left: parent.left; leftMargin: LcarsUi.u(20)
            right: parent.right; rightMargin: LcarsUi.u(20)
        }
        spacing: LcarsUi.u(12)
        Text {
            width: parent.width
            text: root.file.truncated ? "Showing the first 64 KiB." : (root.file.dimensions || "")
            visible: text !== ""
            color: LcarsUi.mauve
            font.family: LcarsUi.font
            font.pixelSize: LcarsUi.u(17)
        }
        Text {
            width: parent.width
            visible: player.error !== MediaPlayer.NoError
            text: player.errorString
            wrapMode: Text.Wrap
            color: LcarsUi.salmon
            font.family: LcarsUi.font
            font.pixelSize: LcarsUi.u(17)
        }
        Slider {
            width: parent.width
            height: LcarsUi.u(54)
            visible: root.media
            from: 0
            to: Math.max(1, player.duration)
            value: player.position
            enabled: player.seekable
            onMoved: player.setPosition(value)
            background: Rectangle {
                x: parent.leftPadding
                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                width: parent.availableWidth; height: LcarsUi.u(12)
                radius: height / 2; color: "#393044"
                Rectangle {
                    width: parent.width * (player.duration > 0 ? player.position / player.duration : 0)
                    height: parent.height; radius: parent.radius; color: LcarsUi.violet
                }
            }
            handle: Rectangle {
                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                width: LcarsUi.u(30); height: LcarsUi.u(30)
                radius: width / 2; color: LcarsUi.peach
            }
        }
        Row {
            spacing: LcarsUi.u(8)
            visible: root.media
            LcarsFileAction {
                text: player.playing ? "PAUSE" : "PLAY"
                onClicked: { if (player.playing) player.pause(); else player.play() }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.time(player.position) + " / " + root.time(player.duration || (root.file.duration || 0) * 1000); color: LcarsUi.amber; font.family: LcarsUi.font; font.pixelSize: LcarsUi.u(18) }
        }
        Row {
            spacing: LcarsUi.u(8)
            visible: root.file.kind === "pdf" && !!root.file.image
            LcarsFileAction { text: "‹"; enabled: root.file.page > 1 && !root.loading; onClicked: root.pageRequested(root.file.page - 1) }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "PAGE " + root.file.page + " / " + root.file.pages; color: LcarsUi.amber; font.family: LcarsUi.font; font.pixelSize: LcarsUi.u(19) }
            LcarsFileAction { text: "›"; enabled: root.file.page < root.file.pages && !root.loading; onClicked: root.pageRequested(root.file.page + 1) }
        }
        LcarsFileAction { text: "OPEN IN DEFAULT APP ↗"; visible: !!root.file.url && root.file.kind !== "directory"; onClicked: root.openRequested() }
    }
    MediaPlayer {
        id: player
        source: root.media ? (root.file.url || "") : ""
        audioOutput: AudioOutput { volume: 0.7 }
        videoOutput: video
    }
}
