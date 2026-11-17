#!/usr/bin/env bash
# Install the current LCARS desktop as a separate Fedora login session.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
app_dir=/usr/local/share/lcars
font_dir=/usr/local/share/fonts/lcars
session_file=/usr/share/wayland-sessions/lcars.desktop
launcher=/usr/local/bin/lcars-session
shell_launcher=/usr/local/bin/lcars-shell
manifest=/var/lib/lcars/install-info
copr=ashbuk/Hyprland-Fedora

die() { printf 'LCARS installer: %s\n' "$*" >&2; exit 1; }
note() { printf 'LCARS installer: %s\n' "$*"; }

[[ ${EUID} -ne 0 ]] || die 'Run as your regular user; the script invokes sudo when needed.'
[[ -r /etc/os-release ]] || die 'Cannot identify the operating system.'
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == fedora ]] || die 'This installer supports Fedora Linux only.'
[[ ${VERSION_ID:-} == 44 || ${VERSION_ID:-} == 45 ]] || die 'Supported Fedora releases: 44 and 45.'
command -v dnf >/dev/null || die 'DNF is required (Fedora Workstation/RPM edition).'
command -v sudo >/dev/null || die 'sudo is required.'
[[ -f $here/desktop.qml && -f $here/ShellContent.qml && -f $here/scripts/app_layout.py ]] ||
    die 'Desktop files are missing. Use a complete checkout of the current project.'

packages=(quickshell qt6-qtdeclarative qt6-qtmultimedia NetworkManager
    pipewire-utils pulseaudio-utils poppler-utils ffmpeg-free python3 xdg-utils
    kitty fontconfig curl jetbrains-mono-fonts)
if [[ $VERSION_ID == 45 ]]; then
    packages+=(fontawesome-7-free-fonts)
else
    packages+=(fontawesome-6-free-fonts)
fi

if ! command -v Hyprland >/dev/null || ! command -v hyprctl >/dev/null; then
    packages+=(hyprland)
    need_copr=1
else
    need_copr=0
fi

if [[ -e $manifest ]]; then
    previous_packages=$(sed -n 's/^new_packages=//p' "$manifest")
    previous_copr=$(sed -n 's/^copr_enabled=//p' "$manifest")
else
    previous_packages=''
    previous_copr=0
fi

note "Fedora $VERSION_ID; installing a separate LCARS session."
note "Packages: ${packages[*]}"
if ((need_copr)); then
    note "Hyprland is supplied by the community COPR $copr (not Fedora's official repository)."
fi
note 'DNF will display the download and installed sizes before asking to proceed.'

# Collect only direct package names absent before this run for optional removal.
new_packages=()
for package in "${packages[@]}"; do
    if ! rpm -q "$package" >/dev/null 2>&1; then
        new_packages+=("$package")
    fi
done

if ((need_copr)); then
    if ! rpm -q dnf5-plugins >/dev/null 2>&1; then
        new_packages+=(dnf5-plugins)
    fi
    sudo dnf install dnf5-plugins
    if sudo dnf repolist --enabled | grep -q 'copr.*ashbuk.*Hyprland-Fedora'; then
        need_copr=0
    else
        sudo dnf copr enable "$copr"
    fi
fi
sudo dnf install "${packages[@]}"

command -v qs >/dev/null || die 'Quickshell was installed but qs is unavailable.'
command -v Hyprland >/dev/null || die 'Hyprland was installed but its executable is unavailable.'
if ! systemctl is-active --quiet NetworkManager; then
    note 'NetworkManager is installed but not active; Wi-Fi controls need that service running.'
fi
hypr_version=$(Hyprland --version 2>&1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
[[ -n $hypr_version ]] || die 'Could not determine the Hyprland version.'
hypr_minor=${hypr_version#*.}
hypr_minor=${hypr_minor%%.*}
[[ $hypr_minor =~ ^[0-9]+$ ]] || die 'Could not parse the Hyprland version.'
if ((hypr_minor < 55)); then
    die "Hyprland $hypr_version is too old for the LCARS Lua session (needs 0.55+)."
fi

# Antonio is not packaged in Fedora 44/45. Fetch the OFL licensed upstream
# font and its license into the LCARS-owned directory, never into user fonts.
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
font_url='https://raw.githubusercontent.com/google/fonts/main/ofl/antonio'
curl -fL --retry 3 -o "$tmp_dir/Antonio.ttf" "$font_url/Antonio%5Bwght%5D.ttf"
curl -fL --retry 3 -o "$tmp_dir/OFL.txt" "$font_url/OFL.txt"
fc-scan --format '%{family}\n' "$tmp_dir/Antonio.ttf" | grep -qx 'Antonio' ||
    die 'The Antonio download is not a valid Antonio font.'

sudo install -d -m 755 "$app_dir" "$app_dir/ui" "$app_dir/theme" "$app_dir/scripts" "$font_dir"
sudo install -m 644 "$here/desktop.qml" "$here/ShellContent.qml" "$app_dir/"
sudo install -m 644 "$here"/ui/*.qml "$app_dir/ui/"
sudo install -m 644 "$here"/theme/*.qml "$here"/theme/qmldir "$app_dir/theme/"
sudo install -m 644 "$here"/scripts/*.py "$here"/scripts/*.sh "$app_dir/scripts/"
sudo install -m 644 "$tmp_dir/Antonio.ttf" "$font_dir/Antonio.ttf"
sudo install -m 644 "$tmp_dir/OFL.txt" "$font_dir/OFL.txt"
sudo sed -i 's/JetBrainsMono NF/JetBrains Mono/g' "$app_dir/theme/LcarsUi.qml"

# Fedora 44 provides Font Awesome 6, and the QML's icon codepoints are from
# the Free Solid set shared by versions 6 and 7.
if [[ $VERSION_ID == 44 ]]; then
    sudo sed -i 's/Font Awesome 7 Free Solid/Font Awesome 6 Free Solid/g' \
        "$app_dir/ShellContent.qml" "$app_dir"/ui/*.qml
fi

sudo install -m 644 "$here/session/hyprland.lua" "$app_dir/hyprland.lua"
sudo install -m 755 "$here/session/lcars-session" "$launcher"
sudo install -m 755 "$here/session/lcars-shell" "$shell_launcher"
sudo install -d -m 755 /usr/share/wayland-sessions /var/lib/lcars
sudo install -m 644 "$here/session/lcars.desktop" "$session_file"
all_new_packages="${previous_packages} ${new_packages[*]}"
read -r -a package_words <<< "$all_new_packages"
all_new_packages=$(printf '%s\n' "${package_words[@]}" | awk 'NF && !seen[$0]++' | paste -sd ' ' -)
if [[ $previous_copr == 1 ]]; then need_copr=1; fi
sudo tee "$manifest" >/dev/null <<EOF
fedora=$VERSION_ID
copr_enabled=$need_copr
new_packages=$all_new_packages
EOF
sudo fc-cache -f "$font_dir"

note 'Installed. Log out, choose LCARS at the login screen, and sign in.'
note 'Super+Return opens a terminal; Super+Shift+E logs out.'
note 'To remove the session later, run ./uninstall-fedora.sh from this checkout.'
