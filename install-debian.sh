#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# NOTE: scripts/dwm-utils.sh only resolves PKG_CMD to paru/yay/pacman and
# never defines DISTRO_NAME (same situation install-fedora.sh is in), so
# it isn't sourced here. This script is self-contained until dwm-utils.sh
# gets a Debian/apt branch.

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
source "$REPO_DIR/scripts/post-install.sh"

command -v apt-get &>/dev/null || { err "This installer requires Debian/Ubuntu (apt-get not found)."; exit 1; }

PKG_CMD="apt"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-Debian/Ubuntu}"
else
    DISTRO_NAME="Debian/Ubuntu"
fi

# apt-get as root, non-interactive. DEBIAN_FRONTEND is passed through `env` because sudo
# resets the environment: a plain `export` never reaches apt, so debconf could still ask
# questions (e.g. which display manager to use when SDDM is installed).
apt_get() { sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

# Packages that could not be installed; listed in a summary at the end of the run.
FAILED_PKGS=()

# Install a batch; if apt rejects the batch because ONE package is unknown, retry one
# by one so a single missing package no longer aborts the whole install.
# Returns non-zero if anything failed, and remembers what in FAILED_PKGS.
install_packages() {
    apt_get install -y "$@" && return 0
    if [ "$#" -eq 1 ]; then
        warn "Could not install: $1"
        FAILED_PKGS+=("$1")
        return 1
    fi
    warn "Batch install failed - retrying package by package..."
    local p rc=0
    for p in "$@"; do
        apt_get install -y "$p" || { warn "Could not install: $p"; FAILED_PKGS+=("$p"); rc=1; }
    done
    return $rc
}

# install_any <pkg> [<alternative>...]: install the first one that works. For packages that
# were renamed between releases; only counts as a failure if none of them can be installed.
install_any() {
    local p
    for p in "$@"; do
        if apt_get install -y "$p" 2>/dev/null; then return 0; fi
    done
    warn "Could not install any of: $*"
    FAILED_PKGS+=("$1")
    return 1
}

BG_DIR="$HOME/Pictures/backgrounds"
FONT_DIR="$HOME/.local/share/fonts"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║        dwm-tudor Installer (Debian)       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Package manager: $PKG_CMD"

# Packages for the optional GTK look (used by setup_gtk_look in scripts/post-install.sh)
install_gtk_theme_packages() { install_packages materia-gtk-theme papirus-icon-theme; }

# ── Refresh package lists ─────────────────────────────────
# Unlike pacman/dnf, apt needs an explicit metadata refresh or a fresh
# system will 404 on half the packages below.
info "Updating package lists..."
apt_get update -qq
ok "Package lists updated."

# ── Build dependencies ───────────────────────────────────
info "Installing build dependencies..."
install_packages build-essential pkg-config \
    libx11-dev libxft-dev libxinerama-dev libimlib2-dev \
    libxcb1-dev libxcb-util-dev fontconfig
# dwm.c includes <X11/Xlib-xcb.h> and <xcb/res.h> directly and
# config.mk links -lX11-xcb -lxcb-res. On Arch these ship inside the
# libx11/libxcb packages already pulled in above, so install-arch.sh
# never needs to name them — but Debian splits both into their own
# dev packages, and without them the build fails with "Xlib-xcb.h: No
# such file or directory" / "xcb/res.h: No such file or directory".
install_packages libx11-xcb-dev libxcb-res0-dev
# freetype's and fontconfig's dev packages were renamed at different points across
# Debian/Ubuntu releases — try the current name first, fall back to the old one.
install_any libfreetype-dev libfreetype6-dev
install_any libfontconfig-dev libfontconfig1-dev

if dpkg -l 2>/dev/null | grep -qi '^ii.*xlibre'; then
    info "Xlibre detected — skipping xserver-xorg."
elif ! dpkg -s xserver-xorg-core &>/dev/null; then
    install_packages xserver-xorg
fi
install_packages xinit x11-xserver-utils x11-utils
ok "Build dependencies installed."

# ── Runtime dependencies ─────────────────────────────────
info "Installing runtime dependencies..."
if install_packages rofi picom dunst feh flameshot dex papirus-icon-theme mate-polkit alsa-utils git curl unzip xz-utils xclip \
    thunar gvfs tumbler thunar-archive-plugin xdg-user-dirs \
    xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring network-manager network-manager-gnome \
    libnotify-bin rsync xdotool x11-xkb-utils
then
    ok "Runtime dependencies installed."
else
    warn "Some runtime dependencies could not be installed (listed at the end)."
fi

# ── Quickshell (wallpaper picker) ────────────────────────
# config/quickshell/wallpaper-picker is a Quickshell QML app. Debian splits the Qt QML
# modules it imports into separate packages (QtQuick, QtQuick.Controls, QtQuick.Effects,
# Qt.labs.folderlistmodel) and quickshell also needs QtQml.Models + the Qt6 declarative
# dev files - without them the picker silently fails to start.
info "Installing Qt QML modules for Quickshell..."
install_packages qt6-declarative-dev \
    qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-effects \
    qml6-module-qtqml-models qml6-module-qt-labs-folderlistmodel \
    || warn "Some Qt QML packages failed to install - the wallpaper picker may not start."

# quickshell is not in Debian 13 (trixie) main, but it IS in the official trixie-backports
# repository (signed by the Debian archive key - no third-party key needed). Debian 14 /
# sid and Ubuntu 26.10+ have it in the normal archive.
install_quickshell() {
    if command -v quickshell &>/dev/null; then
        ok "quickshell already installed."
        return 0
    fi

    # 1) Already visible to apt (Debian 14/forky, sid, Ubuntu 26.10+)?
    if apt-cache policy quickshell 2>/dev/null | grep -q 'Candidate: [^(]'; then
        if apt_get install -y quickshell; then ok "quickshell installed."; return 0; fi
        FAILED_PKGS+=("quickshell")
        return 1
    fi

    # 2) Debian 13 (trixie, or a derivative based on it): enable trixie-backports
    local codename="${DEBIAN_CODENAME:-${VERSION_CODENAME:-}}"
    if [ "$codename" = "trixie" ] && { [ "${ID:-}" = "debian" ] || [ -n "${DEBIAN_CODENAME:-}" ]; }; then
        if ! grep -rqsE '^[^#]*trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
            info "Enabling the official Debian backports repository (trixie-backports)..."
            sudo tee /etc/apt/sources.list.d/debian-backports.sources >/dev/null <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
            apt_get update -qq || warn "apt update failed after adding trixie-backports."
        fi
        # backports are NotAutomatic: they must be requested explicitly with -t
        if apt_get install -y -t trixie-backports quickshell; then
            ok "quickshell installed from trixie-backports."
            return 0
        fi
        warn "Could not install quickshell from trixie-backports."
        FAILED_PKGS+=("quickshell")
        return 1
    fi

    # 3) Nothing suitable
    warn "quickshell is not packaged for $DISTRO_NAME - wallpaper picker disabled."
    case "${ID:-} ${ID_LIKE:-}" in
        *ubuntu*) warn "Ubuntu < 26.10: third-party PPA with 'quickshell-git': sudo add-apt-repository ppa:avengemedia/danklinux && sudo apt install quickshell-git" ;;
        *)
            if [ "$codename" = "bookworm" ]; then
                warn "Debian 12 ships a Qt too old for Quickshell - Debian 13+ is required."
            fi
            warn "Install instructions: https://quickshell.org/docs/guide/install-setup"
            ;;
    esac
    FAILED_PKGS+=("quickshell")
    return 1
}
install_quickshell || true   # failure is already reported and recorded in FAILED_PKGS

