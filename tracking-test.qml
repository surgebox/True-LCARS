import QtQuick
import QtQuick.Window

import "theme"
import "ui"
import "feeds"

// ---------------------------------------------------------------------------
// tracking-test - proof of concept for the "God's Eye View" data layer.
//
//     ./run.sh                       (edit run.sh, or:)
//     qs -p tracking-test.qml
//     ./dev/shot.sh tracking-test.qml dev/shots/tracking.png
//
// Two live panels over a real feed:
//
//   ORBITAL TRACKING   ISS ground track + telemetry, recomputed by SGP4 at
//                      1 Hz from a cached TLE. No network traffic per tick.
//   SEISMIC ACTIVITY   USGS events from the last 24 h, newest first.
//
// Everything on screen is real - there is no simulated data anywhere in this
// file, which is the point. If the feed stops, the panels say so instead of
// inventing numbers (compare LcarsReadout, which is deliberately decorative).
//
// This is a harness, not a layout study: it does not touch shell.qml.
// ---------------------------------------------------------------------------
Window {
    id: win

    readonly property real dh: 1152 // design canvas height, as in shell.qml

    width: 2048
    height: 1152
    visible: true
    color: LcarsUi.black
    title: "LCARS // tracking test"

    Binding { target: LcarsUi; property: "scale"; value: win.height / win.dh }

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    // ---- the feed ---------------------------------------------------------
    TrackingFeed {
        id: feed

        // Ground track accumulates here rather than in the feed: it is a view
        // concern, and the feed stays a pure data source.
        onOrbitChanged: {
            if (orbit && orbit.ok)
                win.pushTrail(orbit.lat, orbit.lon)
        }
    }

    // ---- metrics (design units) -------------------------------------------
    readonly property real m: 28
    readonly property real g: 18
    readonly property real headerH: 64
    readonly property real contentY: m + headerH + g
    readonly property real contentH: dh - contentY - m
    readonly property real leftW: 1160
    readonly property real rightX: m + leftW + g
    readonly property real rightW: 2048 - m - rightX

    // A clock the relative timestamps read, so "2M AGO" keeps aging. A binding
    // that calls ago() picks this up as a dependency and re-evaluates each tick.
    property double clock: Date.now()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: win.clock = Date.now()
    }

    // ---- ground track state ------------------------------------------------
    property var trail: []
    readonly property int trailMax: 200

    function pushTrail(lat, lon) {
        const t = win.trail.slice()
        t.push({ lat: lat, lon: lon })
        while (t.length > win.trailMax)
            t.shift()
        win.trail = t
    }

    // ---- helpers -----------------------------------------------------------
    function f(v, dp) {
        return (v === null || v === undefined) ? "--" : Number(v).toFixed(dp)
    }

    // Sign + degree, the way a tracking console prints a fix.
    function coord(v, dp, pos, neg) {
        if (v === null || v === undefined)
            return "--"
        const a = Math.abs(v).toFixed(dp)
        return a + "\u00B0" + (v >= 0 ? pos : neg)
    }

    function ago(ms) {
        const now = win.clock // dependency, so this re-evaluates each second
        if (!ms)
            return "--"
        const s = Math.max(0, (now - ms) / 1000)
        if (s < 90) return Math.round(s) + "S"
        if (s < 5400) return Math.round(s / 60) + "M"
        return Math.round(s / 3600) + "H"
    }

    function utc(ms) {
        if (!ms)
            return "--:--"
        return new Date(ms).toISOString().substr(11, 5)
    }

    function number(n) {
        if (n === null || n === undefined)
            return "--"
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    // Seismic severity ramp - the one place this borrows the LCARS habit of
    // colour carrying meaning.
    function magColor(mag) {
        if (mag === null || mag === undefined) return LcarsUi.grey
        if (mag >= 6.0) return LcarsUi.red
        if (mag >= 5.0) return LcarsUi.salmon
        if (mag >= 4.0) return LcarsUi.orange
        if (mag >= 3.0) return LcarsUi.gold
        if (mag >= 2.0) return LcarsUi.amber
        return LcarsUi.grey
    }

    // ---- telemetry rows ----------------------------------------------------
    // Two columns of caption/value pairs, interleaved so a single Repeater can
    // lay them out as `index % 2` (column) and `floor(index / 2)` (row).
    // Nesting two Repeaters would shadow Repeater's injected `index`, which
    // this Qt refuses - the same reason LcarsReadout flattens its grid.
    readonly property var o: feed.orbit

    readonly property var telemetry: {
        if (!win.o)
            return []
        const a = [
            { c: "NORAD ID", v: "" + win.o.noradId, k: 0 },
            { c: "LATITUDE", v: win.coord(win.o.lat, 3, "N", "S"), k: 1 },
            { c: "LONGITUDE", v: win.coord(win.o.lon, 3, "E", "W"), k: 1 },
            { c: "ALTITUDE", v: win.f(win.o.altKm, 1) + " KM", k: 2 },
            { c: "VELOCITY", v: win.number(Math.round(win.o.speedKmh)) + " KM/H", k: 2 }
        ]
        const b = [
            { c: "INCLINATION", v: win.f(win.o.inclinationDeg, 2) + "\u00B0", k: 0 },
            { c: "ECCENTRICITY", v: win.f(win.o.eccentricity, 6), k: 0 },
            { c: "PERIOD", v: win.f(win.o.periodMin, 2) + " MIN", k: 2 },
            { c: "REVOLUTION", v: "" + win.o.revNumber, k: 0 },
            { c: "TLE AGE", v: win.ago(win.clock - win.o.tle.ageS * 1000), k: 3 }
        ]
        const out = []
        for (let i = 0; i < Math.max(a.length, b.length); i++) {
            if (i < a.length) out.push(a[i])
            if (i < b.length) out.push(b[i])
        }
        return out
    }

    // Value inks: mostly amber, with the numbers that matter in orange.
    function ink(k) {
        if (k === 1) return LcarsUi.orange
        if (k === 2) return LcarsUi.amber
        if (k === 3) return LcarsUi.grey
        return LcarsUi.ice
    }

    // =======================================================================
    // HEADER
    // =======================================================================
    LcarsStrip {
        x: LcarsUi.u(win.m)
        y: LcarsUi.u(win.m)
        width: LcarsUi.u(win.leftW)
        height: LcarsUi.u(win.headerH)
        color: LcarsUi.orange
        capLeft: true
        round: LcarsUi.u(14)
    }

    LcarsLabel {
        x: LcarsUi.u(win.m + 34)
        y: LcarsUi.u(win.m)
        height: LcarsUi.u(win.headerH)
        text: "TRACKING TEST"
        color: LcarsUi.shade
        size: 34
        tracking: true
    }

    LcarsLabel {
        anchors.right: parent.right
        anchors.rightMargin: LcarsUi.u(win.m + 34)
        y: LcarsUi.u(win.m)
        height: LcarsUi.u(win.headerH)
        text: "GOD'S EYE VIEW // DATA LAYER PORT"
        color: LcarsUi.ember
        size: 22
        tracking: true
        horizontalAlignment: Text.AlignRight
    }

    // Feed health, stated plainly. This is the panel that tells you the rest of
    // the screen is trustworthy.
    LcarsCapsule {
        x: LcarsUi.u(win.rightX)
        y: LcarsUi.u(win.m)
        width: LcarsUi.u(win.rightW * 0.46)
        height: LcarsUi.u(win.headerH)
        label: "FEED"
        value: feed.feedUp ? "LIVE" : (feed.lastLineAt > 0 ? "STALE" : "WAIT")
        color: feed.feedUp ? LcarsUi.sky
                           : (feed.lastLineAt > 0 ? LcarsUi.salmon : LcarsUi.grey)
        valueColor: LcarsUi.ink
        labelColor: LcarsUi.ink
    }

    LcarsCapsule {
        x: LcarsUi.u(win.rightX + win.rightW * 0.5)
        y: LcarsUi.u(win.m)
        width: LcarsUi.u(win.rightW * 0.5)
        height: LcarsUi.u(win.headerH)
        label: "AGE"
        value: feed.lastLineAt > 0 ? feed.ageS.toFixed(1) + "S" : "--"
        color: LcarsUi.lilac
        valueColor: LcarsUi.ink
        labelColor: LcarsUi.ink
    }

    // =======================================================================
    // LEFT - ORBITAL TRACKING
    // =======================================================================
    Item {
        id: orbitPanel
        x: LcarsUi.u(win.m)
        y: LcarsUi.u(win.contentY)
        width: LcarsUi.u(win.leftW)
        height: LcarsUi.u(win.contentH)

        // ---- panel head ----
        LcarsStrip {
            id: orbitHead
            width: parent.width
            height: LcarsUi.u(56)
            color: LcarsUi.violet
            capRight: true
            round: LcarsUi.u(12)
        }

        LcarsLabel {
            x: LcarsUi.u(26)
            height: orbitHead.height
            text: "ORBITAL TRACKING"
            color: LcarsUi.ink
            size: 28
            tracking: true
        }

        LcarsLabel {
            anchors.right: parent.right
            anchors.rightMargin: LcarsUi.u(30)
            height: orbitHead.height
            text: feed.orbit && feed.orbit.name ? feed.orbit.name : "ACQUIRING"
            color: LcarsUi.ink
            size: 26
            horizontalAlignment: Text.AlignRight
            width: parent.width * 0.5
        }

        // ---- ground track ----
        // Equirectangular, not a globe: an honest 2D projection needs no 3D
        // engine, and at this size it reads better than a small sphere would.
        Item {
            id: mapArea
            x: LcarsUi.u(64)
            y: orbitHead.height + LcarsUi.u(22)
            width: parent.width - LcarsUi.u(64 + 24)
            height: LcarsUi.u(420)

            // lon -> x, lat -> y
            function mx(lon) { return (lon + 180) / 360 * width }
            function my(lat) { return (90 - lat) / 180 * height }

            LcarsRect {
                anchors.fill: parent
                color: "#05050a"
                borderColor: Qt.rgba(0.6, 0.6, 0.7, 0.25)
                borderWidth: 1
                radiusTL: LcarsUi.u(10)
                radiusTR: LcarsUi.u(10)
                radiusBR: LcarsUi.u(10)
                radiusBL: LcarsUi.u(10)
            }

            // graticule: meridians every 30 deg, parallels every 30 deg
            Repeater {
                model: 11
                delegate: LcarsRect {
                    x: mapArea.mx(index * 30 - 180)
                    y: 0
                    width: 1
                    height: mapArea.height
                    color: Qt.rgba(0.6, 0.6, 0.7, index === 5 ? 0.28 : 0.13)
                }
            }

            Repeater {
                model: 5
                delegate: LcarsRect {
                    x: 0
                    y: mapArea.my(90 - index * 45)
                    width: mapArea.width
                    height: 1
                    color: Qt.rgba(0.6, 0.6, 0.7, index === 2 ? 0.28 : 0.13)
                }
            }

            // the equator, for reading latitude at a glance
            LcarsRect {
                x: 0
                y: mapArea.my(0)
                width: mapArea.width
                height: 1
                color: Qt.rgba(1.0, 0.61, 0.0, 0.35)
            }

            // ---- the orbit under way ----
            // Sampled from the feed at 2-minute intervals: a dot per sample
            // reads as a dotted curve, which is both what a tracking console
            // draws and cheerfully immune to the antimeridian (a joined path
            // would draw a false line straight across the map on every pass).
            Repeater {
                model: feed.trackPoints
                delegate: LcarsRect {
                    // Already behind us, or still to come.
                    readonly property bool traversed: index <= feed.trackNowIndex
                    x: mapArea.mx(modelData.lon) - width / 2
                    y: mapArea.my(modelData.lat) - height / 2
                    width: LcarsUi.u(6)
                    height: LcarsUi.u(6)
                    radiusTL: width / 2
                    radiusTR: width / 2
                    radiusBR: width / 2
                    radiusBL: width / 2
                    color: traversed ? LcarsUi.violet : LcarsUi.plum
                    opacity: traversed ? 0.85 : 0.9
                }
            }

            // ---- past ground track ----
            Repeater {
                model: win.trail
                delegate: LcarsRect {
                    // A dot per fix rather than a polyline: the track crosses
                    // the antimeridian, and a connected path would draw a false
                    // line straight across the map when it does.
                    readonly property real age: win.trail.length > 1
                        ? index / (win.trail.length - 1) : 1
                    x: mapArea.mx(modelData.lon) - width / 2
                    y: mapArea.my(modelData.lat) - height / 2
                    width: LcarsUi.u(5)
                    height: LcarsUi.u(5)
                    radiusTL: width / 2
                    radiusTR: width / 2
                    radiusBR: width / 2
                    radiusBL: width / 2
                    color: LcarsUi.amber
                    opacity: 0.12 + 0.45 * age
                }
            }

            // ---- live fix ----
            Item {
                id: marker
                visible: !!win.o
                x: win.o ? mapArea.mx(win.o.lon) : 0
                y: win.o ? mapArea.my(win.o.lat) : 0
                width: 0
                height: 0

                // pulse, so the marker is obviously live rather than a stuck dot
                LcarsRect {
                    anchors.centerIn: parent
                    width: LcarsUi.u(30)
                    height: LcarsUi.u(30)
                    radiusTL: width / 2
                    radiusTR: width / 2
                    radiusBR: width / 2
                    radiusBL: width / 2
                    color: "transparent"
                    borderColor: LcarsUi.orange
                    borderWidth: 1
                    opacity: 0.6

                    SequentialAnimation on scale {
                        running: marker.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.6; to: 1.9; duration: 1400; easing.type: Easing.OutQuad }
                        NumberAnimation { from: 1.9; to: 0.6; duration: 0 }
                    }
                    SequentialAnimation on opacity {
                        running: marker.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.7; to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                        NumberAnimation { from: 0.0; to: 0.7; duration: 0 }
                    }
                }

                LcarsRect {
                    anchors.centerIn: parent
                    width: LcarsUi.u(14)
                    height: LcarsUi.u(14)
                    radiusTL: width / 2
                    radiusTR: width / 2
                    radiusBR: width / 2
                    radiusBL: width / 2
                    color: LcarsUi.orange
                }

                // crosshair through the fix
                LcarsRect {
                    x: -LcarsUi.u(40)
                    y: -0.5
                    width: LcarsUi.u(80)
                    height: 1
                    color: Qt.rgba(1.0, 0.61, 0.0, 0.5)
                }
                LcarsRect {
                    x: -0.5
                    y: -LcarsUi.u(30)
                    width: 1
                    height: LcarsUi.u(60)
                    color: Qt.rgba(1.0, 0.61, 0.0, 0.5)
                }
            }

            // axis captions
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.top: parent.top
                anchors.topMargin: 4
                text: "90N"
                color: LcarsUi.grey
                font.family: LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(15)
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: "90S"
                color: LcarsUi.grey
                font.family: LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(15)
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "0"
                color: LcarsUi.grey
                font.family: LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(15)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: "180W"
                color: LcarsUi.grey
                font.family: LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(15)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: "180E"
                color: LcarsUi.grey
                font.family: LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(15)
            }
        }

        // ---- telemetry ----
        Item {
            id: telemetry
            x: LcarsUi.u(64)
            y: mapArea.y + mapArea.height + LcarsUi.u(26)
            width: parent.width - LcarsUi.u(64 + 24)
            height: Math.ceil(win.telemetry.length / 2) * LcarsUi.u(50)

            readonly property real colW: width / 2 - LcarsUi.u(20)
            readonly property real rowH: LcarsUi.u(50)

            Repeater {
                model: win.telemetry
                delegate: Item {
                    x: (index % 2) * (telemetry.colW + LcarsUi.u(40))
                    y: Math.floor(index / 2) * telemetry.rowH
                    width: telemetry.colW
                    height: telemetry.rowH

                    // underscore-leader between caption and value, the way a
                    // console prints a field
                    LcarsRect {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Qt.rgba(0.6, 0.6, 0.7, 0.16)
                    }

                    LcarsLabel {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.c
                        color: LcarsUi.sky
                        size: 20
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.v
                        color: win.ink(modelData.k)
                        font.family: LcarsUi.fontMono
                        font.pixelSize: LcarsUi.u(24)
                    }
                }
            }
        }

        // ---- footer: where this comes from ----
        LcarsStrip {
            anchors.bottom: parent.bottom
            width: parent.width
            height: LcarsUi.u(58)
            color: LcarsUi.plum
            capLeft: true
            round: LcarsUi.u(10)
        }

        LcarsLabel {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: LcarsUi.u(28)
            height: LcarsUi.u(58)
            text: feed.orbit
                ? "SGP4 // ELEMENTS " + feed.orbit.tle.source.toUpperCase()
                    + " // " + win.ago(win.clock - feed.orbit.tle.ageS * 1000) + " OLD"
                : "SGP4 // AWAITING ELEMENTS"
            color: LcarsUi.amber
            size: 19
        }

        LcarsLabel {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: LcarsUi.u(28)
            height: LcarsUi.u(58)
            text: "CELESTRAK TLE \u00B7 DR T.S. KELSO"
            color: LcarsUi.lilac
            size: 19
            horizontalAlignment: Text.AlignRight
        }

        // ---- error line: surfaced, never silently swallowed ----
        LcarsLabel {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: LcarsUi.u(66)
            anchors.left: parent.left
            anchors.leftMargin: LcarsUi.u(28)
            width: parent.width - LcarsUi.u(56)
            height: LcarsUi.u(24)
            text: feed.lastError.length > 0 ? "\u26A0 " + feed.lastError : ""
            color: LcarsUi.red
            size: 17
            caps: false
            fit: true
        }
    }

    // =======================================================================
    // RIGHT - SEISMIC ACTIVITY
    // =======================================================================
    Item {
        id: quakePanel
        x: LcarsUi.u(win.rightX)
        y: LcarsUi.u(win.contentY)
        width: LcarsUi.u(win.rightW)
        height: LcarsUi.u(win.contentH)

        LcarsStrip {
            id: quakeHead
            width: parent.width
            height: LcarsUi.u(56)
            color: LcarsUi.salmon
            capRight: true
            round: LcarsUi.u(12)
        }

        LcarsLabel {
            x: LcarsUi.u(26)
            height: quakeHead.height
            text: "SEISMIC ACTIVITY"
            color: LcarsUi.ink
            size: 28
            tracking: true
        }

        LcarsLabel {
            anchors.right: parent.right
            anchors.rightMargin: LcarsUi.u(30)
            height: quakeHead.height
            width: parent.width * 0.42
            text: feed.quakeCount > 0 ? feed.quakeCount + " / 24H" : "--"
            color: LcarsUi.ink
            size: 24
            horizontalAlignment: Text.AlignRight
        }

        // ---- strongest event ----
        Item {
            id: largest
            y: quakeHead.height + LcarsUi.u(16)
            width: parent.width
            height: LcarsUi.u(84)

            LcarsRect {
                anchors.fill: parent
                color: "#120a0a"
                borderColor: Qt.rgba(0.8, 0.4, 0.4, 0.3)
                borderWidth: 1
                radiusTL: LcarsUi.u(10)
                radiusTR: LcarsUi.u(10)
                radiusBR: LcarsUi.u(10)
                radiusBL: LcarsUi.u(10)
            }

            LcarsLabel {
                x: LcarsUi.u(24)
                height: parent.height
                text: "STRONGEST"
                color: LcarsUi.grey
                size: 19
            }

            Text {
                x: LcarsUi.u(150)
                anchors.verticalCenter: parent.verticalCenter
                text: feed.largestQuake && feed.largestQuake.mag !== null
                    ? "M" + feed.largestQuake.mag.toFixed(1) : "M--"
                color: feed.largestQuake ? win.magColor(feed.largestQuake.mag) : LcarsUi.grey
                font.family: LcarsUi.fontMono
                font.pixelSize: LcarsUi.u(38)
                font.bold: true
            }

            LcarsLabel {
                x: LcarsUi.u(300)
                anchors.right: parent.right
                anchors.rightMargin: LcarsUi.u(24)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - LcarsUi.u(324)
                text: feed.largestQuake ? feed.largestQuake.place : "AWAITING FEED"
                color: LcarsUi.amber
                size: 21
                fit: true
            }
        }

        // ---- the list ----
        Item {
            id: quakeList
            x: LcarsUi.u(0)
            y: largest.y + largest.height + LcarsUi.u(18)
            width: parent.width
            height: quakePanel.height - y - LcarsUi.u(64)

            readonly property real rowH: LcarsUi.u(58)
            readonly property int maxRows: Math.floor(height / rowH)

            Column {
                width: parent.width
                spacing: 0

                Repeater {
                    model: feed.quakeItems.slice(0, quakeList.maxRows)

                    delegate: Item {
                        width: quakeList.width
                        height: quakeList.rowH

                        LcarsRect {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Qt.rgba(0.6, 0.6, 0.7, 0.14)
                        }

                        // magnitude badge
                        LcarsRect {
                            id: badge
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: LcarsUi.u(86)
                            height: LcarsUi.u(40)
                            color: win.magColor(modelData.mag)
                            radiusTL: LcarsUi.u(8)
                            radiusTR: LcarsUi.u(8)
                            radiusBR: LcarsUi.u(8)
                            radiusBL: LcarsUi.u(8)
                        }

                        Text {
                            anchors.centerIn: badge
                            text: modelData.mag !== null ? modelData.mag.toFixed(1) : "--"
                            color: LcarsUi.shade
                            font.family: LcarsUi.fontMono
                            font.pixelSize: LcarsUi.u(24)
                            font.bold: true
                        }

                        LcarsLabel {
                            x: badge.width + LcarsUi.u(18)
                            width: parent.width - badge.width - LcarsUi.u(150)
                            height: parent.height
                            text: modelData.place
                            color: LcarsUi.orange
                            size: 21
                            fit: true
                        }

                        // depth and age, right-aligned as a pair of fixed columns
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: LcarsUi.u(84)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.depthKm !== null
                                ? modelData.depthKm.toFixed(1) + "KM" : "--"
                            color: LcarsUi.ice
                            font.family: LcarsUi.fontMono
                            font.pixelSize: LcarsUi.u(19)
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.ago(modelData.time)
                            color: LcarsUi.grey
                            font.family: LcarsUi.fontMono
                            font.pixelSize: LcarsUi.u(19)
                        }
                    }
                }
            }

            // empty state, kept distinct from "no earthquakes happened"
            LcarsLabel {
                anchors.centerIn: parent
                visible: feed.quakeItems.length === 0
                text: feed.lastLineAt > 0 ? "AWAITING SEISMIC SNAPSHOT" : "NO FEED"
                color: LcarsUi.grey
                size: 22
            }
        }

        LcarsLabel {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: LcarsUi.u(58)
            text: "USGS \u00B7 PUBLIC DOMAIN \u00B7 ALL EVENTS, LAST 24H"
            color: LcarsUi.grey
            size: 17
        }
    }
}
