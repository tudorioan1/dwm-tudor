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

command -v apt-get &>/dev/null || { err "This installer requires Debian/Ubuntu (apt-get not found)."; exit 1; }

PKG_CMD="apt"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-Debian/Ubuntu}"
else
    DISTRO_NAME="Debian/Ubuntu"
fi

export DEBIAN_FRONTEND=noninteractive

# Install a batch; if apt rejects the batch because ONE package is unknown, retry one
# by one so a single missing package no longer aborts the whole install.
install_packages() {
    sudo apt-get install -y "$@" && return 0
    warn "Batch install failed - retrying package by package..."
    local p rc=0
    for p in "$@"; do
        sudo apt-get install -y "$p" || { warn "Could not install: $p"; rc=1; }
    done
    return $rc
}

BG_DIR="$HOME/Pictures/backgrounds"
FONT_DIR="$HOME/.local/share/fonts"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║        dwm-tudor Installer (Debian)       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Package manager: $PKG_CMD"

# ── Refresh package lists ─────────────────────────────────
# Unlike pacman/dnf, apt needs an explicit metadata refresh or a fresh
# system will 404 on half the packages below.
info "Updating package lists..."
sudo apt-get update -qq
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
# freetype's dev package was renamed from libfreetype6-dev to
# libfreetype-dev at different points across Debian/Ubuntu releases —
# try the current name first, fall back to the old transitional one.
install_packages libfreetype-dev 2>/dev/null || install_packages libfreetype6-dev
install_packages libfontconfig1-dev 2>/dev/null || true

if dpkg -l 2>/dev/null | grep -qi '^ii.*xlibre'; then
    info "Xlibre detected — skipping xserver-xorg."
elif ! dpkg -s xserver-xorg-core &>/dev/null; then
    install_packages xserver-xorg
fi
install_packages xinit x11-xserver-utils x11-utils
ok "Build dependencies installed."

# ── Runtime dependencies ─────────────────────────────────
info "Installing runtime dependencies..."
install_packages rofi picom dunst feh flameshot dex mate-polkit alsa-utils git curl unzip xclip \
    thunar gvfs tumbler thunar-archive-plugin xdg-user-dirs \
    xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring network-manager network-manager-gnome \
    libnotify-bin rsync xdotool x11-xkb-utils || true
ok "Runtime dependencies installed."

# quickshell is not in Debian stable (only testing/unstable) - needed for the wallpaper picker only
install_packages quickshell 2>/dev/null \
    || warn "quickshell not available via apt - wallpaper picker disabled. See https://quickshell.org/docs/guide/install-setup"

# nwg-look isn't packaged for Debian/Ubuntu — no clean apt/PPA equivalent
install_packages nwg-look 2>/dev/null \
    || warn "nwg-look not available via apt — build from source (https://github.com/nwg-piotr/nwg-look) or check Flathub."

# ── Qt / GTK theming ─────────────────────────────────────
info "Installing Qt/GTK dark-mode dependencies..."
# dconf-gsettings-backend: required for gsettings to persist GTK color-scheme changes
# qt6ct / qt5ct: QT_QPA_PLATFORMTHEME backend for Qt dark mode in standalone WMs
install_packages dconf-cli dconf-gsettings-backend
install_packages qt6ct 2>/dev/null || install_packages qt5ct 2>/dev/null \
    || warn "Neither qt6ct nor qt5ct found in repos — Qt apps may not respect dark mode."
ok "Qt/GTK theming dependencies installed."

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

if [ -d "$REPO_DIR/config/polybar/fonts" ]; then
    cp -r "$REPO_DIR/config/polybar/fonts/"* "$FONT_DIR/"
fi
fc-cache -f >/dev/null 2>&1
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font available."
else
    warn "JetBrainsMono Nerd Font NOT found by fontconfig - icons in the bar/terminal/rofi will show as boxes."
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
currentdm=""
for dm in sddm lightdm gdm3 gdm; do command -v "$dm" &>/dev/null && { currentdm="$dm"; break; }; done

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
echo "  Full reference: docs/src/keybinds.md or SUPER+/ in dwm"
echo ""
