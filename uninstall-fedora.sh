#!/usr/bin/env bash
# Remove LCARS-owned files. Optional package removal uses the install manifest.
set -euo pipefail

app_dir=/usr/local/share/lcars
manifest=/var/lib/lcars/install-info
[[ ${EUID} -ne 0 ]] || { echo 'Run as your regular user.' >&2; exit 1; }
command -v sudo >/dev/null || { echo 'sudo is required.' >&2; exit 1; }

remove_packages=0
if [[ ${1:-} == --remove-packages ]]; then
    remove_packages=1
elif [[ $# -gt 0 ]]; then
    echo 'Usage: ./uninstall-fedora.sh [--remove-packages]' >&2
    exit 2
fi

if ((remove_packages)) && [[ ! -f $manifest ]]; then
    echo 'Install record is missing; cannot identify which packages LCARS added.' >&2
    exit 1
fi

if ((remove_packages)); then
    # The file was written only by the installer. Read values without executing
    # its contents as shell code.
    new_packages=$(sed -n 's/^new_packages=//p' "$manifest")
    copr_enabled=$(sed -n 's/^copr_enabled=//p' "$manifest")
    remove_plugin=0
    if [[ -n $new_packages ]]; then
        read -r -a recorded_packages <<< "$new_packages"
        packages=()
        for package in "${recorded_packages[@]}"; do
            if [[ $package == dnf5-plugins ]]; then
                remove_plugin=1
            else
                packages+=("$package")
            fi
        done
        if ((${#packages[@]})); then
            sudo dnf remove "${packages[@]}"
        fi
    fi
    if [[ $copr_enabled == 1 ]]; then
        sudo dnf copr disable ashbuk/Hyprland-Fedora
    fi
    if ((remove_plugin)); then
        sudo dnf remove dnf5-plugins
    fi
fi

sudo rm -f -- /usr/share/wayland-sessions/lcars.desktop \
    /usr/local/bin/lcars-session /usr/local/bin/lcars-shell
sudo rm -rf -- "$app_dir" /usr/local/share/fonts/lcars /var/lib/lcars
echo 'LCARS session removed. Existing Fedora sessions and user files were left in place.'
