import QtQuick
import QtQuick.Window
import Quickshell.Io

import "theme"
import "ui"

// ===========================================================================
// LCARS desktop shell - layout study 03
//
// One plain Window (like objects.qml) so we can iterate on geometry fast.
//
// Sizing model: the layout is authored in *design units* for a 2048x1152
// canvas. `LcarsUi.scale` is height/1152, so every block keeps its intended
// vertical size on any resolution; horizontally the blocks are anchored to the
// window edges instead of being pinned to design-x, so a wider or narrower
// screen stretches the bars rather than clipping them.
//
// Regions:
//
//   CHROME  header      date cap, readout, ACCESS title, CPU/MEM/NET/DSK
//   CHROME  top band    strip band off the COMMAND elbow
//   CHROME  rail        the left column, filled elbow-to-band with bars
//   CHROME  bottom band strip band off the bottom-left elbow
//   APP                 the black field between the two bands
//
// The panel - top band down to bottom band - is the point of the composition,
// so the header above it is kept deliberately short (headH). Everything below
// bandTop is generous by comparison.
// ===========================================================================
Window {
    id: win

    readonly property real dh: 1152 // design canvas height

    width: 2048
    height: 1152
    visible: true
    color: LcarsUi.black
    title: "LCARS // layout study"

    Binding {
        target: LcarsUi
        property: "scale"
        value: win.height / win.dh
    }

    // ---- metrics (design units) -------------------------------------------
    readonly property real m: 10           // margin from the screen edge
    readonly property real g: 10           // gap between regions
    readonly property real railW: 210      // left rail / elbow column width
    readonly property real r: 46           // big outer corner
    readonly property real r2: 28

    // ---- the HELLO bar, across the very top of the screen ------------------
    readonly property real helloH: 56      // bar zone; caps + long run + title
    readonly property real helloY: m

    // ---- header ------------------------------------------------------------
    readonly property real headTop: helloY + helloH + g   // 76 - pushed down by the bar

    // The date cap and the DATE elbow are one continuous column: the elbow
    // starts exactly where the cap ends, so there is no separate box between
    // them and the cap's rounded top-left is the head of the whole shape.
    readonly property real dateCapH: 72
    // 2 units of overlap, not a butt joint: two same-coloured shapes meeting
    // exactly leave a hairline where their antialiased edges land on different
    // pixels. The cap is drawn last, so it hides the overlap.
    readonly property real dateElbowTop: m + dateCapH - 2
    readonly property real dateElbowH: 128                  // box height
    readonly property real dateArmThick: 24                 // its thin horizontal bar

    // ---- the volume column, in the gutter between the DATE column and the
    //      numeric readout. The readout is pushed right to make room.
    //      These are ABSOLUTE design y values; the header's children are offset
    //      by headTop, so the placements below subtract it back out.
    readonly property real volX: 262        // clear of the DATE column (ends at 210)
    readonly property real volW: 42
    readonly property real volY: 90
    readonly property real volH: 120
    readonly property real volBtnY: volY + volH + 6     // 216
    readonly property real volBtnH: 30
    readonly property real readoutX: volX + volW + 10   // 266

    // ---- the CPU / MEM / NET / DSK grid ------------------------------------
    readonly property real clusterW: 440         // header right-hand cluster
    readonly property real capsuleW: (clusterW - g) / 2   // both columns equal
    readonly property real capsuleH: 38          // was 30 - they were too thin
    readonly property real capsuleRow1: 72       // below the ACCESS title
    readonly property real capsuleRow2: 72 + capsuleH + g

    readonly property real headH: dateElbowTop + dateElbowH + g   // 220, the header's box

    // The black strip between the DATE elbow's arm and the COMMAND arm. This is
    // the one number that sets how far apart the two horizontal bars sit: the
    // top band is anchored off the DATE arm, not off the header's box, so
    // closing this up lifts the COMMAND elbow and its arm together.
    readonly property real dateArmGap: 12

    // ---- the top band ------------------------------------------------------
    readonly property real bandTop: headTop + dateElbowTop + dateElbowH + dateArmGap   // 298
    readonly property real elbowArm: 48    // the COMMAND elbow's own bar
    readonly property real bandThick: 38   // the band is thinner than that arm
    readonly property real elbowH: 100     // elbow box height

    // ---- the bottom band ---------------------------------------------------
    readonly property real bandBottomEdge: dh - m
    readonly property real bottomThick: 16  // half the old 32 - a thin closing bar
    readonly property real bottomElbowH: 110
    readonly property real bottomBandTop: bandBottomEdge - bottomElbowH

    // ---- region anchors ------------------------------------------------------
    readonly property real railTop: bandTop + elbowH + g
    readonly property real railSpan: bottomBandTop - g - railTop

    readonly property real appX: railW + g
    readonly property real appY: bandTop + bandThick + g
    // the bottom elbow's column only occupies x 0..railW, so the app field is
    // free to run past the elbow's box and down to its bar
    readonly property real appBottom: bandBottomEdge - bottomThick - g
    readonly property real appH: appBottom - appY

    // design-space width of the window, and the right-hand edge of every bar
    readonly property real dw: width / LcarsUi.scale
    readonly property real edge: dw - m

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    // ---- Star Trek style stardate ------------------------------------------
    // 1000 stardates per year, anchored so 1970-01-01 is 0. That puts the
    // present day in the familiar five-digit TNG band. It is decorative - there
    // is no canon mapping from the 21st century onto TNG stardates - but it is
    // deterministic and advances at the rate the shows used.
    property date now: new Date()

    readonly property string stardate:
        (win.now.getTime() / 86400000 / 365.25 * 1000).toFixed(1)

    function two(n) {
        return (n < 10 ? "0" : "") + n
    }

    // The Earth date, for the readout under the stardate.
    readonly property string earthDate:
        win.now.getFullYear() + "." + two(win.now.getMonth() + 1) + "." + two(win.now.getDate())

    Timer {
        interval: 10000        // the tenths digit moves about every 9 hours
        running: true
        repeat: true
        onTriggered: win.now = new Date()
    }

    // =======================================================================
    // "HELLO <NAME>" - across the very top of the screen.
    //
    // Ported from Project-Eve. The OS username is often "firstlast"
    // ("henrysalvador"), so prefer friendlier sources: git user.name, then the
    // passwd GECOS field, and only then the raw username.
    // =======================================================================
    property string userName: "there"

    Process {
        id: nameQuery
        command: ["bash", "-lc",
            "n=$(git config --get user.name 2>/dev/null); " +
            "[ -z \"$n\" ] && n=$(getent passwd \"$(whoami)\" | cut -d: -f5 | sed 's/,.*//'); " +
            "f=${n%% *}; [ -n \"$f\" ] || f=$(whoami); printf '%s' \"$f\""]
        running: true
        stdout: StdioCollector {
            id: nameOut
            waitForEnd: true
            onStreamFinished: {
                const t = "" + nameOut.text
                if (t.trim().length > 0)
                    win.userName = t.trim()
            }
        }
    }

    // =======================================================================
    // Live stats for the CPU / MEM / NET / DSK capsules.
    //
    // scripts/stats.sh is a one-line-per-second poller, so this is one
    // long-lived child process rather than a fork every second - we just read
    // its stdout. The parse is total: a malformed line leaves the last good
    // values on screen rather than blanking the capsules.
    // =======================================================================
    property int volumePct: 40
    property bool muted: false
    property bool dragging: false      // the bar owns the level mid-drag
    property real dragLevel: 0
    // The bar shows the drag value while you are dragging it and the poller's
    // value the rest of the time, so it tracks your finger without fighting the
    // 1 Hz refresh.
    readonly property real shownLevel: dragging ? dragLevel : volumePct / 100

    readonly property string audioCmd:
        Qt.resolvedUrl("scripts/audio.sh").toString().replace(/^file:\/\//, "")

    function audio(args) {
        audioProc.command = ["bash", win.audioCmd].concat(args)
        audioProc.running = true
    }

    Process {
        id: audioProc
        command: []
        running: false
    }

    property int cpuPct: 0
    property real memUsedKb: 0
    property real memTotalKb: 0
    property string netIface: ""
    property int netKbps: 0
    property real dskUsedKb: 0
    property real dskTotalKb: 0

    readonly property string statsCmd:
        Qt.resolvedUrl("scripts/stats.sh").toString().replace(/^file:\/\//, "")

    function applyStats(line) {
        const f = line.trim().split(/\s+/)
        if (f.length < 7)
            return
        win.cpuPct = parseInt(f[0]) || 0
        win.memUsedKb = parseFloat(f[1]) || 0
        win.memTotalKb = parseFloat(f[2]) || 0
        win.netIface = f[3] === "-" ? "" : f[3]
        win.netKbps = parseInt(f[4]) || 0
        win.dskUsedKb = parseFloat(f[5]) || 0
        win.dskTotalKb = parseFloat(f[6]) || 0
        if (f.length >= 9) {
            win.volumePct = parseInt(f[7]) || 0
            win.muted = (parseInt(f[8]) || 0) === 1
        }
    }

    // KiB -> whole GB. The capsules are narrow, so no decimals.
    function gb(kib) {
        return Math.round(kib / 1048576) + "GB"
    }
    function pair(usedKb, totalKb) {
        if (totalKb <= 0)
            return "--"
        return gb(usedKb) + "/" + gb(totalKb)
    }

    readonly property string memText: pair(memUsedKb, memTotalKb)
    readonly property string dskText: pair(dskUsedKb, dskTotalKb)
    readonly property int memPct: memTotalKb > 0 ? Math.round(100 * memUsedKb / memTotalKb) : 0
    readonly property int dskPct: dskTotalKb > 0 ? Math.round(100 * dskUsedKb / dskTotalKb) : 0

    // The capsules are buttons: each one flips between its two readings.
    property bool memShowPercent: false
    property bool dskShowPercent: false

    // KB/s reads badly once it climbs, so switch units at a megabyte
    readonly property string netText: {
        if (win.netIface.length === 0)
            return "NO LINK"
        const rate = win.netKbps >= 1024
            ? (win.netKbps / 1024).toFixed(1) + "M/s"
            : win.netKbps + "K/s"
        return win.netIface.toUpperCase() + " " + rate
    }

    Process {
        id: statsProc
        command: ["bash", win.statsCmd]
        running: true
        stdout: SplitParser {
            onRead: (line) => win.applyStats(line)
        }
    }

    // Quickshell carries a Process across config reloads on purpose, so it will
    // not restart one that has died - the capsules would just freeze on their
    // last reading. A slow heartbeat brings it back. (Hooking onExited instead
    // trips qmllint, which cannot resolve QProcess::ExitStatus without a QtCore
    // import, and a 2s timer costs nothing.)
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!statsProc.running)
                statsProc.running = true
        }
    }

    Item {
        id: helloBar
        x: 0                                  // edge to edge, caps on the screen edges
        y: LcarsUi.u(win.helloY)
        width: win.width
        height: LcarsUi.u(win.helloH)

        LcarsTextBar {
            anchors.fill: parent
            text: "Hello " + win.userName
            accent: LcarsUi.yellow
            ink: LcarsUi.honey
        }
    }

    // =======================================================================
    // RAIL CONTENT
    //
    // `w` is a *relative* height. The blocks are normalised against the space
    // actually available between the elbow and the bottom band, so the column
    // is always filled bar-to-bar and tuning a block means changing its number
    // here, never a cascade of y offsets.
    // =======================================================================
    readonly property real railGap: 8

    readonly property var railBlocks: [
        { w: 1.0, color: LcarsUi.rust,   text: "SYSTEM",      size: 40, align: "left",  pad: 20 },
        { w: 1.0, color: LcarsUi.violet, text: "04-785486",   size: 34, align: "right", pad: 22 },
        { w: 1.0, color: LcarsUi.gold,   text: "NETWORK",     size: 38, align: "left",  pad: 20 },
        { w: 1.0, color: LcarsUi.peach,  text: "30204",       size: 34, align: "right", pad: 22 },
        { w: 1.0, color: LcarsUi.mauve,  text: "67187585",    size: 34, align: "right", pad: 22 },
        { w: 1.0, color: LcarsUi.violet, text: "LCARS 40274", size: 34, align: "left",  pad: 20 }
    ]

    readonly property var railLayout: {
        const blocks = win.railBlocks
        const n = blocks.length
        const span = win.railSpan - win.railGap * (n - 1)
        let sum = 0
        for (let i = 0; i < n; i++)
            sum += blocks[i].w
        const out = []
        let y = 0
        for (let i = 0; i < n; i++) {
            const h = span * blocks[i].w / sum
            out.push({
                y: y, h: h, color: blocks[i].color, text: blocks[i].text,
                size: blocks[i].size, align: blocks[i].align, pad: blocks[i].pad
            })
            y += h + win.railGap
        }
        return out
    }

    // =======================================================================
    // APP AREA - every app window lands here, bounded by the two bands.
    // =======================================================================
    Item {
        id: appArea
        x: LcarsUi.u(win.appX)
        y: LcarsUi.u(win.appY)
        width: win.width - x - LcarsUi.u(win.m)
        height: LcarsUi.u(win.appH)

        // Dim outline + corner brackets, only so the reserved field is obvious
        // while there is no real content in it. Delete this block once apps
        // actually render here.
        LcarsRect {
            anchors.fill: parent
            color: "#050505"
            borderColor: Qt.rgba(1, 0.61, 0, 0.22)
            borderWidth: 1
        }

        Repeater {
            model: 4

            delegate: Item {
                id: bracket
                readonly property real arm: LcarsUi.u(64)
                readonly property real thick: LcarsUi.u(4)
                readonly property bool lhs: index === 0 || index === 2
                readonly property bool topSide: index < 2

                x: lhs ? 0 : appArea.width - arm
                y: topSide ? 0 : appArea.height - arm
                width: arm
                height: arm

                LcarsRect {
                    width: bracket.arm
                    height: bracket.thick
                    y: bracket.topSide ? 0 : bracket.arm - height
                    color: Qt.rgba(1, 0.61, 0, 0.35)
                }
                LcarsRect {
                    width: bracket.thick
                    height: bracket.arm
                    x: bracket.lhs ? 0 : bracket.arm - width
                    color: Qt.rgba(1, 0.61, 0, 0.35)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: LcarsUi.u(8)

            LcarsLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "APPLICATION AREA"
                color: Qt.rgba(1, 0.61, 0, 0.26)
                size: 34
                tracking: true
            }
            LcarsLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "shell chrome stays on top \u00b7 windows open here"
                color: Qt.rgba(1, 0.61, 0, 0.15)
                size: 18
                caps: false
            }
        }
    }

    // =======================================================================
    // HEADER - deliberately short; the panel below it is the subject.
    // =======================================================================
    Item {
        id: header
        x: 0
        y: LcarsUi.u(win.headTop)
        width: win.width
        height: LcarsUi.u(win.headH)

        // ---- right cluster, anchored to the screen edge ----------------------
        Item {
            id: headerRight
            anchors.right: parent.right
            anchors.rightMargin: LcarsUi.u(win.m)
            anchors.top: parent.top
            anchors.topMargin: LcarsUi.u(win.m)
            width: LcarsUi.u(win.clusterW)
            height: LcarsUi.u(win.capsuleRow2 + win.capsuleH)

            LcarsLabel {
                anchors.left: parent.left
                anchors.right: parent.right
                height: LcarsUi.u(62)
                text: "LCARS ACCESS 441"
                color: LcarsUi.orange
                size: 46
                horizontalAlignment: Text.AlignRight
                fit: true
            }

            LcarsCapsule {
                id: capCpu
                x: 0
                y: LcarsUi.u(win.capsuleRow1)
                width: LcarsUi.u(win.capsuleW)
                height: LcarsUi.u(win.capsuleH)
                label: "CPU"
                value: win.cpuPct + "%"
                color: LcarsUi.violet
                labelColor: LcarsUi.shade
                valueColor: LcarsUi.shade
                labelSize: 17
                valueSize: 17
                padLeft: 14
                padRight: 14
            }
            LcarsCapsule {
                anchors.right: parent.right
                y: LcarsUi.u(win.capsuleRow1)
                width: LcarsUi.u(win.capsuleW)
                height: LcarsUi.u(win.capsuleH)
                label: "MEM"
                value: win.memShowPercent ? win.memPct + "%" : win.memText
                color: LcarsUi.pink
                labelColor: LcarsUi.shade
                valueColor: LcarsUi.shade
                labelSize: 17
                valueSize: 17
                padLeft: 14
                padRight: 14
                onClicked: win.memShowPercent = !win.memShowPercent
            }
            LcarsCapsule {
                x: 0
                y: LcarsUi.u(win.capsuleRow2)
                width: LcarsUi.u(win.capsuleW)
                height: LcarsUi.u(win.capsuleH)
                label: "NET"
                value: win.netText
                color: LcarsUi.peach
                labelColor: LcarsUi.shade
                valueColor: LcarsUi.shade
                labelSize: 17
                valueSize: 17
                padLeft: 14
                padRight: 14
            }
            LcarsCapsule {
                anchors.right: parent.right
                y: LcarsUi.u(win.capsuleRow2)
                width: LcarsUi.u(win.capsuleW)
                height: LcarsUi.u(win.capsuleH)
                label: "DSK"
                value: win.dskShowPercent ? win.dskPct + "%" : win.dskText
                color: LcarsUi.violet
                labelColor: LcarsUi.shade
                valueColor: LcarsUi.shade
                labelSize: 17
                valueSize: 17
                padLeft: 14
                padRight: 14
                onClicked: win.dskShowPercent = !win.dskShowPercent
            }
        }

        // ---- volume column -----------------------------------------------------
        // Sits in the gutter between the DATE column and the numbers, and stays
        // put: it is chrome, so it is on top of whatever the app field renders.
        LcarsVolumeBar {
            id: volumeBar
            x: LcarsUi.u(win.volX)
            y: LcarsUi.u(win.volY - win.headTop)
            width: LcarsUi.u(win.volW)
            height: LcarsUi.u(win.volH)
            level: win.shownLevel
            muted: win.muted
            bars: 16
            gap: 2
            radius: 0            // square boxes, old-school

            onMoved: (l) => {
                win.dragging = true
                win.dragLevel = l
            }
            onCommitted: (l) => {
                win.dragging = false
                win.audio(["set", Math.round(l * 100)])
            }
        }

        LcarsIconButton {
            x: LcarsUi.u(win.volX)
            y: LcarsUi.u(win.volBtnY - win.headTop)
            width: LcarsUi.u(win.volW)
            height: LcarsUi.u(win.volBtnH)
            glyph: "\uf028"                    // speaker with sound waves
            glyphSize: 24
            // idle, the glyph takes the meter's own current colour, so it
            // reads as the head of the gauge: green low, red at max
            iconColor: volumeBar.levelColor
            active: win.muted                  // muted: red block + cut glyph
            onClicked: win.audio(["toggle-mute"])
            // The press-and-hold output picker is parked, not deleted:
            // ui/LcarsDeviceMenu.qml and `audio.sh sinks|default` are still
            // here, and LcarsIconButton still emits held(). Re-hooking it is
            // the popup plus the plumbing that used to sit behind it.
        }

        // ---- numeric cascade --------------------------------------------------
        LcarsReadout {
            x: LcarsUi.u(win.readoutX)
            y: LcarsUi.u(14)
            width: Math.max(0, headerRight.x - x - LcarsUi.u(20))
            height: LcarsUi.u(128)
            size: 20
            rows: 4
            rowSpacing: 6
            colWidths: [130, 140, 88, 110, 110, 110, 110, 110, 110, 110]
            colDigits: [4, 7, 2, 4, 4, 4, 4, 4, 4, 4]
        }

        // ---- DATE elbow --------------------------------------------------------
        // The date column runs straight on out of the cap and turns into an
        // upside-down elbow: arm to the right, outer corner rounded at the
        // bottom-left, concave shoulder above it. The arm spans the full width
        // and sits `dateArmGap` above the top band, so the two read as two
        // separate bars with a plain black gap between them.
        LcarsElbow {
            id: dateElbow
            x: LcarsUi.u(win.m)
            y: LcarsUi.u(win.dateElbowTop)
            width: LcarsUi.u(win.edge - win.m)
            height: LcarsUi.u(win.dateElbowH)
            corner: "bottomLeft"
            color: LcarsUi.lilac
            barThickness: LcarsUi.u(win.dateArmThick)
            columnThickness: LcarsUi.u(win.railW - win.m)
            outerRadius: LcarsUi.u(win.dateArmThick)
            innerRadius: LcarsUi.u(24)
        }

        // ---- date cap ---------------------------------------------------------
        LcarsRect {
            x: LcarsUi.u(win.m)
            y: LcarsUi.u(win.m)
            width: LcarsUi.u(win.railW - win.m)
            height: LcarsUi.u(win.dateCapH)
            color: LcarsUi.lilac
            radiusTL: LcarsUi.u(30)
        }

        Column {
            x: LcarsUi.u(win.m + 12)
            y: LcarsUi.u(win.m + 8)
            spacing: 0

            LcarsLabel {
                text: "DATE"
                color: LcarsUi.ink
                size: 20
                height: LcarsUi.u(24)
            }
            LcarsLabel {
                text: win.stardate
                color: LcarsUi.ink
                size: 30
                height: LcarsUi.u(38)
            }
        }

        // ---- TZ readout --------------------------------------------------------
        // No box any more - the cap and the elbow column are one continuous
        // shape, so the readout just sits on it.
        Row {
            x: LcarsUi.u(win.m + 8)
            y: LcarsUi.u(win.m + win.dateCapH + 12)
            spacing: LcarsUi.u(6)

            LcarsRect {
                anchors.verticalCenter: parent.verticalCenter
                width: LcarsUi.u(8)
                height: LcarsUi.u(8)
                color: LcarsUi.ink
            }
            LcarsLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: win.earthDate
                color: LcarsUi.ink
                size: 15
            }
        }
    }

    // =======================================================================
    // TOP BAND - the strip band, growing out of the COMMAND elbow.
    //
    // The elbow's own arm is `elbowArm` thick; the band continuing from it is
    // `bandThick`, a notch thinner, and both are top-aligned so the top edge
    // stays one continuous horizon and the arm keeps a small lip underneath.
    // =======================================================================
    Item {
        id: topBand
        x: 0
        y: LcarsUi.u(win.bandTop)
        width: win.width
        height: LcarsUi.u(win.elbowH)

        LcarsElbow {
            id: bandElbow
            x: 0
            y: 0
            width: LcarsUi.u(440)
            height: LcarsUi.u(win.elbowH)
            corner: "topLeft"
            color: LcarsUi.brick
            barThickness: LcarsUi.u(win.elbowArm)
            columnThickness: LcarsUi.u(win.railW)
            outerRadius: LcarsUi.u(win.r)
            innerRadius: LcarsUi.u(24)
        }

        Column {
            x: LcarsUi.u(22)
            y: LcarsUi.u(4)
            spacing: 0

            LcarsLabel {
                text: "COMMAND"
                color: LcarsUi.shade
                size: 34
            }
            LcarsLabel {
                text: "67187585"
                color: Qt.rgba(0.1, 0.06, 0.03, 0.75)
                size: 18
            }
        }

        // ---- the rest of the band ---------------------------------------------
        LcarsStrip {
            id: band2
            x: bandElbow.width
            y: 0
            width: LcarsUi.u(540)
            height: LcarsUi.u(win.bandThick)
            color: LcarsUi.gold
        }
        LcarsStrip {
            id: band3
            x: band2.x + band2.width
            y: 0
            width: LcarsUi.u(360)
            height: LcarsUi.u(win.bandThick)
            color: LcarsUi.peach
        }
        LcarsStrip {
            id: band4
            x: band3.x + band3.width
            y: 0
            width: LcarsUi.u(360)
            height: LcarsUi.u(win.bandThick)
            color: LcarsUi.violet
        }
        LcarsStrip {
            x: band4.x + band4.width
            y: 0
            width: Math.max(0, LcarsUi.u(win.edge) - x)
            height: LcarsUi.u(win.bandThick)
            color: LcarsUi.mauve
        }
    }

    // =======================================================================
    // LEFT RAIL - hangs off the elbow's column, filled down to the bottom band.
    // =======================================================================
    Item {
        id: rail
        x: 0
        y: LcarsUi.u(win.railTop)
        width: LcarsUi.u(win.railW)
        height: LcarsUi.u(win.railSpan)

        Repeater {
            model: win.railLayout

            delegate: Item {
                x: 0
                y: LcarsUi.u(modelData.y)
                width: rail.width
                height: LcarsUi.u(modelData.h)

                LcarsRect {
                    anchors.fill: parent
                    color: modelData.color
                }

                LcarsLabel {
                    // `left` / `right` are FINAL on Item - hence isRight
                    readonly property bool isRight: modelData.align === "right"
                    x: isRight ? 0 : LcarsUi.u(modelData.pad)
                    width: parent.width - LcarsUi.u(modelData.pad) * (isRight ? 1 : 1.6)
                    height: parent.height
                    text: modelData.text
                    color: LcarsUi.shade
                    size: modelData.size
                    horizontalAlignment: isRight ? Text.AlignRight : Text.AlignLeft
                    fit: true
                }
            }
        }
    }

    // =======================================================================
    // BOTTOM BAND - the closing strip band, off the bottom-left elbow.
    // =======================================================================
    Item {
        id: bottomBand
        x: 0
        y: LcarsUi.u(win.bottomBandTop)
        width: win.width
        height: LcarsUi.u(win.bottomElbowH)

        LcarsElbow {
            id: bottomElbow
            x: 0
            y: 0
            width: LcarsUi.u(440)
            height: LcarsUi.u(win.bottomElbowH)
            corner: "bottomLeft"
            color: LcarsUi.mauve
            barThickness: LcarsUi.u(win.bottomThick)
            columnThickness: LcarsUi.u(win.railW)
            outerRadius: LcarsUi.u(win.r)
            innerRadius: LcarsUi.u(24)
        }

        LcarsLabel {
            x: LcarsUi.u(22)
            y: LcarsUi.u(14)
            text: "LCARS"
            color: LcarsUi.shade
            size: 34
        }

        LcarsStrip {
            id: bband2
            x: bottomElbow.width
            y: bottomBand.height - LcarsUi.u(win.bottomThick)
            width: LcarsUi.u(600)
            height: LcarsUi.u(win.bottomThick)
            color: LcarsUi.violet
        }
        LcarsStrip {
            id: bband3
            x: bband2.x + bband2.width
            y: bottomBand.height - LcarsUi.u(win.bottomThick)
            width: LcarsUi.u(480)
            height: LcarsUi.u(win.bottomThick)
            color: LcarsUi.mauve
        }
        LcarsStrip {
            x: bband3.x + bband3.width
            y: bottomBand.height - LcarsUi.u(win.bottomThick)
            width: Math.max(0, LcarsUi.u(win.edge) - x)
            height: LcarsUi.u(win.bottomThick)
            color: LcarsUi.peach
        }
    }

}
