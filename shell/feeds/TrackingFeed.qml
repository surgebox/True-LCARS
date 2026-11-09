import QtQuick
import Quickshell.Io
import "../theme"

// ---------------------------------------------------------------------------
// TrackingFeed - live orbital + seismic data for the LCARS panels.
//
// This is the whole "port the feature" story in one file. It owns a single
// long-lived child process (feeds/orbit/track.mjs) and turns its stdout into
// QML properties. Nothing else in the shell needs to know that the data came
// from CelesTrak and USGS, or that SGP4 was involved.
//
//   TrackingFeed {
//       id: feed
//   }
//   LcarsLabel { text: feed.orbit ? feed.orbit.altKm.toFixed(1) + " KM" : "--" }
//
// TWO THINGS WORTH KNOWING
//
// 1. It never blanks. A dropped fetch or a parse failure leaves the previous
//    reading in place and only flips `fresh` - the same "parse is total"
//    discipline scripts/stats.sh is read with. A panel that goes empty on a
//    transient network error looks broken; one that says STALE does not.
//
// 2. It is line-oriented on purpose. One JSON object per line, tagged by
//    `kind`, means the feed can send orbit data at 1 Hz and earthquakes every
//    60 s over the same pipe without either one waiting on the other.
// ---------------------------------------------------------------------------
Item {
    id: root

    // -- process ------------------------------------------------------------
    // Resolve node rather than assuming a PATH: this machine's node is a mise
    // install, and Quickshell's environment is whatever the compositor handed
    // it. A login shell plus an explicit fallback covers both.
    readonly property string trackScript:
        Qt.resolvedUrl("orbit/track.mjs").toString().replace(/^file:\/\//, "")

    readonly property string trackCommand:
        "n=$(command -v node) || n=/usr/bin/node; " +
        "exec \"$n\" '" + root.trackScript.replace(/'/g, "'\\''") + "'"

    // -- live state ---------------------------------------------------------
    property bool feedUp: false          // a line arrived recently
    property double lastLineAt: 0

    // The orbit reading, or null before the first line. Read fields as
    // feed.orbit.lat etc. - the whole object is replaced each tick, so
    // bindings re-evaluate.
    property var orbit: null
    property bool orbitOk: false

    // Recent earthquakes, newest first, plus the true total for the window.
    property var quakeItems: []
    property int quakeCount: 0
    property var largestQuake: null
    property double quakesAt: 0

    // Sampled positions of the current orbit, from roughly half a period behind
    // to half a period ahead. `trackNowIndex` is the sample nearest the present
    // moment, so a view can draw the traversed part differently from the part
    // still to come.
    property var trackPoints: []
    property int trackNowIndex: 0
    property double trackPeriodMin: 0

    property string lastError: ""

    // Seconds since the last line, for a panel that wants to say how old its
    // numbers are. Ticks on its own so the label ages even if the feed stalls.
    property double ageS: 0

    function applyLine(line) {
        const text = ("" + line).trim()
        if (text.length === 0)
            return
        let o
        try {
            o = JSON.parse(text)
        } catch (e) {
            // A torn or non-JSON line is dropped, not fatal: the next tick
            // fixes it. Only real JSON ever reaches the state below.
            root.lastError = "parse: " + e
            return
        }

        root.lastLineAt = Date.now()

        if (o.kind === "orbit") {
            // `ok:false` means this reading did not update - keep the last
            // good position rather than snapping the marker to the equator.
            if (o.ok) {
                root.orbit = o
                root.orbitOk = true
            } else {
                root.orbitOk = false
                root.lastError = "orbit: " + (o.reason || "failed")
            }
        } else if (o.kind === "quakes") {
            if (o.ok) {
                root.quakeItems = o.items || []
                root.quakeCount = o.count || 0
                root.largestQuake = o.largest || null
                root.quakesAt = o.t || Date.now()
            }
        } else if (o.kind === "track") {
            if (o.ok) {
                root.trackPoints = o.points || []
                root.trackNowIndex = o.nowIndex || 0
                root.trackPeriodMin = o.periodMin || 0
            }
        }
    }

    Process {
        id: trackProc
        command: ["bash", "-lc", root.trackCommand]
        running: true

        stdout: SplitParser {
            onRead: (line) => root.applyLine(line)
        }

        stderr: SplitParser {
            onRead: (line) => {
                // track.mjs keeps diagnostics on stderr precisely so they can
                // be shown without polluting the feed. Only the tagged ones are
                // worth a red line in the UI - routine notes ("TLE loaded from
                // cache") would otherwise sit there looking like a fault.
                const t = ("" + line).trim()
                if (t.length > 0 && /error/i.test(t))
                    root.lastError = t.replace(/^track:\s*ERROR\s*/i, "")
            }
        }
    }

    // Quickshell deliberately carries a Process across config reloads, so it
    // will not restart one that has died - the panels would freeze on their
    // last reading. Same slow heartbeat as the stats poller in shell.qml.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!trackProc.running) {
                root.feedUp = false
                trackProc.running = true
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.ageS = root.lastLineAt > 0
                ? (Date.now() - root.lastLineAt) / 1000
                : 0
            // Three missed ticks at 1 Hz means the feed is not merely slow.
            root.feedUp = root.lastLineAt > 0 && root.ageS < 3.5
        }
    }
}
