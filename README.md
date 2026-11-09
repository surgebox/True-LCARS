# True-LCARS
---
A Star Trek LCARS–inspired graphical shell for **Fedora Linux**, built on
**Hyprland** + **Quickshell** (QML). Every pixel of the interface — bars,
panels, buttons, status readouts, launcher, animations — is drawn by our own
QML code, so the LCARS style is the *whole* interface, not a theme on top of
a normal desktop.

---
## Getting started

**You need: Fedora 44** in VirtualBox or on a real machine. The shell targets
the 0.2.1 Quickshell that Fedora 44 ships — don't use another Fedora version
without reading the notes below. Then, from a terminal:

```bash
# 1. Clone into your home directory (the config expects this exact path):
cd ~
git clone --branch henry/lcars-shell https://github.com/surgebox/True-LCARS.git

# 2. Bundle Installer — Hyprland + Quickshell + apps + font (<~10 mins):
cd True-LCARS
bash scripts/setup-fedora.sh

# The orbital feed uses satellite.js; install it before starting the shell.
npm ci --prefix shell/feeds/orbit

# 3. Log out, and at the login screen pick the "LCARS/Python" session (gear icon).
```
The LCARS/Python session starts Hyprland, which starts the shell automatically
through `exec-once` in `hypr/hyprland.conf`. The installer copies that config
to `~/.config/hypr/hyprland.conf`. If your repo lives
somewhere other than `~/True-LCARS`, fix the path in that file.


You should see the LCARS layout window. `SUPER+Return` opens a terminal.
For a manual run from the repo root, use `qs -p shell/shell.qml`; `shell/run.sh`
also starts it. The layout is still a windowed shell study, so use Hyprland's
`SUPER+F` to fullscreen it. `shell/run.sh --fullscreen` uses an Omarchy-specific
Hyprland command and is not expected to work on stock Fedora.

**Fedora notes:** The installer replaces your Hyprland config. Back up any
existing `~/.config/hypr/hyprland.conf` first. It installs Fedora's Quickshell
package and version-locks it because the COPR build used by this setup has had
a Qt private-API mismatch. The LCARS notification panel needs to own the desktop
notification service; stop another notification daemon if notifications do not
appear. Network controls need NetworkManager (`nmcli`). Detailed network metrics
use `omarchy-network-status` and show `--` on stock Fedora; basic network
connection controls still work. Media previews depend on available codecs.

---

## How to Branch
When making and using branches, you can thing of it as having "main" and "alternate" branches. The "main" branch that we are using is
the original code that will be used for Project EVE. If someone wanted to make an adjustment, test something out,
or just see what they can do with the code without worrying about ruining the original code that can make a branch of the code. 
There can be multiple branches at the same time, just make sure that the code you branch from is from
"main" and not a branch of "main". Once you finished editing the code and want to add what you worked
on back to the main branch you can click on the pull request. After the Programming Lead has reviewed the code an answer will be given 
and the branch will either be merged into the “main” branch or denied.

```
[ main branch ] ─────────────────────────────────────────> (Final Product)
      |                                           ▲
      |  (Copied & split)                         |  (Merging back into main)
      ▼                                           | 
[ 2nd branch  ] ───────(individual coding)───────── 
```
---

# Development loop 

Quickshell watches the shell QML files and reloads them as you save. So:

1. Edit any file in `shell/`
2. Save — the running shell reloads instantly
3. Screenshot / repeat

No compile step, no restart, no command line needed for iteration.

---

**Graphics notes:**(requires verification as of 09/08/26)
- **VirtualBox without 3D acceleration:** works out of the box — software
  rendering is pre-configured — but expect it to be slow. See
  `docs/vm-virtualbox.md` for the 3D-acceleration upgrade.
- **Physical machine with a real GPU:** comment out the two lines
  `env = LIBGL_ALWAYS_SOFTWARE` and `env = GALLIUM_DRIVER` in
  `~/.config/hypr/hyprland.conf` for full speed.

---

## Why this stack

| Piece | Job |
|---|---|
| **Hyprland** | Wayland compositor: draws windows, manages workspaces, animations. Ships with *no* bars or menus, so nothing fights our design. |
| **Quickshell** | The shell: our QML code renders the full-screen background, top bar, status bar, nav panel, launcher and (later) notifications. It talks to Hyprland over its IPC (`Quickshell.Hyprland`) and reads system data (`Quickshell.Io`, `Quickshell.Networking`, `Quickshell.Services.*`). |
| **Fedora** | The base OS. VirtualBox-friendly, and the professor gets a ready-to-import `.ova` appliance at the end. |

---

## Repo layout
(placeholder, update as changes happen)
```
True-LCARS/
├── README.md              ← you are here
├── docs/
│   ├── STYLE.md           ← LCARS design guide (colors, fonts, shapes, motion)
│   ├── PHASES.md          ← project plan: phases, roles, risks, delivery
│   └── vm-virtualbox.md   ← VirtualBox setup, autologin, .ova export
├── hypr/
│   └── hyprland.conf      ← compositor config (launches the shell)
├── scripts/
│   └── setup-fedora.sh    ← one-shot Fedora installer (COPRs + packages + font)
└── shell/                 ← the whole LCARS UI, in QML
    ├── shell.qml          ← entry point (ShellRoot)
    ├── qmldir             ← registers LcarsStyle as a singleton
    ├── LcarsStyle.qml     ← THE design tokens: colors, fonts, metrics
    ├── LcarsPanel.qml     ← rounded LCARS panel
    ├── LcarsElbow.qml     ← the classic asymmetric "elbow" shape
    ├── LcarsButton.qml    ← touch-friendly LCARS button (hover/press)
    ├── LcarsLabel.qml     ← LCARS-styled text
    ├── TopBar.qml         ← master bar: title, workspaces, clock
    ├── StatusBar.qml      ← bottom strip: CPU / MEM / uptime
    ├── NavPanel.qml       ← left navigation column
    ├── WorkspacePager.qml ← live Hyprland workspace switcher
    ├── ClockReadout.qml   ← clock + stardate
    ├── SystemReadout.qml  ← CPU / RAM / uptime from /proc
    └── Launcher.qml       ← app launcher overlay
```

---

## Credits / related work

- [Quickshell](https://quickshell.org) — the toolkit (MIT/ LGPL, see repo)
- [lcarsde](https://github.com/lcarsde/lcarsde) — an earlier full LCARS desktop environment (reference material)
- Antonio font by Santiago Orozco — [SIL OFL](https://github.com/google/fonts/tree/main/ofl/antonio), Closest LCARS font
-  LCARS is a design language from *Star Trek* (Paramount). This is a fan-made,
  educational project: "LCARS-inspired", not affiliated with or endorsed by
  Paramount.