# nwg-look isn't packaged for Debian/Ubuntu — no clean apt/PPA equivalent
install_packages nwg-look 2>/dev/null \
    || warn "nwg-look not available via apt — build from source (https://github.com/nwg-piotr/nwg-look) or check Flathub."

# ── Qt / GTK theming ─────────────────────────────────────
info "Installing Qt/GTK dark-mode dependencies..."
# dconf-gsettings-backend: required for gsettings to persist GTK color-scheme changes
# qt6ct / qt5ct: QT_QPA_PLATFORMTHEME backend for Qt dark mode in standalone WMs
install_packages dconf-cli dconf-gsettings-backend
install_any qt6ct qt5ct || warn "Qt apps may not respect dark mode."
ok "Qt/GTK theming dependencies installed."

# fetch_nerd_font <zip name> <target dir> <unzip pattern> <fontconfig family>
# Downloads a Nerd Fonts release asset and unpacks only the files matching <pattern>.
fetch_nerd_font() {
    local zip="$1" dir="$2" pattern="$3" family="$4" tmp
    if fc-list 2>/dev/null | grep -qi "$family"; then return 0; fi
    info "Downloading $family..."
    tmp="$(mktemp -d)"
    if curl -fL --retry 3 -o "$tmp/$zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$zip"; then
        mkdir -p "$dir"
        unzip -oqj "$tmp/$zip" "$pattern" -d "$dir" \
            || warn "Failed to unpack $family from $zip."
    else
        warn "Failed to download $family. Get $zip manually from https://www.nerdfonts.com/font-downloads and unzip $pattern into $dir"
    fi
    rm -rf "$tmp"
}

