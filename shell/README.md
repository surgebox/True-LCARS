# lcars-dev

Working folder for the LCARS desktop shell. **Layout study 39** - not a shell
yet, on purpose.

```
./run.sh                 windowed, hot-reloads on save
./run.sh --desktop       managed LCARS desktop with app windows
./run.sh --fullscreen    fullscreen; Ctrl+C quits
./dev/shot.sh            capture shell.qml        -> dev/shots/latest.png
./dev/shot.sh demo/elbow.qml dev/shots/elbows.png
./dev/check.sh           qmllint, without opening a window
```

`dev/shot.sh` **reuses a running layout window** if there is one - it does not
launch a second instance, which would knock the running window out of
fullscreen and fight it for the screen. `LCARS_SHOT_NEW=1` forces a throwaway
one. It fullscreens through the compositor (so the capture is the layout 1:1
rather than a tiled slice), grabs only that window's rect with `grim`, and only
kills an instance it started itself.

Note it captures whatever workspace is *visible*: if the layout is fullscreen on
another workspace, grim will happily hand you that workspace instead. Switch to
the layout's workspace first, or read `dev/shots/latest.png` from a run you
watched happen.

`dev/check.sh` is the fast loop - this Qt fails the *entire* config on things
qmllint can see, so it is worth running before a capture.

## System file browser (alternative version)

