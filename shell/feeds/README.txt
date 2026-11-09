PARKED - live tracking feed
===========================

Status: built, verified against live data, and parked before it was ever wired
into shell.qml. Nothing in the shell imports any of this. It is inert.

Kept rather than deleted because this folder has no git, so a delete would be
permanent. Delete the three pieces below whenever you are sure:

    feeds/                 the data layer
      README.txt           this file
      TrackingFeed.qml     process -> QML properties (the whole port)
      orbit/
        track.mjs          TLE + SGP4 poller, one JSON line per tick
        package.json       the one dependency (satellite.js)
        node_modules/      installed, ~1 MB, ignore it
    tracking-test.qml      the two-panel harness window


What it does
------------

Two panels fed by real public data, with no simulated number anywhere:

  ORBITAL TRACKING   ISS ground track, position and telemetry, propagated
                     locally by SGP4 from a cached CelesTrak TLE.
  SEISMIC ACTIVITY   USGS events from the last 24 h, newest first.

The idea worth remembering is the split between two clocks. The ISS moves at
7.7 km/s, so anything slower than 1 Hz looks like a stutter - but its orbital
elements are good for days. So the network is barely touched: the TLE is fetched
once, cached to ~/.cache/lcars-orbit/, and every position after that is
arithmetic. Earthquakes are the opposite and are refetched every 60 s.


Running it again
----------------

The poller on its own, which is the fastest way to see the data:

    node feeds/orbit/track.mjs --once     # one orbit + track line, then exit
    node feeds/orbit/track.mjs            # stream until killed

The window (run.sh cannot do this - it hardcodes shell.qml and takes no file
argument):

    qs -p /home/henrysalvador/lcars-dev/tracking-test.qml

Fullscreen is requested through the compositor, as run.sh does, and the first
attempt usually races the window mapping - run it again and it takes:

    addr=$(hyprctl clients -j | python3 -c "..." )   # match the qs cmdline
    hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 'fullscreen', window = 'address:$addr' })"

Or just capture it without showing it:

    ./dev/shot.sh tracking-test.qml dev/shots/tracking.png


Dependencies and other gotchas
------------------------------

satellite.js is the only dependency, installed under feeds/orbit/. No API key is
needed for anything here - CelesTrak (citation requested) and USGS (public
domain) are both keyless. Both credit lines are drawn in the panel footers.

TrackingFeed.qml resolves node through a login shell with a /usr/bin/node
fallback, because this machine's node is a mise install and Quickshell only gets
whatever environment the compositor handed it. If the panels sit at "WAIT",
that resolution is the first thing to check.

track.mjs watches its own mtime and exits, relying on the heartbeat Timer in
TrackingFeed.qml to restart it - the same convention scripts/stats.sh uses under
shell.qml.


If it is ever picked up again
-----------------------------

The layout-independent part is done: TrackingFeed.qml is the whole interface.

    import "feeds"
    TrackingFeed { id: feed }
    LcarsLabel { text: feed.orbit ? feed.orbit.altKm.toFixed(1) + " KM" : "--" }

It never blanks on a failed fetch - it keeps the last good reading and flips a
freshness flag, so a transient network error shows STALE rather than an empty
panel. That behaviour is the part worth keeping if the panels are ever rebuilt.

Unfinished: run.sh takes no file argument (see above), and the ground track is
drawn equirectangular, which is honest at this size but is not a globe.
