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

command -v dnf &>/dev/null || { err "This installer requires Fedora/RHEL (dnf not found)."; exit 1; }

PKG_CMD="dnf"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-Fedora/RHEL}"
else
    DISTRO_NAME="Fedora/RHEL"
fi

install_packages() {
    sudo dnf install -y "$@"
}

BG_DIR="$HOME/Pictures/backgrounds"
FONT_DIR="$HOME/.local/share/fonts"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║      dwm-tudor Installer (Fedora/RHEL)    ║"
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
install_packages rofi picom dunst feh flameshot dex-autostart mate-polkit alsa-utils git curl unzip xclip \
    xprop thunar gvfs tumbler thunar-archive-plugin xdg-user-dirs \
    xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring NetworkManager network-manager-applet \
    libnotify rsync
ok "Runtime dependencies installed."

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
install_packages nwg-look 2>/dev/null \
    || warn "nwg-look not in Fedora repos — install via: sudo dnf copr enable tofik/nwg-shell && sudo dnf install nwg-look"

# ── Qt / GTK theming ─────────────────────────────────────
info "Installing Qt/GTK dark-mode dependencies..."
# dconf: required for gsettings to persist GTK color-scheme changes
# qt6ct / qt5ct: QT_QPA_PLATFORMTHEME backend for Qt dark mode in standalone WMs
install_packages dconf
install_packages qt6ct 2>/dev/null || install_packages qt5ct 2>/dev/null \
    || warn "Neither qt6ct nor qt5ct found in repos — Qt apps may not respect dark mode."
ok "Qt/GTK theming dependencies installed."

# ── Fonts ────────────────────────────────────────────────
info "Installing fonts..."
install_packages google-noto-color-emoji-fonts
mkdir -p "$FONT_DIR"

# Meslo Nerd Font isn't packaged for Fedora — fetch it from upstream
if ! fc-list 2>/dev/null | grep -qi "MesloLGS Nerd Font"; then
    info "Downloading Meslo Nerd Font..."
    if curl -fsSL -o /tmp/Meslo.zip \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Meslo.zip"; then
        unzip -oq /tmp/Meslo.zip -d "$FONT_DIR"
        rm -f /tmp/Meslo.zip
    else
        warn "Failed to download Meslo Nerd Font. Get it manually from https://www.nerdfonts.com/font-downloads"
    fi
fi

if [ -d "$REPO_DIR/config/polybar/fonts" ]; then
    cp -r "$REPO_DIR/config/polybar/fonts/"* "$FONT_DIR/"
fi
fc-cache -fv >/dev/null 2>&1
ok "Fonts installed."

# ── Terminal emulator ────────────────────────────────────
terminal=""
for t in ghostty kitty alacritty; do command -v "$t" &>/dev/null && { terminal="$t"; break; }; done

if [ -n "$terminal" ]; then
    ok "Terminal already installed: $terminal"
else
    info "No supported terminal found — installing ghostty..."
    install_packages ghostty 2>/dev/null \
        || warn "ghostty not in Fedora repos — install via COPR (sudo dnf copr enable scottames/ghostty) or from https://ghostty.org"
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

# ── Autostart data-dir fix ────────────────────────────────
# dwm.c's runautostart() looks for scripts/autostart.sh under
# ~/.local/share/<dwmdir>/, where <dwmdir> is a string hardcoded in
# dwm.c. The Makefile, however, syncs the repo to
# ~/.local/share/dwm-tudor (DATA_DIR). If dwm.c still says
# dwmdir[] = "dwm-titus" (a leftover from before this repo was renamed
# from the original dwm-titus fork), dwm looks in a folder that never
# gets created and silently runs NO autostart programs at all — no
# picom, no dunst, no nm-applet. This affects Arch too; it's just easy
# to miss there if a leftover ~/.local/share/dwm-titus/ from an older
# install happens to still exist.
if grep -q 'dwmdir\[\] = "dwm-titus"' "$REPO_DIR/dwm.c" 2>/dev/null; then
    info "Patching dwm.c: autostart data dir 'dwm-titus' -> 'dwm-tudor' (to match Makefile's DATA_DIR)..."
    sed -i 's/dwmdir\[\] = "dwm-titus"/dwmdir[] = "dwm-tudor"/' "$REPO_DIR/dwm.c"
    ok "Patched dwm.c."
else
    info "dwm.c autostart dir already matches (or string not found) — skipping patch."
fi

# ── Build & Install ──────────────────────────────────────
cd "$REPO_DIR"
sudo make clean install

# Belt-and-suspenders: guarantee runautostart() can find
# scripts/autostart.sh under BOTH names, in case the patch above ever
# gets out of sync again or you're re-running against an already-built
# binary.
DATA_DIR_TUDOR="$HOME/.local/share/dwm-tudor"
DATA_DIR_TITUS="$HOME/.local/share/dwm-titus"
if [ -d "$DATA_DIR_TUDOR" ] && [ ! -e "$DATA_DIR_TITUS" ]; then
    ln -sfn "$DATA_DIR_TUDOR" "$DATA_DIR_TITUS"
    ok "Linked $DATA_DIR_TITUS -> $DATA_DIR_TUDOR for autostart compatibility."
fi

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