Click **SYSTEM** to open the embedded file viewer. Selecting a directory adds
another column, preserving the visible parent chain; deep paths scroll
horizontally. The columns and preview resize as the chain grows, and the whole
view slides in from the right. File rows, the filter, and preview actions use
large touch targets. Selecting a file shows its preview at the right. Navigation stays
in memory when switching rail buttons. LCARS chrome surrounds readable filenames
and document text. The column/preview arrangement is inspired by
[Strata](https://github.com/lgse/strata); this implementation is independent.

The header title displays the current mode in both condensed and expanded
states; condensed CPU/MEM/NET/DSK pills sit against the right margin. Selecting
System replaces the side rail with large Back, Forward, Up, Home, Root, Refresh,
Hidden, and Main controls. Unavailable actions dim, Hidden shows its toggle state,
and Main returns to the default rail.
Press COMMAND or LCARS to return to the default mode menu. The browser's path
field lives in the System toolbar; Ctrl+L focuses it.
There is no separate file-viewer title bar or navigation toolbar.

The name filter matches names in the displayed columns. The viewer reads files;
opening in the default application is an
explicit button, double-click, or Enter on a file. It has no file-editing actions.

| Key | Action |
| --- | --- |
| Up / Down | Select and preview an entry |
| Right / Left | Enter a folder / focus the parent column |
| Enter | Enter a folder or open a file externally |
| Ctrl+L | Edit location (absolute paths and `~` supported) |
| Alt+Up | Parent directory |
| Alt+Left / Alt+Right | Navigation history |
| Ctrl+H | Toggle hidden entries |
| F5 | Refresh directory contents and selected preview |

Previews include images, selectable text/source, rendered Markdown, paginated
PDFs, and audio/video with explicit playback and seeking. Text is limited to
64 KiB, PDF previews to 100 MiB, and directory columns to 10,000 entries; the UI
reports truncation. Unsupported formats retain metadata and an external-open
button. PDFs require Poppler's `pdftoppm` and `pdfinfo`; video thumbnails and
media metadata use `ffmpeg`/`ffprobe`. Playback uses Qt Multimedia and supported
codecs. Python 3 provides the asynchronous read-only service, with previews in
a temporary cache cleaned on service exit. Refresh is manual (F5).

Run the backend checks with `python3 dev/test-files.py`, and the column keyboard
checks with `/usr/lib/qt6/bin/qmltestrunner -input dev/tst-file-column.qml`
(`QT_QPA_PLATFORM=offscreen` works for a headless run).

## Touch keyboard study

Run `qs -p keyboard-preview.qml` to inspect the keyboard by itself. The component
includes letter and symbol layouts, one-shot Shift, cursor controls, Backspace,
and Enter. `ui/LcarsKeyboard.qml` accepts a `target` TextInput or TextField and
a `targetLabel` for the field name shown in its elbow; it emits `enterPressed`
for the host to handle.

In `shell.qml`, tap the chevron centered on the bottom LCARS bar or the bottom
KEYBOARD elbow to show every key. Once open, three bars replace the chevron as
the drag handle. Drag it upward to lift the panel toward your hands, downward to
peek behind it, and farther down to close it. Tapping either control closes it. The bottom elbow
and horizontal band stay anchored at the screen edge while the wider keyboard
tray extends upward from them. At its highest position, the free space below
the keys is one key row plus its gap. Its two elbows use the band's current color.
As the tray rises, the expanded top zone folds into its compact layout to keep
at least 400 design units of application space. Raising it farther first
shrinks the yellow Hello bar, then slides that bar offscreen. Lowering the tray
restores the previous top-zone preference.
Focusing the directory path, file filter, or network password opens the keyboard with that field named
in the elbow. The file area contracts and the network console moves and scales
into the space above the keyboard as it moves.

Run its interaction checks with
`QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input dev/tst-keyboard.qml`.
The dock gesture checks are in `dev/tst-keyboard-dock.qml` and use the same command.

## Notifications

The black bell in the top-left yellow cap opens the LCARS notification panel.
The cap straightens into a yellow column that reaches the screen bottom, and
the menu reveals downward from its lower edge. The title and DND status sit on
that column. The status is a green ACTIVE or red SILENCED switch with a moving
thumb. The panel follows the top bar if that bar moves.
Quickshell's `NotificationServer` receives desktop notifications directly;
Live and Recent tabs, individual dismiss controls, Clear All, and Do Not
Disturb work without Omarchy. Recent notifications and the DND setting are
stored in `$XDG_STATE_HOME/lcars/notifications.json` (or
`~/.local/state/lcars/notifications.json`). The panel keeps the newest 30
recent entries. The standalone shell must be the active desktop notification
service; stop another notification daemon before installing it as the shell.

## What is here

```
shell.qml              windowed layout preview
desktop.qml            layer-shell desktop with a transparent app area
ShellContent.qml       shared LCARS layout and geometry
scripts/app_layout.py  fits live Hyprland windows into the app area
demo/                  one runnable file per component - see demo/README.md
  rect.qml  label.qml  strip.qml  capsule.qml  textbar.qml  elbow.qml
tracking-test.qml      live orbital + seismic panels over a real feed (harness)
theme/
  qmldir               declares the singleton
  LcarsUi.qml          palette + type + the global scale
ui/
  LcarsRect.qml        rect with four independent corner radii (+ outline)
  LcarsElbow.qml       the L / elbow shape
  LcarsStrip.qml       horizontal bar, optionally half-round on either end
  LcarsLabel.qml       Text pre-set with the LCARS face, sized in design units
  LcarsCapsule.qml     the CPU / MEM / NET / DSK readout pill
  LcarsButton.qml      the big button bar (currently unused - the footer is gone)
  LcarsReadout.qml     the amber numeric cascade
  LcarsTextBar.qml     the "HELLO <NAME>" strip (ported from Project-Eve)
  LcarsKeyboard.qml    touch keyboard with text-field target
  LcarsKeyboardDock.qml keyboard position controlled by the bottom-band chevron
  LcarsVolumeBar.qml   the draggable vertical level meter (open panel)
  LcarsVolumeBarH.qml  the block-that-opens horizontal meter (collapsed panel)
  LcarsSpeaker.qml     a drawn volume glyph (PARKED - the font glyphs won)
  LcarsIconButton.qml  small glyph button, click vs press-and-hold
  LcarsDeviceMenu.qml  the audio output picker (PARKED - not wired up)
feeds/
  TrackingFeed.qml     live tracking data as QML properties (the whole port)
  orbit/
    track.mjs          TLE + SGP4 poller; one JSON line per tick
scripts/
  stats.sh             one line of stats per second for the capsules
  audio.sh             volume / mute / output-device backend
dev/
  shot.sh              screenshot harness
  check.sh             lint harness
  shots/               captures
```

## The demo gallery

`demo/` holds one runnable window per component. A `ui/` file is a definition,
not a program - it has no size or background, so running it alone gives an empty
window. A demo is the wrapper that makes a component into something you can look
at:

    qs -p demo/rect.qml

Change `ui/LcarsRect.qml`, re-run that, and you see that radius and nothing else.
`demo/README.md` explains the pattern and the two symlinks the folder needs.

## The sizing model

The layout is authored in **design units for a 2048x1152 canvas**. `LcarsUi.scale`
is `height / 1152` and is republished by `shell.qml` into the singleton, so
every component writes `LcarsUi.u(46)` and gets the right pixel size on any
resolution.

Vertically everything keeps its design size. Horizontally, blocks are **anchored
to the window edges** rather than pinned to a design x, so a wider or narrower
screen stretches the bars instead of clipping them.

## The elbow

The piece the whole language is built on. Authored once in the top-left
orientation - a convex `outerRadius` at the screen corner and a concave
`innerRadius` shoulder where the arms meet - then mirrored per point for the
other three corners. Mirroring inverts arc sweep, so the sweep flags flip with
it; one code path generates all four orientations and no item transform is
involved.

```
barThickness        how tall the horizontal arm is
columnThickness     how wide the vertical arm is
outerRadius         the convex screen-edge corner
innerRadius         the concave shoulder
corner              topLeft | topRight | bottomLeft | bottomRight
```

Used twice, both as the root of a band: `topLeft` for `COMMAND`, `bottomLeft`
for the `LCARS` corner. `demo/elbow.qml` proves all four orientations.

## Region map

```
CHROME  hello bar   "HELLO <NAME>", edge to edge across the very top     (56 tall)
CHROME  header      DATE elbow, readout, ACCESS title, CPU/MEM/NET/DSK (220 tall)
CHROME  top band    strip band off the COMMAND elbow                    (38 thick)
CHROME  rail        six bars, elbow down to the bottom band
CHROME  bottom band strip band off the bottom-left elbow                (16 thick)
APP                 the black field between the top band and the bottom band's bar
```

The stack above the panel is three numbers:

```
helloY:  10    // hello bar top
helloH:  56    // its height
headTop: 76    // = helloY + helloH + gap
headH:  220    // header box height
bandTop: 298   // = headTop + dateElbowTop + dateElbowH + dateArmGap
```

## The CPU / MEM / NET / DSK capsules

A 2x2 grid of equal cells (`capsuleW` derives from `clusterW`, so both columns
are the same width by construction rather than by two numbers agreeing), 38
tall. They show real numbers, fed by `scripts/stats.sh`.

**MEM and DSK are buttons.** Clicking one flips it between its two readings -
MEM between `7GB/15GB` and `47%`, DSK between `49GB/86GB` and `57%` - via
`memShowPercent` / `dskShowPercent`. The capsule value uses `Text.HorizontalFit`
in a fixed share of the pill, so a long value shrinks rather than running under
the caption.

Run the poller by hand to see what the shell sees:

```
./scripts/stats.sh
cpu%  memUsedKB  memTotalKB  netname  netKB/s  dskUsedKB  dskTotalKB  vol%  mute
```

Sizes arrive as raw KiB and the shell picks the units, so `44GB/256GB` is a
formatting decision that lives in QML (`gb()` / `pair()`), not in bash.

It prints one line per second and the shell reads that stdout through a
Quickshell `SplitParser`. Polling inside one long-lived `bash` loop rather than
spawning a `Process` per tick keeps it to a single child instead of a fork every
second.

Sources: `/proc/stat` deltas for CPU (idle + iowait counted as not-busy),
`MemTotal - MemAvailable` for memory, the **default-route interface** from
`ip route` for both the network's name and its rate, and `df -Pk /` for disk.

`netname` is the **wifi SSID** when the default route is wireless - that is the
network you are actually on, and "5g-net" means something to a person where
"wlan0" does not. Anything else keeps its interface name. Spaces in an SSID
become underscores so the line stays space-separated.

The parse is total - a short or malformed line leaves the last good values on
screen rather than blanking the capsules - and the first line is always 0 for
CPU and NET, since both need a previous sample to diff against.

The capsule ink is `LcarsUi.shade`, not LCARS orange. Orange on violet and pink
looks right in a mockup and is genuinely hard to read in use; the dark ink
matches the rail bars.

Watch the mount: DSK reports `/`, which on this machine is an 86 GB LVM volume
on a 238 GB NVMe, not the whole drive.

## The volume widget

Lives in the gutter between the DATE column and the numeric readout, and the
readout is pushed right (`readoutX`) to make room. It is chrome, so it sits on
top of whatever the app field renders.

**The meter** (`LcarsVolumeBar`) is a stack of 16 **square** boxes - no
rounding, which reads older and closer to the reference - green at the bottom
climbing through yellow to red at the top, so loud reads red the way a VU meter
does. A box is lit when the level reaches it; the rest stay a dim tint of their
own hue, so the whole scale stays visible and it reads as a gauge rather than a
bar chart. Dragging sets the level absolutely and reports it live, but only
pushes to the audio server on **release** - otherwise a drag would fork a
`pactl` process per pixel. `shownLevel` follows your finger while dragging and
the poller's value the rest of the time.

**The button** (`LcarsIconButton`) carries a speaker glyph from Font Awesome,
not the LCARS face - so it takes its own `iconFont`. A click toggles mute.

The wave count follows the level, the same way the colour does:

```
0%          \uf026   speaker, no waves
1 - 49%     \uf027   speaker, one wave
50 - 100%   \uf028   speaker, two waves
muted       the block turns red and the glyph is cut through
```

Three bands is what Font Awesome offers - it ships exactly those three speakers,
and Material Symbols the same three under different names - so 1 wave covers
everything under half and 2 covers everything above it.

`LcarsSpeaker.qml` is a **drawn** alternative (0-4 waves, arcs as numbers rather
than glyphs) that was built and then not kept. It is still in `ui/`, and
`LcarsIconButton` still has the `Component icon` slot that would render it.

The glyph is a **speaker with sound waves** (`fa-volume-high`), not headphones.

It has no button until there is something to say. Idle it is just that glyph
sitting on the black, **coloured by the meter's own current level** - green low,
through yellow, red at max - so it reads as the head of the gauge rather than a
separate control. `LcarsVolumeBar` exposes `litCount` and `levelColor` (the
colour of the topmost lit box) precisely so the icon asks the meter instead of
reimplementing the ramp and drifting from it.

With nothing lit there is no "topmost box" to quote, so it goes **dormant grey**
rather than the bottom of the ramp. The bottom of the ramp is green, and a green
speaker at zero volume reads as "quiet" when it should read as "off". `active` (muted) brings up a red block behind it and cuts
the glyph through with a bar - so the control only asserts itself when the state
is not the default one. The cut is drawn as a rotated rectangle rather than
swapped for a muted glyph, so it reads as crossed out whatever the icon happens
to be - and it is sized off `glyphSize` rather than the button, so it still spans
the whole glyph if the icon changes width.

**Mute does not zero the volume.** `status` keeps reporting the stored level and
the *widget* draws at zero. Zeroing would mean unmuting gives you silence, which
is not what anyone wants from a mute button.

### The horizontal one (collapsed panel only)

The flat panel has no room for a 120-tall vertical meter, so it gets
`LcarsVolumeBarH`: to the right of the speaker, a **block whose colour is the
reading**, cut into `idleBoxes` segments so it reads as a row of boxes rather
than one solid slab. It is 4 rather than the meter's 12 on purpose - at 46 wide,
12 segments would leave more gap than box and it would read as a comb. The four
segments carry a slight lightness ramp across them (0.84x to 1.16x), so it reads
as four boxes rather than one flat slab with holes in it. Idle and open
cross-fade over 150ms rather than swapping, so the block dissolves into the meter
as the width animates. Click it and it opens into a horizontal meter you can drag - the
same ramp as the vertical one (green at the quiet end, red at the loud), on its
side. It folds back to the block after `idleMs` (5s) of no interaction, and any
touch restarts that timer.

Two things worth knowing about how it is wired:

- **It owns its own open state and its own width.** It exposes `designWidth`,
  which is what the stat row is placed off - so the buttons ride along as it
  opens rather than being overlapped by it. Width animates 46 -> 200.
- **A click opens it; it does not also set the volume.** If the first press
  reported a level, the volume would jump to wherever the cursor happened to
  land, which is not what clicking a small block should do. Only a press while
  already open reports a level, and only the release pushes to the audio server.

Its colour comes from the same `levelColor` idea as the vertical meter: the
colour of the highest lit box, or `LcarsUi.grey` when nothing is lit - so a
muted or zero reading reads as *off* rather than as quiet.

### Parked: the output picker

`LcarsIconButton` still knows how to press-and-hold and still emits `held()`,
and `ui/LcarsDeviceMenu.qml` and `audio.sh sinks|default` are both still here
and working. What is gone is the wiring: the popup, its full-screen dismiss
catcher, the sink-fetch process and the `sinks` model. Re-hooking it is that
plumbing plus an `onHeld` - kept rather than deleted so the option stays open.

`scripts/audio.sh` is the backend. It uses `pactl`, whose output is far easier
to parse than `wpctl`'s ASCII trees, except for the volume read in `stats.sh`
where one `wpctl get-volume` yields both the level and the mute flag in a single
call. Output descriptions share a long boilerplate prefix, so the script strips
the longest common prefix and the menu shows `HDMI / DisplayPort 2 Output`
rather than the whole device string.

```
./scripts/audio.sh status | set <0-150> | toggle-mute | sinks | default <index>
```

## The stardate, and the date

The DATE cap carries a stardate instead of the old `LCARS 40274` filler, and the
readout under it shows the real calendar date (`2026.09.19`).

```
stardate = (msSinceEpoch / 86400000) / 365.25 * 1000
```

1000 stardates per year, anchored so 1970-01-01 is 0. That lands the present day
in the familiar five-digit TNG band (`56715.3`). It is **decorative** - there is
no canon mapping from the 21st century onto TNG stardates, which were invented
per-episode - but it is deterministic, monotonic, and advances at the rate the
shows used.

The timer only wakes every 10 seconds, since at that rate the displayed tenths
digit moves about every nine hours.

## The column as a function selector

Every column block is a button. Picking one does two things:

1. **Recolours both arms, end to end** - the COMMAND elbow and every segment of
   the band it feeds, and the LCARS elbow at the bottom and every segment of its
   band - to that block's colour. Every band segment goes through
   `themed(defaultColor)`, so with nothing picked each keeps its own colour and
   the resting state is unchanged. Active, each arm reads as one solid bar in
   the function's colour.
2. **Names the function in the COMMAND block**, whose second line switches from
   the `67187585` filler to the active function's name.

The active block is marked with a `>` triangle off its left edge rather than
being recoloured - its own colour is the thing the arms are matching, so it has
to stay itself. Blocks lift slightly on hover. Clicking the active block again
clears the selection.

Every block is set the same way - right-aligned to the same pad, at the same
size - so the column reads as one list rather than six labels that happen to be
stacked. `COMMAND` and `LCARS` are elbow captions rather than column blocks and
keep their own left alignment.

The blocks are labelled with what they do. `fn` is the id of the view, `fnName`
is the longer form printed in the COMMAND block once that function is active:

| block | `fn` | `fnName` |
|---|---|---|
| SYSTEM | `system` | SYSTEM STATS |
| ARCHIVE | `archive` | FILE ARCHIVE |
| NETWORK | `network` | NETWORK |
| LAUNCH | `launch` | APP LAUNCHER |
| COMMS | `comms` | COMMS |
| MAIN | `home` | MAIN DISPLAY |

**Next session:** the `fn` ids are the hooks. `selectFn(fn, acc)` is where a
view would be summoned, and the app field is the surface it would open into.

## Collapse / expand

The panel between the hello bar and the top band starts **collapsed** and opens
on demand. Everything is driven by one number:

```
expand: 0   collapsed (default)
expand: 1   the full panel
```

`requestedExpand` is assigned imperatively by the chevron and carries a `Behavior`
(`600ms`, `InOutQuad`). The panel travels 134 units vertically, so it wants
longer than a hover transition to read as one deliberate movement. Every moving piece is a `lerp` on it, and because the
layout metrics themselves descend from `dateElbowH` - which is in turn a lerp -
animating this single property walks the whole panel open. The top band, the
rail (`railTop`, `railSpan`) and the app field (`appY`) all follow without
knowing the feature exists. The visible `expand` value follows the requested
amount until raising the keyboard limits it to preserve the minimum app height.

### What you get in each state

```
                    collapsed                open
headH               100                      234
bandTop             178                      312
app field           226 .. 1116 (890 tall)   360 .. 1116 (756 tall)
rail span           734                      600
```

**Collapsed** shows only: the Earth date, the speaker, and the four buttons in
one horizontal row. The meter, the numeric cascade, the stardate and the
`LCARS ACCESS 441` title are faded out - they are `opacity: expand`. **Open** is
the panel as it was, with the buttons gathering back into the 2x2 grid:
`capX(i)` / `capY(i)` interpolate each one between the flat row and the grid.

### Three things that made the flat state short

Every one of these is height the collapsed panel does not have to carry, and
each one buys height back for the app field, the COMMAND segment and the rail:

1. **The `DATE` label and the stardate fold away**, both with `height: N * expand`
   rather than just fading. The date underneath rides up instead of leaving a gap
   where the hidden lines were.
2. **`dateCapH` collapses with them** - 96 open, **38 flat**, which is exactly the
   height of the stat buttons. Flat, the cap and the button row are the same
   band of the screen: same top edge, same bottom edge.
3. **The buttons keep one size.** `capW` used to interpolate between a wide flat
   cell and a narrow grid cell; a stretching cell meant the flat row had to be
   tall enough to hold the stretched shape. It is now `capsuleW` in both states
   and only the *positions* animate.
4. **The elbow column flattens to 44.** Flat, it is barely more than the shoulder
   between the cap and the arm - but the arm has to stay, because that is what
   the chevron rides on.

The Earth date was promoted to the bigger of the two (size 24, up from 14) in
both states, since it is the one that survives the fold. The stardate is set
`Font.Light` in `LcarsUi.plum` - Antonio ships Thin through Bold, so weight is a
real axis here, and it makes the two lines read as different kinds of readout
rather than two rows of the same one. `LcarsLabel` gained a `weight` input for
it.

The meter fades on `expand²` rather than `expand`, so it is mostly gone before
the speaker rises through the space it occupied. At `expand = 0.5` a linear fade
left the speaker sitting on top of a half-visible meter.

### The gap across the date column

A black strip the height of `railGap` - the same gap the column buttons use -
cuts across the DATE column about halfway down, below the date itself:

```
dateStripY = dateElbowTop + (dateElbowH - dateArmThick) / 2 - dateStripH / 2
```

It is `opacity: expand`, so it only exists when the panel is open; collapsed the
column is too short for the gap to read as anything but a seam. It is drawn
*over* the elbow and the cap so it cuts a hole rather than laying a bar on top.

### The chevron

It sits on the **arm of the DATE elbow**, centred on the screen, on a fully
transparent button - all you see is the glyph. It rides the arm as the panel
animates, because its `y` is measured off the elbow rather than fixed:

```
y = dateElbowTop + dateElbowH - dateArmThick/2 - chevH/2
```

It points the way the panel will move (`fa-chevron-down` collapsed,
`fa-chevron-up` open).

## The DATE elbow

The date cap and the DATE elbow are **one continuous column**. There is no box
between them: the elbow starts where the cap ends and the cap's rounded
top-left is the head of the whole shape, with the `TZ 67199` readout sitting
straight on it.

The column turns into an **upside-down elbow** - `corner: "bottomLeft"` - so its
thin arm (24) runs right across the **full width**, with the outer corner
rounded at the bottom-left and the concave shoulder above it. It is parallel to
the top band and sits one gap of trailing black above it, so the two read as two
separate bars rather than one thick one.

```
dateCapH:     72
dateElbowTop: 82    // = m + dateCapH - 2   (see the overlap note below)
dateElbowH:   128
dateArmThick: 24
dateArmGap:   12    // black between this arm and the COMMAND arm
```

`bandTop` is anchored off the **DATE arm**, not off the header's box:

```
bandTop = headTop + dateElbowTop + dateElbowH + dateArmGap
```

That means `dateArmGap` is the single number that sets how far apart the two
horizontal bars sit, and closing it up lifts the COMMAND elbow and its arm
together - which is what you want, since they are one shape. It is currently 12,
down from 20 and 38 before that.

## The hello bar

Ported from `~/Project-Eve/shell/LcarsTextBar.qml`:

```
[cap]  gap  [ FLOATING TITLE ]  gap  [ long bar ]  gap  [cap]
```

Both end caps share the accent colour and are **rounded on their outer face
only**; they are wider than they are tall, so they read as a pill segment rather
than a half-circle. `LcarsRect`'s per-corner radii give that directly -
Project-Eve needed a second rectangle per cap to square off the inner face,
which is no longer necessary here.

The title floats straight on the backdrop with no box behind it. Its type size
is **solved, not set**: the font's real ink box is measured with `TextMetrics`
at a reference 100px, and the size whose ink height equals `barHeight * textFill`
is derived from it, with the baseline parked so the capitals sit with equal
padding above and below. That is what makes the text as tall as the strip, and
it survives a font change. `textFill` is the only knob.

Colours are Project-Eve's own pair, kept in the theme as `LcarsUi.yellow`
(the bar) and `LcarsUi.honey` (the title ink, a touch lighter so the floating
title reads against it).

### The power button

The right cap is the power button. `LcarsTextBar` gained a `powerButton` flag
and a `powerClicked()` signal; the cap gets an `LcarsIconButton` over it with
`\uf011` (Font Awesome's power glyph) in `LcarsUi.shade`, which reads as dark
ink on the cap's yellow.

The whole cap is the hit area rather than just the glyph - an 80x56 pad with a
24px icon in it is a much easier target than the icon alone. The button draws no
background of its own, so the cap shows through untouched.

**Nothing is wired to it yet.** `shell.qml` logs the press and nothing more,
deliberately: shutdown, reboot and logout are the next session's work, and none
of them should be reachable from a button until the menu behind it exists. The
hook is `onPowerClicked`.

The name comes from the same lookup chain: `git user.name`, then the passwd
GECOS field, then the raw username - so a `firstlast` username still renders as
"HELLO HENRY". It arrives asynchronously from a `Quickshell.Io` `Process`, so
the bar renders "HELLO THERE" for the first frame.

## The two arms

Both arms are the same object mirrored about the screen's midline, and now they
are built that way rather than by two separate lists of segments:

```
elbowArmLen: 440     how far each elbow's arm runs before the segments start
bandGap:      4      the thin dividers between segments (half of railGap)
armColors:    gold, peach, violet, mauve
```

Four **equal** segments on each, with the same colours in the same order, so the
segment boundaries line up vertically between the top and bottom arm. A vertical
flip preserves left-to-right order, so "a flipped image of each other" and "same
order" are the same thing here - the flip is the elbows (topLeft against
bottomLeft), not the sequence.

`bandSegStart` and `bandSegW` are derived from the window's width, so the four
segments share out whatever space is left after the elbow and stay equal on any
resolution. Every segment goes through `themed()`, so selecting a function still
paints the whole arm in one colour.

### The arm's step

The three middle segments are half the thickness of the ends, and **top-aligned
with them** - all four share one top edge, and only the depth changes:

```
COMMAND elbow arm   48 thick   ┐
segments 1-3        19 thick   ├ all flush at the top
segment 4           48 thick   ┘
```

The elbow and the last segment are untouched; only the middle three were cut. So
the band's underside steps in and out while its top edge stays one line.

An earlier pass also dropped the thin run by 14.5 units to centre it, which
opened black above the segments but broke the top edge; that was reverted. If
the inset is ever wanted it is a `y` on the three thin strips - `(elbowArm -
bandThick) / 2` - not a separate metric.

**Note:** `appY` is measured off `elbowArm`, not `bandThick`. The band's real
bottom edge is set by the two thick pieces, so deriving the app field from the
thin run's thickness would let it overlap them.

## The two bands

Both bands are the same object: an `LcarsElbow` whose arm *is* segment one, with
the remaining segments abutting it and the last one pinned to the right edge.
The elbow's column is what the rail hangs off (top) and what carries the `LCARS`
caption (bottom).

The elbow's own arm is `elbowArm` (48) and the band continuing from it is
`bandThick` (38) - a notch thinner - and both are **top-aligned**, so the top
edge stays one continuous horizon and the arm keeps a small lip underneath.

Rebalancing a band means editing its segment list: segment one is
`LcarsElbow.width`, every segment after it starts at the previous one's
`x + width`, and the last one fills to the right edge.

Thicknesses: top band 38 off a 48 arm, DATE arm 24, bottom band 16. Each is one
number, and the elbow's own `outerRadius` clamps itself to the bar thickness, so
a thin bar gets a half-round end automatically without being told.

## The rail

The rail is **normalised, not hand-placed**. `railBlocks` gives each bar a
*relative* height (and its colour, text, text size and padding); `railLayout`
scales those weights to exactly fill the space between the elbow and the bottom
band, gaps included. So the column is always filled bar-to-bar, and changing a
block means changing its weight - never a cascade of y offsets.

```
railSpan = bottomBandTop - railGap - railTop
```

`railGap` (8) is the black between the stacked bars.

## The tracking feed (PARKED)

**Parked, not deleted.** The panels work and were verified against live data,
but this is not going into the shell for now. Nothing in `shell.qml` imports it,
so it is inert - `feeds/`, `feeds/orbit/` and `tracking-test.qml` cost the shell
nothing by sitting there. The section below is kept as the record of how it
works; `feeds/README.txt` has the commands to bring it back up.

`tracking-test.qml` is a **harness, not a layout study** - it does not touch
`shell.qml`. It proves out a live data layer for the shell:

```
./dev/shot.sh tracking-test.qml dev/shots/tracking.png
```

Two panels, both fed by real public data - there is no simulated number
anywhere in either file:

- **ORBITAL TRACKING** - ISS ground track, position and telemetry, propagated
  locally by SGP4 from a cached CelesTrak TLE.
- **SEISMIC ACTIVITY** - USGS events from the last 24 h, newest first.

The interesting part is the split between the two clocks. The ISS moves at
7.7 km/s, so anything slower than 1 Hz looks like a stutter - but its *orbital
elements* are good for days. So the network is touched almost never: the TLE is
fetched once, cached to `~/.cache/lcars-orbit/`, and every position after that
is arithmetic. The earthquake feed is the opposite and is refetched on a slow
timer. Conflating the two would mean either a stuttering marker or an HTTP
request per second.

`feeds/orbit/track.mjs` is the poller, in the same shape as `stats.sh`: one
long-lived process, one JSON object per line, `stderr` for diagnostics. Lines
are tagged by `kind`:

```
{"kind":"orbit",  ...}   every tick (1 Hz, no network)
{"kind":"track",  ...}   the whole orbit's ground track, rarely
{"kind":"quakes", ...}   every 60 s
```

`feeds/TrackingFeed.qml` owns the process and turns those lines into QML
properties. Nothing else needs to know that CelesTrak or SGP4 were involved:

```qml
TrackingFeed { id: feed }
LcarsLabel { text: feed.orbit ? feed.orbit.altKm.toFixed(1) + " KM" : "--" }
```

Three rules it keeps, all of them about not lying to the operator:

- **It never blanks.** A failed fetch or an unparseable line leaves the last
  good reading on screen and only flips a freshness flag. A panel that empties
  on a transient network error looks broken; one that says `STALE` does not.
- **A tick is one whole line.** The reader is line-oriented and drops a torn
  line rather than half-applying it.
- **Errors are tagged, notes are not.** `track.mjs` writes routine notes and
  real problems to the same stream but only prefixes the latter with `ERROR`,
  so `TLE loaded from cache` never sits on screen looking like a fault.

The ground track is drawn as **dots rather than a joined path**. The ISS
crosses the antimeridian once per orbit, and a polyline would draw a false
straight line across the map every time it did. Traversed samples are violet,
samples still to come are plum (`trackNowIndex` says which is which).

Running the poller by hand is the fastest way to see the data:

```
node feeds/orbit/track.mjs --once      # one orbit + track line, then exit
node feeds/orbit/track.mjs             # stream until killed
```

`satellite.js` is the only dependency, installed under `feeds/orbit/`.

## Where this goes next

**Refine desktop window handling.** `desktop.qml` uses a transparent app field
in one top-layer `PanelWindow`; `scripts/app_layout.py` tiles the visible
workspace's windows in the field. The controller currently makes managed
windows floating while active and restores their prior layout on exit. Test
applications with minimum window sizes and multi-monitor setups before relying
on this as a daily driver.

**Then components.** `ShellContent.qml` is deliberately one file so geometry stays easy
to iterate on. Once the layout stops moving, the CHROME regions lift straight
out with their metrics as properties, and the band segments become a
model-driven `LcarsBand`.

**Then the app area.** External windows now render through the transparent
field in desktop mode; built-in System and Network pages still render in QML.

## Gotchas this Qt will bite you with

- **A config reload is not guaranteed.** Most edits hot-reload, but occasionally
  one is missed and the window keeps rendering the old code - which looks
  exactly like a broken binding. If something you just changed has no effect,
  restart the shell before debugging it. Twice here a working binding was
  "debugged" for several rounds before a restart proved it had been correct all
  along.
- **Fullscreen does not survive a reload.** The window is reconstruicted and
  comes back tiled, often to a third of the screen. `run.sh --fullscreen`
  re-applies it; `hl.dsp.window.fullscreen({ mode = 'fullscreen', window =
  'address:0x...' })` does it by hand.

- **`Cannot override FINAL property`** and the whole config fails to load. It
  fires when a delegate re-declares a property that `Item` or `Repeater`
  already injects: `index`, `modelData`, and - less obviously - `left` and
  `right` on `Item`. `shell.qml` works around it with `isRight`, `lhs` and
  `topSide`. qmllint's suggestion to *add* `required property int index` is
  exactly what triggers it here.
- **`height` inside a positioned child is the child's own height**, not the
  parent's. `y: height - u(32)` silently evaluates to 0. Measure against the
  container by id.
- **Hot reload reconstruits the window**, which drops compositor fullscreen and
  leaves a gap where grim can catch whatever is behind it. `dev/shot.sh` settles
  before grabbing for this reason.
- Editing *anything* under the config directory triggers a reload - including
  `dev/shot.sh` itself.
- **A property declared inside an item is not reachable as `win.<name>`.** Only
  the window's *own* properties are. Worse, a bad reference in a binding fails
  silently and leaves the target on its component default - the speaker sat on
  two waves at every volume for a whole round because `wavesForLevel` had landed
  inside the header item instead of on the window.
- **A child item's `y` is relative to its parent, and `header` is offset by
  `headTop`.** Placing the volume widget at an absolute design y put it 76 units
  too low. The volume metrics are absolute; the placements subtract `headTop`
  back out. Worth watching for any new header child.
- **A `Process` is a `PostReloadHook` and is carried across config reloads.**
  That is deliberate - your long-running children survive a reload - but it
  means editing `scripts/stats.sh` does *not* restart the poller, and `bash`
  has already read the old loop into memory. The script now watches its own
  mtime and `exec`s itself when it changes. It also means a child that dies is
  never restarted: `shell.qml` carries a slow heartbeat timer that re-runs it,
  otherwise the capsules silently freeze on their last reading.
- **Two same-coloured shapes meeting exactly leave a hairline.** Their
  antialiased edges land on different pixels, so a butt joint between the date
  cap and the elbow column shows as a faint line. Overlapping them by 2 units
  with the later-drawn shape on top hides it.

## Parked

`dev/parked-pre-expand/` is a complete copy of `shell.qml`, `ui/`, `theme/` and
`scripts/` from immediately before the collapse/expand experiment - the rollback
point. See the README.txt in there for how to restore it. The folder has no git,
so this is the only copy.

`dev/parked-glass/` holds the glass / backlit-pane material from study 14. It was
reverted because it did not land: softening the pigment as well as the lighting
made the shell read as pastel plastic rather than lit glass, and the highlight
blew the pale alloys out to white. It is inert - nothing imports it - and it is
only kept because this folder has no git, so a revert would otherwise be
permanent. See the README.txt in there for how to bring it back.

`feeds/` and `tracking-test.qml` hold the live tracking feed - a Node poller
(CelesTrak TLE + SGP4 for the ISS, USGS for earthquakes) behind a
`Quickshell.Io` `Process`, and a two-panel harness over it. It was built and
verified against live data, then parked before it was ever wired into
`shell.qml`: the layout is still moving, and this was a detour from it. Inert -
nothing imports it - and kept because this folder has no git. See
`feeds/README.txt` for how to run it again. The "The tracking feed (PARKED)"
section above is the record of how it works.

## Known rough edges

- Hex values live in two places: `LcarsUi` and a couple of inline literals in
  `shell.qml` (the TZ stub). Fold them into the theme when the palette settles.
- `LcarsButton.qml` is now unused; keep it or delete it when the footer question
  is settled for good.
- The band segments are still hand-positioned off each other, which is fine for
  four of them but wants to be a model-driven component before the lists grow.
- The reference has small scroll/arrow accents on the app field that are not
  reproduced.
- The hello bar spans edge to edge with no side margin, unlike everything else
  in the layout. It matches Project-Eve, but if it should respect `m` it is a
  two-line change in the `helloBar` item.


## Battery and network console

The battery gauge sits beside volume: a vertical segmented meter when expanded,
and a compact meter when folded. Percentages appear only in hover/status text. A battery icon identifies both
layouts. Compact battery and volume bars share a 26-unit height, leaving space for status
text and a gap above the horizontal LCARS strip. Bars are white, turning
red at 20% and below. Compact mode has five bars; the expanded icon sits centered
below the meter, with its percentage in the hover/status text. Status text stays visible at 30% and below, and while plugged in.
Plugged-in percentage and status text are green and report charging (or full /
charge held when appropriate). While plugged in, a glowing white fill repeatedly grows from the
current charge toward full; the percentage continues to report the actual charge.
Touch or hover for charging state. Missing batteries
show `--`. `scripts/battery.py` reads laptop battery telemetry from sysfs every
five seconds, excluding peripheral batteries.

The header **NET** capsule opens the centered network console. The overlay blocks
input to the underlying shell; tap outside, or press Escape to dismiss it. The
**NETWORK** rail button opens a network screen that fills the application area
to the right edge. Its content slides in from the right and slides back out
when another mode is selected. Its rail segments show live download, upload,
frequency, link speed, and ping readings, with **MAIN** beneath them to exit
Network. Tap the top elbow or press
Escape to return to the main rail. A password field in this screen can raise the
touch keyboard while the network controls remain above it.

The header pill reports an active Wi-Fi or wired
connection in green (`CONNECTED`), or shows LCARS red (`INACTIVE`) with no active
link. The frame uses a yellow top elbow with violet, mauve, sky, rust, and peach
accents; the Wi-Fi toggle is violet beside the amber Scan button. A small RX/TX
activity graph shows recent transfer samples. Routine status refreshes update
silently, without flashing an activity message or disabling controls. The LCARS frame uses compound elbows,
a segmented spine, and curved row markers. Network rows are 82 design units high
and support touch scrolling. The console scales down to fit smaller windows.

Select a network, then **CONNECT** (or **DISCONNECT** for the current connection).
Saved profiles reuse their credentials; new secured networks show a password
field. **SCAN** refreshes nearby access points; **WI-FI** toggles the radio.
New enterprise and legacy WEP profiles require setup in the system network
settings. The menu closes with Escape or by tapping outside it.
Connection errors remain in the console. No network state changes merely by
opening the menu. Closing clears password entry while an already submitted
operation can finish in the background.

The current Wi-Fi network is green, saved profiles are violet, and new/unsaved
networks are peach; the row markers, text, signal bars, and legend share those
colors. The menu frame shows interface, download, upload, frequency, link speed,
ping, gateway, and IP address in place of decorative labels. The live metrics
stream reuses Omarchy's `network status --verbose` data while the menu or the
expanded header readout is visible. The readout replaces two numeric columns
with download, upload, and ping labels and values, and sampling stops when the
header is compact and the network views are closed;
transfer rates are calculated from byte-counter changes, so the first sample
shows `--`. A missing metric also shows `--`.

`scripts/network.py` uses NetworkManager via `nmcli` and JSON over standard input.
Passwords are passed using a private temporary password file, removed after
activation; they never appear in process arguments. Existing saved profiles are
preserved on failure. The service refreshes cached status every ten seconds while
the menu is open and scans only when requested.

Validation and offline design preview:

```bash
python3 dev/test-network-battery.py
qs -p network-test.qml
qs -p network-preview.qml
```

The preview uses fictional networks and never starts the network backend.
`LCARS_CAPTURE=1 qs -p network-preview.qml` saves an offscreen-compatible capture
to `/tmp/lcars-network-preview.png` and quits.

The top yellow bar includes a live 12-hour clock in tall black Antonio Light
type, matching the stardate weight, immediately left of the power button. It shows
`HH:MM` when compact and `HH:MM:SS` when expanded, updating once per second.

The mode heading uses the same 62-unit region in both panel states. Expanded, a
smaller `LCARS ACCESS 441` line sits above the live system hostname; compact,
the hostname disappears and the heading moves to the right of the CPU/MEM/NET/DSK
buttons. The four buttons shift left to make room without changing their size.
Expanded title and hostname align to the left edge of that button group; long
hostnames elide within the group width.
