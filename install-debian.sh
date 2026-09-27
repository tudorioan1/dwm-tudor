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

install_packages() {
    sudo apt-get install -y "$@"
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
    libnotify-bin rsync
ok "Runtime dependencies installed."

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

# Meslo Nerd Font isn't packaged for Debian/Ubuntu — fetch it from upstream
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
    install_packages ghostty 2>/dev/null || warn "ghostty not in Debian/Ubuntu repos — install from https://ghostty.org"
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

# ── Rofi missing font.rasi fix ────────────────────────────
# config/rofi/config/general.rasi does `@import "font"`, resolved
# against ~/.config/rofi/config/font.rasi once installed — but the repo
# never ships that file. Without it rofi refuses to launch with
# something like: "Failed to parse ... Path to file '.../config/font.rasi'
# does not exist." This is a repo bug, not Debian-specific (Arch hits it
# too, whenever @theme actually resolves down to config/general.rasi),
# but nothing patches it yet, so create it here if it's missing.
ROFI_FONT_RASI="$REPO_DIR/config/rofi/config/font.rasi"
if [ ! -f "$ROFI_FONT_RASI" ]; then
    info "config/rofi/config/font.rasi is missing — creating it..."
    cat > "$ROFI_FONT_RASI" <<'EOF'
/* font.rasi — satisfies `@import "font"` in config/general.rasi */
* {
    font: "MesloLGS Nerd Font 12";
}
EOF
    ok "Created config/rofi/config/font.rasi."
else
    ok "config/rofi/config/font.rasi already present — skipping."
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
