#!/usr/bin/env node
// ---------------------------------------------------------------------------
// track.mjs - the poller behind the LCARS tracking panel.
//
// Emits one JSON object per line on stdout, tagged by `kind`, so a Quickshell
// SplitParser can hand them straight to QML:
//
//     {"kind":"orbit",  ...}   every tick (default 1 Hz, no network)
//     {"kind":"quakes", ...}   every 60 s (one HTTP request)
//
// Run it by hand to watch the feed:
//     node feeds/orbit/track.mjs --once        # one orbit line, then exit
//     node feeds/orbit/track.mjs               # stream until killed
//
// WHY IT IS SHAPED THIS WAY
//
// Two different clocks are at work and conflating them wastes bandwidth. The
// ISS moves ~7.7 km/s, so anything slower than ~1 Hz looks like a stutter, but
// its *orbital elements* are good for days. So the network is touched almost
// never: the TLE is fetched once and cached to disk, and every subsequent
// position is computed locally by SGP4. The earthquake feed is the opposite -
// it changes on a human timescale, so it is refetched on a slow timer.
//
// This is the same split the God's Eye View project uses ("disk-cached TLEs
// reduce repeated requests", SGP4 propagated client-side). The difference is
// that this is ~150 lines instead of a 640-file globe.
//
// THE CONTRACT THE QML SIDE RELIES ON
//
//   - A line is never partially written: one JSON object per newline, flushed.
//   - A malformed or failed *fetch* never produces a line at all, so the panel
//     keeps its last good reading instead of blanking. Fields carry their own
//     freshness (`ageS`, `stale`) rather than vanishing.
//   - `ok:false` means "this reading did not update", not "the sky is empty".
// ---------------------------------------------------------------------------

