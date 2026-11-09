import QtQuick
import "../theme"

// ---------------------------------------------------------------------------
// LcarsReadout - the amber numeric cascade from the top of the reference.
//
// A matrix of zero-padded numbers in fixed-width, right-aligned columns. A
// timer nudges a few cells so it reads as live telemetry rather than a static
// screenshot; set `live: false` for a frozen table.
//
// The grid is flattened to a list of absolutely-positioned cells and rendered
// by a single Repeater. Nesting two Repeaters would shadow Repeater's injected
// `index`, and this version of Qt refuses a delegate that re-declares it.
// ---------------------------------------------------------------------------
Item {
    id: root

    property color textColor: LcarsUi.amber
    property real size: 30
    property int rows: 6
    property real rowSpacing: 8
    property bool live: true
    property int tickMs: 620
    // The final two columns can show live network values in place of digits.
    property var networkMetrics: ({})

    // A slow white scan through the telemetry, measured start-to-start.
    property bool sweepEnabled: true
    property int sweepIntervalMs: 20000
    property int sweepRowMs: 1000
    readonly property bool sweepActive: sweepEnabled && live && visible && opacity > 0
    property int sweepRow: -1
    property real flashStrength: 0
    readonly property color flashColor: Qt.rgba(
        textColor.r + (1 - textColor.r) * flashStrength,
        textColor.g + (1 - textColor.g) * flashStrength,
        textColor.b + (1 - textColor.b) * flashStrength,
        textColor.a)

    onSweepActiveChanged: {
        if (!sweepActive)
            sweepRow = -1
    }
    onSweepRowChanged: {
        flashPulse.stop()
        flashStrength = 0
        if (sweepRow >= 0)
            flashPulse.start()
    }

    // character width of each column, and how many digits it holds
    property var colWidths: [110, 116, 74, 92, 92, 92, 92, 92, 92, 92]
    property var colDigits: [4, 7, 2, 4, 4, 4, 4, 4, 4, 4]

    // flattened grid: [{ x, y, w, t, row }, ...] in design units
    property var flat: []

    readonly property real rowHeight: LcarsUi.u(size) * 1.26
    implicitHeight: rows * (rowHeight + LcarsUi.u(rowSpacing))

    Component.onCompleted: regenerate()
    onRowsChanged: regenerate()

    function randCell(col) {
        const digits = colDigits[col]
        let s = ""
        for (let i = 0; i < digits; i++)
            s += Math.floor(Math.random() * 10)
        return s
    }

    function networkValue(row) {
        const details = networkMetrics || {}
        if (!details.iface) return "--"
        if (row === 2) {
            if (details.internet_ping_ms === null || details.internet_ping_ms === undefined
                || details.internet_ping_ms === "") return "--"
            const ping = Number(details.internet_ping_ms)
            return Number.isFinite(ping) ? Math.round(ping) + " MS" : "--"
        }
        const value = Number(row === 0 ? details.downloadBps : details.uploadBps)
        if (!Number.isFinite(value) || value < 0
            || (row === 0 ? details.downloadBps : details.uploadBps) === null)
            return "--"
        if (value < 1024) return Math.round(value) + " B/S"
        if (value < 1048576) return (value / 1024).toFixed(1) + " K/S"
        return (value / 1048576).toFixed(1) + " M/S"
    }

    function cellText(cell) {
        if (cell.row < 3 && cell.col === colWidths.length - 2)
            return ["DWNLD", "UPLD", "PNG"][cell.row]
        if (cell.row < 3 && cell.col === colWidths.length - 1)
            return networkValue(cell.row)
        return cell.t
    }

    function regenerate() {
        const cols = colWidths.length
        const grid = []
        for (let r = 0; r < rows; r++) {
            const row = []
            for (let c = 0; c < cols; c++)
                row.push(randCell(c))
            grid.push(row)
        }
        flatten(grid)
    }

    // Replace a few cells so the binding on `flat` re-fires - the numbers
    // should crawl the way a live telemetry board does.
    function jitter() {
        const grid = []
        for (let i = 0; i < flat.length; i += colWidths.length) {
            const row = []
            for (let c = 0; c < colWidths.length; c++)
                row.push(flat[i + c].t)
            grid.push(row)
        }
        for (let n = 0; n < 3; n++) {
            const r = Math.floor(Math.random() * grid.length)
            const c = Math.floor(Math.random() * Math.max(1, colWidths.length - 2))
            grid[r][c] = randCell(c)
        }
        flatten(grid)
    }

    function flatten(grid) {
        const out = []
        const rowH = rowSpacing + size * 1.26
        for (let r = 0; r < grid.length; r++) {
            let x = 0
            for (let c = 0; c < colWidths.length; c++) {
                out.push({ x: x, y: r * rowH, w: colWidths[c], t: grid[r][c], row: r, col: c })
                x += colWidths[c]
            }
        }
        flat = out
    }

    Timer {
        running: root.sweepActive && root.rows > 0
        interval: root.sweepIntervalMs
        repeat: true
        onTriggered: {
            if (root.sweepRow < 0)
                root.sweepRow = 0
        }
    }

    Timer {
        running: root.sweepActive && root.sweepRow >= 0
        interval: root.sweepRowMs
        repeat: true
        onTriggered: root.sweepRow = root.sweepRow + 1 < root.rows ? root.sweepRow + 1 : -1
    }

    SequentialAnimation {
        id: flashPulse
        NumberAnimation { target: root; property: "flashStrength"; to: 1; duration: root.sweepRowMs * 0.15 }
        PauseAnimation { duration: root.sweepRowMs * 0.6 }
        NumberAnimation { target: root; property: "flashStrength"; to: 0; duration: root.sweepRowMs * 0.25 }
    }

    Timer {
        running: root.live && root.visible
        interval: root.tickMs
        repeat: true
        onTriggered: root.jitter()
    }

    Repeater {
        model: root.flat

        delegate: LcarsLabel {
            x: LcarsUi.u(modelData.x)
            y: LcarsUi.u(modelData.y)
            width: LcarsUi.u(modelData.w)
            height: root.rowHeight
            text: root.cellText(modelData)
            color: modelData.row === root.sweepRow ? root.flashColor : root.textColor
            size: root.size
            caps: false
            horizontalAlignment: Text.AlignRight
        }
    }
}
