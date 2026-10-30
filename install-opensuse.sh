#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# NOTE: scripts/dwm-utils.sh only resolves PKG_CMD to paru/yay/pacman and never defines
# DISTRO_NAME, so it is not sourced here. This script is self-contained, like the Debian and
# Fedora ones.

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
source "$REPO_DIR/scripts/post-install.sh"

command -v zypper &>/dev/null || { err "This installer requires openSUSE (zypper not found)."; exit 1; }

PKG_CMD="zypper"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-openSUSE}"
else
    DISTRO_NAME="openSUSE"
fi

# Packages that could not be installed; listed in a summary at the end of the run.
FAILED_PKGS=()

# Install a batch; if zypper rejects the batch because ONE package is unknown, retry one
# by one so a single missing package no longer aborts the whole install.
# Returns non-zero if anything failed, and remembers what in FAILED_PKGS.
install_packages() {
    sudo zypper --non-interactive install --auto-agree-with-licenses "$@" && return 0
    if [ "$#" -eq 1 ]; then
        warn "Could not install: $1"
        FAILED_PKGS+=("$1")
        return 1
    fi
    warn "Batch install failed - retrying package by package..."
    local p rc=0
    for p in "$@"; do
        sudo zypper --non-interactive install --auto-agree-with-licenses "$p" || { warn "Could not install: $p"; FAILED_PKGS+=("$p"); rc=1; }
    done
    return $rc
}

# try_install <pkg>...: quiet attempt with no bookkeeping, for "official repo first,
# then somewhere else" fallbacks.
try_install() { sudo zypper --non-interactive install --auto-agree-with-licenses "$@" >/dev/null 2>&1; }

# install_any <pkg> [<alternative>...]: install the first one that works (e.g. qt6ct, else
# qt5ct). Only counts as a failure if none of them can be installed.
install_any() {
    local p
    for p in "$@"; do
        if sudo zypper --non-interactive install --auto-agree-with-licenses "$p" 2>/dev/null; then return 0; fi
    done
    warn "Could not install any of: $*"
    FAILED_PKGS+=("$1")
    return 1
}

# (confirm() comes from scripts/post-install.sh)
# install_from_obs <repo-url> <pkg>...: add a third-party Open Build Service repository (after
# asking) and install from it.
install_from_obs() {
    local url="$1"; shift
    if ! confirm "Add the third-party OBS repository $url to install: $*?"; then
        warn "Skipped: $*  (add it later with: sudo zypper addrepo $url)"
        FAILED_PKGS+=("$@")
        return 1
    fi
    sudo zypper --non-interactive --gpg-auto-import-keys addrepo --refresh "$url" >/dev/null 2>&1 || true   # may already exist
    if ! sudo zypper --non-interactive --gpg-auto-import-keys refresh; then
        warn "Could not refresh the repositories after adding $url."
        FAILED_PKGS+=("$@")
        return 1
    fi
    install_packages "$@" && ok "Installed from $url: $*"
}

# Packages for the optional GTK look (used by setup_gtk_look in scripts/post-install.sh): the
# Papirus icons, plus what building Materia from its GitHub repo needs (Meson, Ninja, npm for
# Sass, and the GTK2 engine + base themes it relies on). Materia and Bibata themselves are not
# packages: they are fetched from GitHub.
install_gtk_theme_packages() {
    install_packages papirus-icon-theme meson ninja gtk2-engine-murrine
    install_any npm-default npm24 npm22 npm20
}

BG_DIR="$HOME/Pictures/backgrounds"
FONT_DIR="$HOME/.local/share/fonts"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║        dwm-tudor Installer (openSUSE)     ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Package manager: $PKG_CMD"

# ── Build dependencies ───────────────────────────────────
info "Installing build dependencies..."
# The libraries are requested as pkg-config capabilities: zypper resolves them to the matching
# -devel packages, so this does not depend on openSUSE's package names.
install_packages gcc make pkg-config \
    'pkgconfig(x11)' 'pkgconfig(xft)' 'pkgconfig(xinerama)' 'pkgconfig(imlib2)' \
    'pkgconfig(xcb)' 'pkgconfig(xcb-util)' 'pkgconfig(xcb-res)' 'pkgconfig(x11-xcb)' \
    'pkgconfig(freetype2)' 'pkgconfig(fontconfig)'

if rpm -qa 2>/dev/null | grep -qi '^xlibre'; then
    info "Xlibre detected — skipping xorg-x11-server."
elif ! rpm -q xorg-x11-server &>/dev/null; then
    install_packages xorg-x11-server
fi
install_packages xinit xrandr xsetroot xset
ok "Build dependencies installed."

# ── Runtime dependencies ─────────────────────────────────
info "Installing runtime dependencies..."
if install_packages rofi picom dunst feh flameshot papirus-icon-theme dex mate-polkit alsa-utils git curl unzip xz xclip \
    xprop gvfs tumbler thunar-plugin-archive xdg-user-dirs \
    xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring NetworkManager NetworkManager-applet \
    libnotify-tools rsync xdotool setxkbmap
then
    ok "Runtime dependencies installed."
else
    warn "Some runtime dependencies could not be installed (listed at the end)."
fi

# File manager: the package is called Thunar on openSUSE
install_any Thunar thunar || true

# quickshell (wallpaper picker): official repos first, then the Open Build Service repository
# that ships it for Tumbleweed/Slowroll (asks first). The QML modules it imports come from
# qt6-declarative-imports.
case "${ID:-}" in opensuse-slowroll) OBS_DIST="openSUSE_Slowroll" ;; *) OBS_DIST="openSUSE_Tumbleweed" ;; esac
install_packages qt6-declarative-imports || true
try_install quickshell || install_from_obs "https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/$OBS_DIST/home:AvengeMedia:danklinux.repo" quickshell || true

# nwg-look (GTK settings app): not in every openSUSE repo
if ! try_install nwg-look; then
    warn "nwg-look is not in your openSUSE repositories - build it from https://github.com/nwg-piotr/nwg-look (Go) or use lxappearance."
    FAILED_PKGS+=("nwg-look")
fi

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
install_any noto-coloremoji-fonts google-noto-coloremoji-fonts || warn "No colour emoji font package found - emoji may be missing."
mkdir -p "$FONT_DIR"

# JetBrainsMono Nerd Font isn't packaged for openSUSE - fetch it from upstream
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

# MesloLGS Nerd Font Mono isn't packaged for openSUSE either - fetch only the Mono family
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
for dm in sddm lightdm gdm; do
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

# ── Back up the files this install is about to change ─────
backup_user_files

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
if [ -n "${BACKUP_DIR:-}" ]; then
    info "Your previous files were backed up to: $BACKUP_DIR"
fi
echo "  • Edit config.h to customize, then: make && sudo make install"
echo "  • Log out and select 'dwm', or start with: startx"
echo ""
echo "  SUPER+/   keybind viewer     SUPER+X  terminal"
echo "  SUPER+F1  control center     SUPER+R  app launcher (rofi)"
echo "  SUPER+Q   close window"
echo ""
echo "  Full keybind reference: press SUPER+/ in dwm (reads ~/.config/dwm-tudor/hotkeys.toml)"
echo ""
