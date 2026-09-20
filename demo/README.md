# demo/ - one runnable file per component

A component file like `ui/LcarsRect.qml` is a **definition, not a program**. It
has no size, no background and no screen, so running it directly gives you an
empty window. That is not a bug - it is the trade you make for being able to
embed it.

These demos are the other half. Each one is a small throwaway window whose only
job is to put ONE component on screen so you can look at it.

    qs -p demo/rect.qml

## Why this exists

Component galleries are standard practice - Storybook in the JS world, Qt's own
`qmlscene`. You build each piece in isolation and look at it before assembling
anything. Changing a radius in `ui/LcarsRect.qml` and re-running `demo/rect.qml`
shows you that radius and nothing else, instead of making you squint at a
2048x1152 screenshot trying to work out which of forty rectangles moved.

## The five parts of a demo

1. **A `Window`** - the container that makes it runnable at all.
2. **The scale binding** - see below. Pin it to `1`.
3. **The component**, usually several variants side by side. You are looking for
   which case is *wrong*, and that is much easier to spot across a row than one
   at a time.
4. **A labelled heading** naming the component being shown.
5. **A note** with the property names, so the screenshot still makes sense to
   you tomorrow.

## The scale binding, and why it is pinned to 1

```qml
Binding { target: LcarsUi; property: "scale"; value: 1 }
```

The shell derives its scale from the *screen* height (`screenHeight / 1152`), so
on a 1152-tall display a design unit is one pixel. A demo window is much
smaller, so if it derived its scale the same way everything would render at
around half size - and every measurement you were studying would be wrong by a
factor of two without anything looking obviously broken.

Pinning it to `1` means a component renders here at the same size it renders in
the shell.

## The symlinks - what they are for

```
demo/ui    -> ../ui
demo/theme -> ../theme
```

QML will not resolve a directory import through `..`. `import "../ui"` from this
folder fails with `LcarsRect is not a type`, and it fails identically whether or
not a `qmldir` is present. A relative directory import only reaches *below* the
importing file.

So each demo says `import "ui"` and `import "theme"`, and these two symlinks
make those names resolve. They are the only reason the folder works; delete one
and every demo stops loading.

## Running one

```bash
qs -p demo/rect.qml                        # open it
./dev/shot.sh demo/rect.qml /tmp/out.png   # or capture it
```

Escape quits after a demo loads - which also means a stray Escape closes the
window rather than the demo being broken.

## Editing loop, and one warning

    edit ui/LcarsX.qml  ->  qs -p demo/x.qml  ->  look  ->  repeat

**Quickshell's hot reload is unreliable.** If your change appears to do nothing,
kill the process and start it fresh before concluding anything. A stale config
looks exactly like a broken binding, and it has cost real time on this project
more than once.

## What is here

| file | component | what it shows |
|---|---|---|
| `rect.qml` | `LcarsRect` | all four corner radii separately, and radius clamping |
| `label.qml` | `LcarsLabel` | design-unit sizing, caps, tracking, weight, `fit` |
| `strip.qml` | `LcarsStrip` | plain, end caps, uniform rounding |
| `capsule.qml` | `LcarsCapsule` | the readout pill, and `valueFit` with long values |
| `textbar.qml` | `LcarsTextBar` | the HELLO bar, accent variants, `powerButton` off |
| `elbow.qml` | `LcarsElbow` | all four orientations, annotated with their parameters |

## Adding one

Copy the nearest existing demo, point it at the component you want, and change
the heading. Then **verify it loads** before trusting what you see:

```bash
qs -p demo/newthing.qml 2>&1 | grep -iE 'Failed to load|is not a type'
```

Loading cleanly is not the same as rendering correctly - take a screenshot and
look. Several bugs on this project were a component that loaded perfectly and
painted nothing.
