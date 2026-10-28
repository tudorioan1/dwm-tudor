#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# NOTE: scripts/dwm-utils.sh currently only resolves PKG_CMD to
# paru/yay/pacman and never defines DISTRO_NAME, so it isn't sourced
# here. This script is self-contained until dwm-utils.sh gets a
# Fedora/dnf branch.

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
source "$REPO_DIR/scripts/post-install.sh"

command -v dnf &>/dev/null || { err "This installer requires Fedora/RHEL (dnf not found)."; exit 1; }

PKG_CMD="dnf"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-Fedora/RHEL}"
else
    DISTRO_NAME="Fedora/RHEL"
fi

# Packages that could not be installed; listed in a summary at the end of the run.
FAILED_PKGS=()

# Install a batch; if dnf rejects the batch because ONE package is unknown, retry one
# by one so a single missing package no longer aborts the whole install.
# Returns non-zero if anything failed, and remembers what in FAILED_PKGS.
install_packages() {
    sudo dnf install -y "$@" && return 0
    if [ "$#" -eq 1 ]; then
        warn "Could not install: $1"
        FAILED_PKGS+=("$1")
        return 1
    fi
    warn "Batch install failed - retrying package by package..."
    local p rc=0
    for p in "$@"; do
        sudo dnf install -y "$p" || { warn "Could not install: $p"; FAILED_PKGS+=("$p"); rc=1; }
    done
    return $rc
}

# try_install <pkg>...: quiet attempt with no bookkeeping, for "official repo first,
# then somewhere else" fallbacks.
try_install() { sudo dnf install -y "$@" 2>/dev/null; }

# install_any <pkg> [<alternative>...]: install the first one that works (e.g. qt6ct, else
# qt5ct). Only counts as a failure if none of them can be installed.
install_any() {
    local p
    for p in "$@"; do
        if sudo dnf install -y "$p" 2>/dev/null; then return 0; fi
    done
    warn "Could not install any of: $*"
    FAILED_PKGS+=("$1")
    return 1
}

# (confirm() comes from scripts/post-install.sh)
# install_from_copr <copr> <pkg>...: enable a third-party COPR (after asking) and install from it.
install_from_copr() {
    local copr="$1"; shift
    if ! confirm "Enable the third-party COPR '$copr' to install: $*?"; then
        warn "Skipped: $*  (enable it later with: sudo dnf copr enable $copr)"
        FAILED_PKGS+=("$@")
        return 1
    fi
    install_any dnf5-plugins dnf-plugins-core >/dev/null || true   # provides `dnf copr`
    if ! sudo dnf -y copr enable "$copr"; then
        warn "Could not enable COPR $copr (not available for this Fedora release?)."
        FAILED_PKGS+=("$@")
        return 1
    fi
    install_packages "$@" && ok "Installed from COPR $copr: $*"
}

# Packages for the optional GTK look (used by setup_gtk_look in scripts/post-install.sh)
install_gtk_theme_packages() { install_packages materia-gtk-theme papirus-icon-theme; }

BG_DIR="$HOME/Pictures/backgrounds"
FONT_DIR="$HOME/.local/share/fonts"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║        dwm-tudor Installer (Fedora)       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Package manager: $PKG_CMD"

# ── Build dependencies ───────────────────────────────────
info "Installing build dependencies..."
install_packages gcc make pkgconf-pkg-config \
    libX11-devel libXft-devel libXinerama-devel imlib2-devel \
    libxcb-devel xcb-util-devel freetype-devel fontconfig-devel

if rpm -qa 2>/dev/null | grep -qi '^xlibre'; then
    info "Xlibre detected — skipping xorg-x11-server-Xorg."
elif ! rpm -q xorg-x11-server-Xorg &>/dev/null; then
    install_packages xorg-x11-server-Xorg
fi
install_packages xorg-x11-xinit xrandr xsetroot xset
ok "Build dependencies installed."

# ── Runtime dependencies ─────────────────────────────────
info "Installing runtime dependencies..."
if install_packages rofi picom dunst feh flameshot papirus-icon-theme dex-autostart mate-polkit alsa-utils git curl unzip xz xclip \
    xprop thunar gvfs tumbler thunar-archive-plugin xdg-user-dirs \
    xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring NetworkManager network-manager-applet \
    libnotify rsync xdotool setxkbmap
then
    ok "Runtime dependencies installed."
else
    warn "Some runtime dependencies could not be installed (listed at the end)."
fi

# quickshell (wallpaper picker): official repos first (Rawhide / newer releases), then the
# COPR that upstream recommends for Fedora. Qt QML modules come with qt6-qtdeclarative.
try_install quickshell || install_from_copr errornointernet/quickshell quickshell || true

# Fedora's dex-autostart package ships the binary as `dex-autostart`,
# not `dex` (Arch's `dex` package ships `dex`). Anything in this repo's
# autostart chain that calls `dex` directly (e.g. `dex -a -s
# ~/.config/autostart/`, the usual way nm-applet/mate-polkit get fired
# via their XDG .desktop entries) would silently no-op on Fedora
# without this. Cheap to add even if it turns out unused.
if command -v dex-autostart &>/dev/null && ! command -v dex &>/dev/null; then
    info "Fedora ships dex-autostart's binary as 'dex-autostart', not 'dex' — adding a compatibility symlink."
    sudo ln -sf "$(command -v dex-autostart)" /usr/local/bin/dex
    ok "Symlinked /usr/local/bin/dex -> dex-autostart."
fi

# nwg-look isn't in the official Fedora repos — needs a COPR
try_install nwg-look || install_from_copr tofik/nwg-shell nwg-look || true

# ── Qt / GTK theming ─────────────────────────────────────
info "Installing Qt/GTK dark-mode dependencies..."
# dconf: required for gsettings to persist GTK color-scheme changes
# qt6ct / qt5ct: QT_QPA_PLATFORMTHEME backend for Qt dark mode in standalone WMs
install_packages dconf
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
install_packages google-noto-color-emoji-fonts
mkdir -p "$FONT_DIR"

# JetBrainsMono Nerd Font isn't packaged for Fedora - fetch it from upstream
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

# MesloLGS Nerd Font Mono isn't packaged for Fedora either - fetch only the Mono family
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
install_packages polybar
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
currentdm=""
for dm in sddm lightdm gdm; do command -v "$dm" &>/dev/null && { currentdm="$dm"; break; }; done

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