# ── Fonts ────────────────────────────────────────────────
info "Installing fonts..."
install_packages fonts-noto-color-emoji
mkdir -p "$FONT_DIR"

# JetBrainsMono Nerd Font isn't packaged for Debian/Ubuntu - fetch it from upstream
JB_DIR="$FONT_DIR/JetBrainsMonoNerdFont"
if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    info "Downloading JetBrainsMono Nerd Font..."
    JB_TMP="$(mktemp -d)"
    if curl -fL --retry 3 -o "$JB_TMP/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
        mkdir -p "$JB_DIR"
        unzip -oq "$JB_TMP/JetBrainsMono.zip" -d "$JB_DIR" -x 'LICENSE*' 'README*' \
            || warn "Failed to unpack JetBrainsMono Nerd Font archive."
    else
        warn "Failed to download JetBrainsMono Nerd Font. Get JetBrainsMono.zip manually from https://www.nerdfonts.com/font-downloads and unzip it into $JB_DIR"
    fi
    rm -rf "$JB_TMP"
fi

# MesloLGS Nerd Font Mono isn't packaged for Debian/Ubuntu either - fetch only the Mono family
# (S = small line spacing) instead of unpacking the whole Meslo archive
fetch_nerd_font Meslo.zip "$FONT_DIR/MesloLGSNerdFontMono" '*MesloLGSNerdFontMono-*.ttf' "MesloLGS Nerd Font Mono"

if [ -d "$REPO_DIR/config/polybar/fonts" ]; then
    cp -r "$REPO_DIR/config/polybar/fonts/"* "$FONT_DIR/"
fi
fc-cache -f >/dev/null 2>&1
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font available."
else
    warn "JetBrainsMono Nerd Font NOT found by fontconfig - icons in the bar/terminal/rofi will show as boxes."
fi
if fc-list 2>/dev/null | grep -qi "MesloLGS Nerd Font Mono"; then
    ok "MesloLGS Nerd Font Mono available."
else
    warn "MesloLGS Nerd Font Mono NOT found by fontconfig."
fi
ok "Fonts installed."

# ── Terminal emulator ────────────────────────────────────
terminal=""
for t in ghostty kitty alacritty; do command -v "$t" &>/dev/null && { terminal="$t"; break; }; done

if [ -n "$terminal" ]; then
    ok "Terminal already installed: $terminal"
else
    info "No supported terminal found — installing alacritty..."
    install_packages alacritty 2>/dev/null || warn "alacritty not in repos — install a terminal manually (SUPER+X expects alacritty)"
