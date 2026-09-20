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

    // character width of each column, and how many digits it holds
    property var colWidths: [110, 116, 74, 92, 92, 92, 92, 92, 92, 92]
    property var colDigits: [4, 7, 2, 4, 4, 4, 4, 4, 4, 4]

    // flattened grid: [{ x, y, w, t }, ...] in design units
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
            const c = Math.floor(Math.random() * colWidths.length)
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
                out.push({ x: x, y: r * rowH, w: colWidths[c], t: grid[r][c] })
                x += colWidths[c]
            }
        }
        flat = out
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
            text: modelData.t
            color: root.textColor
            size: root.size
            caps: false
            horizontalAlignment: Text.AlignRight
        }
    }
}
