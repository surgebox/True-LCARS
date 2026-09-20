import QtQuick
import QtQuick.Shapes
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

    // =======================================================================
    // COLLAPSE / EXPAND
    //
    // `expand` is the single driver: 0 is the collapsed strip, 1 is the full
    // panel. Everything that moves is a lerp on it, and because the layout's
    // own metrics (headH, bandTop, railTop, appY) are derived from dateElbowH,
    // animating this one number walks the whole panel open - the band, the rail
    // and the app field all follow without knowing anything about it.
    //
    // The Behavior is on `expand` itself and it is assigned imperatively by the
    // arrow, which is the one arrangement where a Behavior is guaranteed to
    // run; bind it to a state expression instead and the animation is skipped.
    // =======================================================================
    property real expand: 0

    // 600ms: the panel travels 134 units vertically, so it wants longer than a
    // hover transition to read as one deliberate movement rather than a snap.
    Behavior on expand {
        NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
    }

    function lerp(a, b) {
        return a + (b - a) * win.expand
    }

    // ---- the date column ---------------------------------------------------
    // The cap itself collapses: the stardate is the line that folds away, which
    // is most of what makes the flat state short. The Earth date stays and is
    // the bigger of the two now.
    readonly property real dateCapHFlat: 38      // one line: the Earth date only
    readonly property real dateCapHOpen: 96
    readonly property real dateCapH: lerp(dateCapHFlat, dateCapHOpen)

    // 2 units of overlap, not a butt joint: two same-coloured shapes meeting
    // exactly leave a hairline where their antialiased edges land on different
    // pixels. The cap is drawn last, so it hides the overlap.
    readonly property real dateElbowTop: m + dateCapH - 2

    // The elbow box is what collapses: flat, the arm sits just under the cap;
    // open, the column runs the full height it used to.
    readonly property real dateElbowFlat: 44
    readonly property real dateElbowOpen: 120
    readonly property real dateElbowH: lerp(dateElbowFlat, dateElbowOpen)

    readonly property real dateArmThick: 24                 // its thin horizontal bar

    // A gap cut across the DATE column, matching the gaps between the column
    // buttons. Sits about halfway down the column, below the date itself.
    readonly property real dateStripH: railGap
    readonly property real dateStripY:
        dateElbowTop + (dateElbowH - dateArmThick) / 2 - dateStripH / 2
    readonly property real dateArmGap: 12                   // black before the top band

    // the chevron rides the arm itself rather than sitting on a segment of its
    // own, centred on the screen; it is transparent, so all you see is the glyph
    readonly property real chevW: 96
    readonly property real chevH: 36

    readonly property real headH: dateElbowTop + dateElbowH + g
    // ---- the two arms ------------------------------------------------------
    // Both arms are the same object mirrored about the screen's midline: the
    // elbows are topLeft and bottomLeft, and the segments running out of them
    // are the same four colours in the same order at the same lengths. A
    // vertical flip preserves left-to-right order, so "flipped image of each
    // other" and "same order" are the same thing here.
    readonly property real elbowArmLen: 440        // how far each elbow's arm runs
    readonly property real bandGap: 4              // the thin dividers, half of railGap
    readonly property var armColors: [LcarsUi.gold, LcarsUi.peach,
                                      LcarsUi.violet, LcarsUi.mauve]

    // segment geometry, in device pixels, shared by both bands
    readonly property real bandSegStart: LcarsUi.u(elbowArmLen + bandGap)
    readonly property real bandSegW:
        (LcarsUi.u(edge) - bandSegStart - LcarsUi.u(bandGap) * (armColors.length - 1))
        / armColors.length

    readonly property real bandTop: headTop + dateElbowTop + dateElbowH + dateArmGap

    // the collapsed panel's height, held constant so the flat row does not drift
    // while the animation runs
    readonly property real headHFlat: m + dateCapHFlat - 2 + dateElbowFlat + g

    // ---- the volume column, in the gutter between the DATE column and the
    //      numeric readout. These are ABSOLUTE design y values; the header's
    //      children are offset by headTop, so the placements subtract it back.
    readonly property real volX: 262        // clear of the DATE column (ends at 210)
    readonly property real volW: 42
    readonly property real volY: 90
    readonly property real volH: 120
    readonly property real volBtnY: volY + volH + 6     // 216
    readonly property real volBtnH: 30
    readonly property real readoutX: volX + volW + 10   // 266

    // ---- the CPU / MEM / NET / DSK buttons ---------------------------------
    // Collapsed they are one row across the panel; open they gather into the 2x2
    // grid on the right. Every position is a lerp between the two.
    readonly property real clusterW: 440
    readonly property real clusterX: edge - clusterW
    readonly property real capsuleW: (clusterW - g) / 2     // the open grid's cell
    readonly property real capsuleH: 38
    readonly property real capsuleRow1: 72                  // below the ACCESS title
    readonly property real capsuleRow2: 72 + capsuleH + g

    // ---- the horizontal volume control, collapsed panel only ----------------
    readonly property real volHX: volX + volW + 12          // right of the speaker
    readonly property real volHCompactW: 46                 // idle: one block
    readonly property real volHOpenW: 200                   // open: the meter
    // The stat row starts after it, so the buttons ride along as it opens
    // instead of being overlapped by it.
    readonly property real capsuleRowX: volHX + volHoriz.designWidth + g

    // =======================================================================
    // THE ACTIVE FUNCTION
    //
    // Picking a column block recolours the two elbows - the COMMAND one and the
    // LCARS one at the bottom - with that block's colour, and prints the
    // function's name in the COMMAND block. With nothing picked both elbows sit
    // on their own default colours, so the resting state is exactly what it was.
    //
    // Clicking the active block again clears it. Whichever view each `fn` opens
    // is the next session's work; for now the selection is the whole behaviour.
    // =======================================================================
    property string activeFn: ""
    property color activeAccent: LcarsUi.brick

    function selectFn(fn, acc) {
        if (win.activeFn === fn) {
            win.activeFn = ""
        } else {
            win.activeFn = fn
            win.activeAccent = acc
        }
    }

    // Every segment of both arms goes through this: with a function picked they
    // all take its colour, so the whole arm reads as belonging to that function
    // rather than just the elbow at its end.
    function themed(defaultColor) {
        return win.activeFn === "" ? defaultColor : win.activeAccent
    }

    readonly property color commandColor:
        win.activeFn === "" ? LcarsUi.brick : win.activeAccent
    readonly property color lcarsColor:
        win.activeFn === "" ? LcarsUi.mauve : win.activeAccent

    readonly property string activeFnName: {
        if (win.activeFn === "")
            return ""
        const b = win.railBlocks
        for (let i = 0; i < b.length; i++) {
            if (b[i].fn === win.activeFn)
                return b[i].fnName
        }
        return ""
    }
    // header-relative: flat, the row's top edge sits flush with the top of the
    // date shape rather than floating in the middle of the panel
    readonly property real capsuleFlatY: m

    // The buttons keep ONE size in both states - only their positions move. A
    // stretching cell meant the flat row had to be tall enough to hold the
    // stretched shape, which is height the collapsed panel does not have.
    readonly property real capW: capsuleW

    function capX(i) {
        const flat = capsuleRowX + i * (capsuleW + g)
        const open = (i % 2 === 0) ? clusterX : clusterX + clusterW - capsuleW
        return lerp(flat, open)
    }
    function capY(i) {
        const open = m + (i < 2 ? capsuleRow1 : capsuleRow2)
        return lerp(capsuleFlatY, open)
    }

    readonly property real elbowArm: 48    // the COMMAND elbow's own bar
    // The three middle segments: half the thickness of the elbow and the last
    // segment, top-aligned with them so all four share one top edge. Only the
    // depth changes, so the band's underside steps in and out.
    readonly property real bandThick: 19
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
    readonly property real appY: bandTop + elbowArm + g
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

            // Hook for the power menu: shutdown / reboot / logout. Deliberately
            // just a log for now - nothing here should be able to take the
            // session down until the menu behind it exists.
            onPowerClicked: console.log("LCARS power button pressed")
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

    // `fn` is the id of the view this block selects; `fnName` is what the
    // COMMAND block displays once it is the active one. The visible labels are
    // left exactly as they were - the numbers are part of the look - so the
    // mapping lives here until there are real views to name them after.
    // Every block is set the same way - right-aligned against the same pad, at
    // the same size - so the column reads as one list rather than six labels
    // that happen to be stacked. (COMMAND and LCARS are elbow captions, not
    // column blocks, and keep their own alignment.)
    readonly property var railBlocks: [
        { w: 1.0, color: LcarsUi.rust,   text: "SYSTEM",  size: 34, align: "right", pad: 22,
          fn: "system",  fnName: "SYSTEM STATS" },
        { w: 1.0, color: LcarsUi.violet, text: "ARCHIVE", size: 34, align: "right", pad: 22,
          fn: "archive", fnName: "FILE ARCHIVE" },
        { w: 1.0, color: LcarsUi.gold,   text: "NETWORK", size: 34, align: "right", pad: 22,
          fn: "network", fnName: "NETWORK" },
        { w: 1.0, color: LcarsUi.peach,  text: "LAUNCH",  size: 34, align: "right", pad: 22,
          fn: "launch",  fnName: "APP LAUNCHER" },
        { w: 1.0, color: LcarsUi.mauve,  text: "COMMS",   size: 34, align: "right", pad: 22,
          fn: "comms",   fnName: "COMMS" },
        { w: 1.0, color: LcarsUi.violet, text: "MAIN",    size: 34, align: "right", pad: 22,
          fn: "home",    fnName: "MAIN DISPLAY" }
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
                size: blocks[i].size, align: blocks[i].align, pad: blocks[i].pad,
                fn: blocks[i].fn, fnName: blocks[i].fnName
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

        // ---- DATE elbow --------------------------------------------------------
        // The date column turns into an upside-down elbow: arm to the right, outer
        // corner rounded at the bottom-left, concave shoulder above it. The arm
        // spans the full width and sits `dateArmGap` above the top band, so the
        // two read as two separate bars with a plain black gap between them.
        // Collapsed, the column is short enough that the arm tucks in right
        // under the chevron.
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

        // The cap carries both dates now: the stardate and the Earth date are what
        // stay legible when everything else folds away.
        // Drawn over the elbow and the cap, so it reads as a gap rather than a
        // bar. Fades with the panel - collapsed there is no room for it to read
        // as anything but a seam.
        LcarsRect {
            x: LcarsUi.u(win.m)
            y: LcarsUi.u(win.dateStripY)
            width: LcarsUi.u(win.railW - win.m)
            height: LcarsUi.u(win.dateStripH)
            color: LcarsUi.black
            opacity: win.expand
        }

        Column {
            x: LcarsUi.u(win.m + 12)
            y: LcarsUi.u(win.m + 4)
            spacing: 0

            // Flat, the label goes too - the date speaks for itself and the cap
            // shrinks to a single line, which is most of the remaining height.
            LcarsLabel {
                text: "DATE"
                color: LcarsUi.ink
                size: 16
                height: LcarsUi.u(20 * win.expand)
                opacity: win.expand
            }
            // Thin and a different colour from the date below it, so the two read
            // as different kinds of readout rather than two lines of the same one.
            LcarsLabel {
                text: win.stardate
                color: LcarsUi.plum
                weight: Font.Light
                size: 28
                height: LcarsUi.u(34 * win.expand)
                opacity: win.expand
            }
            LcarsLabel {
                text: win.earthDate
                color: LcarsUi.ink
                size: 24
                height: LcarsUi.u(30)
            }
        }

        // ---- collapse / expand chevron -----------------------------------------
        // Transparent, so there is no segment colour to clash with the arm - just
        // the glyph, sitting on the arm itself and centred on the screen. It rides
        // the arm as the panel animates, because its y is measured off the elbow.
        LcarsIconButton {
            x: LcarsUi.u(win.dw / 2 - win.chevW / 2)
            y: LcarsUi.u(win.dateElbowTop + win.dateElbowH
                         - win.dateArmThick / 2 - win.chevH / 2)
            width: LcarsUi.u(win.chevW)
            height: LcarsUi.u(win.chevH)
            // points the way the panel will move
            glyph: win.expand < 0.5 ? "\uf078" : "\uf077"
            glyphSize: 20
            iconColor: LcarsUi.ink
            onClicked: {
                win.expand = win.expand < 0.5 ? 1 : 0
                volHoriz.open = false       // it belongs to the flat panel
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
            // squared, so the meter is mostly gone before the speaker rises
            // through where it was
            opacity: win.expand * win.expand
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

        // The speaker rides up into the flat row as the panel closes.
        LcarsIconButton {
            id: speakerButton
            x: LcarsUi.u(win.volX)
            y: LcarsUi.u(win.lerp(win.capsuleFlatY + (win.capsuleH - win.volBtnH) / 2,
                                  win.volBtnY - win.headTop))
            width: LcarsUi.u(win.volW)
            height: LcarsUi.u(win.volBtnH)
            // Font Awesome ships three speakers: none, one wave, two. The count
            // follows the level, so the glyph reads as the head of the gauge the
            // same way its colour does.
            glyph: win.shownLevel <= 0 ? "\uf026"
                 : (win.shownLevel < 0.5 ? "\uf027" : "\uf028")
            glyphSize: 24
            // idle, the glyph takes the meter's own current colour, so it
            // reads as the head of the gauge: green low, red at max
            iconColor: volumeBar.levelColor
            active: win.muted                  // muted: red block + cut glyph
            onClicked: win.audio(["toggle-mute"])
        }

        // ---- horizontal volume control (collapsed panel only) -------------------
        LcarsVolumeBarH {
            id: volHoriz
            x: LcarsUi.u(win.volHX)
            y: LcarsUi.u(win.capsuleFlatY)
            height: LcarsUi.u(win.capsuleH)
            opacity: 1 - win.expand     // the vertical meter takes over when open
            level: win.shownLevel
            muted: win.muted
            boxes: 12
            gap: 2

            onMoved: (l) => {
                win.dragging = true
                win.dragLevel = l
            }
            onCommitted: (l) => {
                win.dragging = false
                win.audio(["set", Math.round(l * 100)])
            }
        }

        // ---- numeric cascade ---------------------------------------------------
        LcarsReadout {
            x: LcarsUi.u(win.readoutX)
            y: LcarsUi.u(14)
            width: Math.max(0, LcarsUi.u(win.clusterX) - x - LcarsUi.u(20))
            height: LcarsUi.u(128)
            opacity: win.expand
            size: 20
            rows: 4
            rowSpacing: 6
            colWidths: [130, 140, 88, 110, 110, 110, 110, 110, 110, 110]
            colDigits: [4, 7, 2, 4, 4, 4, 4, 4, 4, 4]
        }

        // ---- ACCESS title ------------------------------------------------------
        LcarsLabel {
            x: LcarsUi.u(win.clusterX)
            y: LcarsUi.u(win.m)
            width: LcarsUi.u(win.clusterW)
            height: LcarsUi.u(62)
            text: "LCARS ACCESS 441"
            color: LcarsUi.orange
            size: 46
            horizontalAlignment: Text.AlignRight
            fit: true
            opacity: win.expand
        }

        // ---- CPU / MEM / NET / DSK ---------------------------------------------
        // One row when collapsed, the 2x2 grid when open - see capX/capY.
        LcarsCapsule {
            x: LcarsUi.u(win.capX(0))
            y: LcarsUi.u(win.capY(0))
            width: LcarsUi.u(win.capW)
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
            x: LcarsUi.u(win.capX(1))
            y: LcarsUi.u(win.capY(1))
            width: LcarsUi.u(win.capW)
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
            x: LcarsUi.u(win.capX(2))
            y: LcarsUi.u(win.capY(2))
            width: LcarsUi.u(win.capW)
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
            x: LcarsUi.u(win.capX(3))
            y: LcarsUi.u(win.capY(3))
            width: LcarsUi.u(win.capW)
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
            width: LcarsUi.u(win.elbowArmLen)
            height: LcarsUi.u(win.elbowH)
            corner: "topLeft"
            color: win.commandColor
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
                text: win.activeFnName !== "" ? win.activeFnName : "67187585"
                color: Qt.rgba(0.1, 0.06, 0.03, 0.75)
                size: 18
            }
        }

        // ---- the arm: four equal segments, thin dividers between ------------
        // The middle three run at the band's thickness; the last one is cut at
        // the elbow's own, so the arm steps down out of the elbow and back up
        // again at its far end. All top-aligned, so the step shows as a hard
        // change of depth along the bottom edge.
        Repeater {
            model: win.armColors.length - 1

            delegate: LcarsStrip {
                x: win.bandSegStart + index * (win.bandSegW + LcarsUi.u(win.bandGap))
                y: 0
                width: win.bandSegW
                height: LcarsUi.u(win.bandThick)
                color: win.themed(win.armColors[index])
            }
        }

        LcarsStrip {
            x: win.bandSegStart + (win.armColors.length - 1)
                * (win.bandSegW + LcarsUi.u(win.bandGap))
            y: 0
            width: win.bandSegW
            height: LcarsUi.u(win.elbowArm)
            color: win.themed(win.armColors[win.armColors.length - 1])
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

                // hover lift, so the column reads as pressable
                LcarsRect {
                    anchors.fill: parent
                    color: "white"
                    opacity: barMouse.containsMouse ? 0.12 : 0
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }

                // The active block is marked rather than recoloured - its own
                // colour is the thing the arms are matching, so it has to stay
                // itself. A '>' off the left edge reads as "this one".
                Shape {
                    id: mark
                    visible: win.activeFn === modelData.fn
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: LcarsUi.u(15)
                    height: LcarsUi.u(26)
                    preferredRendererType: Shape.CurveRenderer
                    antialiasing: true

                    ShapePath {
                        fillColor: LcarsUi.ink
                        PathSvg {
                            path: "M 0 0 L " + mark.width + " " + (mark.height / 2)
                                + " L 0 " + mark.height + " Z"
                        }
                    }
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

                MouseArea {
                    id: barMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.selectFn(modelData.fn, modelData.color)
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
            width: LcarsUi.u(win.elbowArmLen)
            height: LcarsUi.u(win.bottomElbowH)
            corner: "bottomLeft"
            color: win.lcarsColor
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

        Repeater {
            model: win.armColors

            delegate: LcarsStrip {
                x: win.bandSegStart + index * (win.bandSegW + LcarsUi.u(win.bandGap))
                y: bottomBand.height - LcarsUi.u(win.bottomThick)
                width: win.bandSegW
                height: LcarsUi.u(win.bottomThick)
                color: win.themed(modelData)
            }
        }
    }

}
