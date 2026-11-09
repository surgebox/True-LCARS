#!/usr/bin/env bash
# ============================================================
# LCARS shell — one-shot Fedora setup
#   Run from the repo root:   bash scripts/setup-fedora.sh [--autologin]
#
# WHAT THIS INSTALLS
#   - Hyprland          from the lionheartp/Hyprland COPR
#   - Quickshell 0.2.1  from the OFFICIAL Fedora repos. NOT from the COPRs:
#                       both quickshell COPR builds for Fedora 44 currently
#                       fail to start with
#                         "symbol lookup error: ... Qt_6.11_PRIVATE_API"
#                       because they are built against a Qt newer than what
#                       Fedora 44 stable ships. Fedora's own 0.2.1 build is
#                       compiled against the repos' exact Qt, so it always
#                       links. The shell QML targets this 0.2.1 API.
#   - Qt/QML extras, kitty, firefox, nautilus, screenshot tools,
#     Mesa software Vulkan (lavapipe, for VirtualBox), the Antonio font,
#     SDDM (enabled only with --autologin)
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HYPR_COPR="${HYPR_COPR:-lionheartp/Hyprland}"

AUTOLOGIN=0
if [[ "${1:-}" == "--autologin" ]]; then
    AUTOLOGIN=1
fi

echo "==> [1/5] Enabling the Hyprland COPR ($HYPR_COPR)..."
sudo dnf copr enable -y "$HYPR_COPR"

echo "==> [2/5] Installing Hyprland + apps (quickshell deliberately NOT here)..."
sudo dnf install -y \
    hyprland \
    kitty \
    firefox \
    nautilus \
    grim \
    slurp \
    wl-clipboard \
    qt6-qtdeclarative \
    qt6-qtquickcontrols2 \
    qt6-qt5compat \
    qt6-qtsvg \
    qt6-qtimageformats \
    qt6-qtmultimedia \
    python3 \
    nodejs \
    npm \
    NetworkManager \
    wireplumber \
    pulseaudio-utils \
    iproute \
    iw \
    poppler-utils \
    ffmpeg-free \
    fontconfig \
    mesa-vulkan-drivers \
    sddm

echo "==> [3/5] Installing Quickshell from the OFFICIAL Fedora repos..."
# The COPRs also ship quickshell (0.3.x) but those builds are broken on
# Fedora 44 stable (Qt private-API mismatch). Disabling COPRs for this one
# install makes dnf pick Fedora's quickshell-0.2.1, which matches the
# installed Qt exactly.
sudo dnf --disablerepo='copr*' install -y quickshell

# Pin it so a later `dnf upgrade` cannot silently pull the broken COPR build.
if ! rpm -q python3-dnf-plugin-versionlock >/dev/null 2>&1; then
    sudo dnf install -y python3-dnf-plugin-versionlock
fi
sudo dnf versionlock add quickshell || true

echo "==> [4/5] Installing the Antonio font (SIL OFL, very LCARS)..."
mkdir -p "$HOME/.local/share/fonts"
FONT="$HOME/.local/share/fonts/Antonio.ttf"
if [[ ! -f "$FONT" ]]; then
    curl -fL -o "$FONT" \
        "https://github.com/google/fonts/raw/main/ofl/antonio/Antonio%5Bwght%5D.ttf"
fi
fc-cache -f >/dev/null 2>&1 || true

echo "==> [5/5] Installing Hyprland config and LCARS/Python login session..."
mkdir -p "$HOME/.config/hypr"
cp "$REPO_DIR/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
echo "    -> ~/.config/hypr/hyprland.conf"
sudo install -Dm644 "$REPO_DIR/hypr/lcars-python.desktop" \
    /usr/share/wayland-sessions/lcars-python.desktop
echo "    -> /usr/share/wayland-sessions/lcars-python.desktop"

if [[ "$AUTOLOGIN" == "1" ]]; then
    echo "==> Enabling SDDM autologin for '$USER' (session: LCARS/Python)..."
    sudo mkdir -p /etc/sddm.conf.d
    printf '[Autologin]\nUser=%s\nSession=lcars-python.desktop\n' "$USER" \
        | sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null
    sudo systemctl enable sddm
    sudo systemctl set-default graphical.target
fi

echo
echo "Done. Next steps:"
echo "  1) Log out of your current desktop and pick 'LCARS/Python' at the login"
echo "     screen (gear menu), or from a TTY run:  Hyprland"
echo "  2) VirtualBox guest? Uncomment the WLR_RENDERER env lines in"
echo "     ~/.config/hypr/hyprland.conf (see docs/vm-virtualbox.md)."
echo "  3) The shell hot-reloads QML edits as you save."