fi

# ── Polybar + XDG dirs + wallpapers ──────────────────────
install_packages polybar 2>/dev/null \
    || warn "polybar not found in repos — check backports or build from source: https://github.com/polybar/polybar"
command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update

mkdir -p "$HOME/Pictures"
if [ ! -d "$BG_DIR" ]; then
    info "Downloading wallpapers..."
    git clone https://github.com/tudorioan1/backgrounds.git "$BG_DIR" 2>/dev/null \
        && ok "Wallpapers downloaded to $BG_DIR" \
        || warn "Failed to download wallpapers. Add your own to $BG_DIR."
else
    ok "Wallpapers already present."
fi



# ── Display manager ──────────────────────────────────────
# Debian/Ubuntu's GDM package/binary is "gdm3", not "gdm" — check both.
# lightdm and gdm3 live in /usr/sbin, which is NOT in a normal user's PATH on Debian, so a
# plain `command -v` misses them and the script would install SDDM and try to enable it on
# top of the user's existing display manager. Look in the sbin dirs too, and honour an
# already-enabled display-manager.service.
currentdm=""
for dm in sddm lightdm gdm3 gdm; do
    if PATH="$PATH:/usr/sbin:/sbin" command -v "$dm" &>/dev/null; then currentdm="$dm"; break; fi
done
if [ -z "$currentdm" ] && [ -e /etc/systemd/system/display-manager.service ]; then
    currentdm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
fi

if [ -n "$currentdm" ]; then
    ok "Display manager already installed: $currentdm"
else
    info "No display manager found — installing SDDM..."
    install_packages sddm
    sudo systemctl enable sddm
    ok "SDDM installed and enabled."
fi

# ── Build & Install ──────────────────────────────────────
cd "$REPO_DIR"
# Build as the normal user (root-owned objects break later rebuilds), install as root.
make clean
make
sudo make install

# Verify Xft/Xinerama actually linked into the binary (config.mk's
# hardcoded /usr/X11R6 paths are usually harmless no-ops since gcc/ld
# fall back to /usr/include and /usr/lib, but let's confirm instead of
# assuming).
if [ -f "$REPO_DIR/dwm" ]; then
    info "Verifying dwm was linked against Xft/Xinerama..."
    if ldd "$REPO_DIR/dwm" 2>/dev/null | grep -qi 'libxft'; then
        ok "libXft linked."
    else
        warn "libXft NOT found in 'ldd dwm' output — fonts may not render correctly."
    fi
    if ldd "$REPO_DIR/dwm" 2>/dev/null | grep -qi 'libxinerama'; then
        ok "libXinerama linked."
    else
        warn "libXinerama NOT found in 'ldd dwm' output — multi-monitor support may be missing."
    fi
fi

# ── Optional setup (asked at the end) ────────────────────
# Each step asks first and is skipped without a terminal; see scripts/post-install.sh
setup_gtk_look
setup_bash_prompt
setup_default_browser

# ── Anything that failed to install? ─────────────────────
if [ "${#FAILED_PKGS[@]}" -gt 0 ]; then
    echo ""
    warn "dwm is installed, but these packages could not be installed:"
    printf '    - %s\n' "${FAILED_PKGS[@]}"
    warn "See the warnings above for how to get them, then re-run this script if you like."
fi

# ── Done ─────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║          Installation Complete!           ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Detected: $DISTRO_NAME"
echo "  • Edit config.h to customize, then: make && sudo make install"
echo "  • Log out and select 'dwm', or start with: startx"
echo ""
echo "  SUPER+/   keybind viewer     SUPER+X  terminal"
echo "  SUPER+F1  control center     SUPER+R  app launcher (rofi)"
echo "  SUPER+Q   close window"
echo ""
echo "  Full keybind reference: press SUPER+/ in dwm (reads ~/.config/dwm-tudor/hotkeys.toml)"
echo ""