import * as satellite from "satellite.js";
import { mkdirSync, readFileSync, writeFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

// -- tunables ---------------------------------------------------------------
const args = process.argv.slice(2);
const hasFlag = (f) => args.includes(f);
const argOf = (f, dflt) => {
  const i = args.indexOf(f);
  return i >= 0 && args[i + 1] !== undefined ? args[i + 1] : dflt;
};

const TICK_MS = Number(argOf("--interval-ms", 1000));
const QUAKE_MS = Number(argOf("--quake-every-s", 60)) * 1000;
// TLEs go stale over days, not minutes. Refetching more often than every few
// hours is pure waste against a free service.
const TLE_MAX_AGE_MS = Number(argOf("--tle-max-age-h", 6)) * 3600 * 1000;
const ONCE = hasFlag("--once");
// How many quakes to serialize. The view decides what to show; the feed just
// refuses to ship 300 rows at 1 Hz.
const QUAKE_LIMIT = Number(argOf("--quake-limit", 20));

const NORAD_ID = Number(argOf("--norad", 25544)); // ISS (ZARYA)
const TLE_URL = `https://celestrak.org/NORAD/elements/gp.php?CATNR=${NORAD_ID}&FORMAT=TLE`;
const QUAKE_URL =
  "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson";

const CACHE_DIR = join(
  process.env.XDG_CACHE_HOME || join(homedir(), ".cache"),
  "lcars-orbit",
);
const TLE_CACHE = join(CACHE_DIR, `tle-${NORAD_ID}.txt`);

// -- tiny helpers -----------------------------------------------------------
const DEG = 180 / Math.PI;

function emit(obj) {
  // One object, one newline, flushed. The reader is line-oriented and will
  // drop a torn line, so a single write() of the whole record matters.
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function note(msg) {
  // Diagnostics go to stderr so they can never be mistaken for feed data.
  process.stderr.write(`track: ${msg}\n`);
}

function problem(msg) {
  // Same stream, but tagged so the QML side can tell "worth showing" from
  // "routine". Surface only these in the UI.
  process.stderr.write(`track: ERROR ${msg}\n`);
}

async function getText(url, timeoutMs = 15000) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ctl.signal,
      headers: { "user-agent": "lcars-dev-orbit-feed/0.1 (personal project)" },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

// -- orbital elements -------------------------------------------------------
// Kept in memory as a parsed satrec, and on disk as the raw three TLE lines so
// a cold start in a tunnel still has a usable orbit instead of an empty panel.
let satrec = null;
let tleMeta = { name: "", fetchedAt: 0, source: "none", rev: null };

function parseTle(text) {
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trimEnd())
    .filter((l) => l.length > 0);
  // CelesTrak returns: name, line 1, line 2.
  if (lines.length < 3) throw new Error("TLE response too short");
  const [name, l1, l2] = lines;
  if (!l1.startsWith("1 ") || !l2.startsWith("2 "))
    throw new Error("TLE lines not in expected order");
  // The revolution number at epoch lives in columns 64-68 of line 2 and is not
  // exposed on the satrec, so it has to come off the raw text. `null` rather
  // than NaN when a feed leaves the field blank.
  const rev = parseInt(l2.substring(63, 68).trim(), 10);
  return { name: name.trim(), l1, l2, rev: Number.isFinite(rev) ? rev : null };
}

function adoptTle(parsed, source) {
  satrec = satellite.twoline2satrec(parsed.l1, parsed.l2);
  tleMeta = {
    name: parsed.name,
    fetchedAt: Date.now(),
    source,
    rev: parsed.rev,
  };
  note(`TLE loaded from ${source}: ${parsed.name}`);
}

function loadCachedTle() {
  try {
    const text = readFileSync(TLE_CACHE, "utf8");
    const ageMs = Date.now() - statSync(TLE_CACHE).mtimeMs;
    adoptTle(parseTle(text), "cache");
    return ageMs;
  } catch {
    return Infinity;
  }
}

async function refreshTle() {
  const text = await getText(TLE_URL);
  const parsed = parseTle(text);
  try {
    mkdirSync(CACHE_DIR, { recursive: true });
    writeFileSync(TLE_CACHE, `${parsed.name}\n${parsed.l1}\n${parsed.l2}\n`);
  } catch (err) {
    // A read-only cache dir is not fatal - the in-memory satrec is fine.
    note(`could not cache TLE: ${err.message}`);
  }
  adoptTle(parsed, "network");
}

// -- the per-tick payload ---------------------------------------------------
function orbitLine() {
  const now = new Date();
  const base = {
    kind: "orbit",
    t: now.getTime(),
    noradId: NORAD_ID,
    name: tleMeta.name,
    tle: {
      ageS: Math.round((now.getTime() - tleMeta.fetchedAt) / 1000),
      source: tleMeta.source,
    },
  };

  if (!satrec) return { ...base, ok: false, reason: "no-tle" };

  const pv = satellite.propagate(satrec, now);
  if (!pv || !pv.position || typeof pv.position !== "object")
    return { ...base, ok: false, reason: "sgp4-failed" };

  const gmst = satellite.gstime(now);
  const geo = satellite.eciToGeodetic(pv.position, gmst);
  const lat = satellite.degreesLat(geo.latitude);
  const lon = satellite.degreesLong(geo.longitude);

  const v = pv.velocity;
  const speedKmS = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

  return {
    ...base,
    ok: true,
    lat,
    lon,
    altKm: geo.height,
    speedKmh: speedKmS * 3600,
    // Straight off the satrec, so the panel can show something that reads like
    // a real tracking console without any extra math.
    inclinationDeg: satrec.inclo * DEG,
    periodMin: (2 * Math.PI) / satrec.no, // satrec.no is rad/min
    revNumber: tleMeta.rev,
    eccentricity: satrec.ecco,
  };
}

// -- the current orbit's ground track --------------------------------------
// A single fix is a dot; the shape of the pass is what makes a tracking display
// readable. Sampling the *whole* orbit forwards and backwards means the panel
// has a full ground track from the first tick instead of filling in over the
// several minutes it would take to accumulate one from live fixes.
//
// It is emitted rarely (it only changes as the orbit precesses), so the cost is
// one burst of arithmetic every few minutes.
function groundTrackLine() {
  const base = {
    kind: "track",
    t: Date.now(),
    noradId: NORAD_ID,
    name: tleMeta.name,
  };
  if (!satrec) return { ...base, ok: false, reason: "no-tle" };

  const periodMin = (2 * Math.PI) / satrec.no;
  const stepMin = 2;
  const half = Math.floor(periodMin / 2 / stepMin) * stepMin; // one full orbit
  const now = Date.now();
  const points = [];
  let nearest = 0;
  let nearestDelta = Infinity;

  for (let m = -half; m <= half; m += stepMin) {
    const at = new Date(now + m * 60000);
    const pv = satellite.propagate(satrec, at);
    if (!pv || !pv.position || typeof pv.position !== "object") continue;
    const geo = satellite.eciToGeodetic(pv.position, satellite.gstime(at));
    points.push({
      lat: Number(satellite.degreesLat(geo.latitude).toFixed(3)),
      lon: Number(satellite.degreesLong(geo.longitude).toFixed(3)),
      // minutes relative to now: negative is behind, positive ahead
      dMin: m,
    });
    const delta = Math.abs(m);
    if (delta < nearestDelta) {
      nearestDelta = delta;
      nearest = points.length - 1;
    }
  }

  return {
    ...base,
    ok: true,
    periodMin,
    stepMin,
    // The sample index closest to now, so the view can draw the traversed part
    // of the orbit differently from the part still to come.
    nowIndex: nearest,
    points,
  };
}

// -- earthquakes ------------------------------------------------------------
let quakeCache = null;

async function refreshQuakes() {
  const text = await getText(QUAKE_URL);
  const payload = JSON.parse(text);
  const features = Array.isArray(payload.features) ? payload.features : [];

  const rows = features
    .map((f) => {
      const p = f.properties || {};
      const c = (f.geometry && f.geometry.coordinates) || [];
      // Rounded here rather than in the view: it keeps the line short (this
      // ships at 1 Hz) and it is the precision a readout can actually show.
      const round = (v, dp) =>
        typeof v === "number" ? Number(v.toFixed(dp)) : null;
      return {
        id: f.id,
        mag: round(p.mag, 1),
        place: p.place || "UNKNOWN REGION",
        time: p.time || 0,
        // USGS orders coordinates [lon, lat, depthKm]
        lon: round(c[0], 3),
        lat: round(c[1], 3),
        depthKm: round(c[2], 1),
        url: p.url || "",
      };
    })
    // Newest first, then trim. `count` below still reports the true total, so
    // the panel can say "20 OF 312" honestly.
    .sort((a, b) => b.time - a.time);

  quakeCache = {
    kind: "quakes",
    ok: true,
    t: Date.now(),
    count: rows.length,
    items: rows.slice(0, QUAKE_LIMIT),
    largest: rows.reduce(
      (best, r) => (r.mag !== null && (best === null || r.mag > best.mag) ? r : best),
      null,
    ),
  };
}

// -- lifecycle --------------------------------------------------------------
// Quickshell carries a Process across config reloads rather than restarting it,
// so editing this file would otherwise never take effect. Watch our own mtime
// and re-exec, exactly like scripts/stats.sh does.
const SELF = new URL(import.meta.url).pathname;
let selfStamp = 0;
try {
  selfStamp = statSync(SELF).mtimeMs;
} catch {
  /* not fatal: reload-on-save is a convenience, not a requirement */
}
function fileChanged() {
  try {
    return statSync(SELF).mtimeMs !== selfStamp;
  } catch {
    return false;
  }
}

async function main() {
  const cachedAgeMs = loadCachedTle();
  if (cachedAgeMs > TLE_MAX_AGE_MS) {
    try {
      await refreshTle();
    } catch (err) {
      // Worth surfacing: a stale TLE silently degrades every position on
      // screen, so the panel should be able to say the elements are old.
      problem(`TLE fetch failed (${err.message}); using cache if any`);
    }
  }

  if (ONCE) {
    emit(orbitLine());
    emit(groundTrackLine());
    return;
  }

  // First line immediately, so the panel is never empty while the first
  // quake request is still in flight.
  emit(orbitLine());
  emit(groundTrackLine());

  let lastQuakeAt = 0;
  let lastTrackAt = 0;
  const tick = setInterval(() => {
    if (fileChanged()) {
      note("source changed, re-exec");
      process.exit(75); // Quickshell's heartbeat restarts us
    }

    if (Date.now() - lastQuakeAt > QUAKE_MS) {
      lastQuakeAt = Date.now();
      refreshQuakes()
        .then(() => emit(quakeCache))
        .catch((err) => problem(`quake fetch failed: ${err.message}`));
    }

    // The ground track barely moves, so it is only rebuilt when the elements
    // behind it change - not on every tick.
    if (Date.now() - lastTrackAt > TLE_MAX_AGE_MS) {
      lastTrackAt = Date.now();
      emit(groundTrackLine());
    }

    // Keep the orbit fresh from the cache when the TLE is getting old.
    if (Date.now() - tleMeta.fetchedAt > TLE_MAX_AGE_MS)
      refreshTle().catch((err) => problem(`TLE refresh failed: ${err.message}`));

    emit(orbitLine());
  }, TICK_MS);

  const bye = () => {
    clearInterval(tick);
    process.exit(0);
  };
  process.on("SIGTERM", bye);
  process.on("SIGINT", bye);
}

main().catch((err) => {
  problem(`fatal: ${err.message}`);
  process.exit(1);
});
