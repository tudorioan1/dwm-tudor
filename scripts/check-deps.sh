#!/bin/bash
# ─────────────────────────────────────────────────────────
# dwm-titus dependency checker — Arch Linux & Fedora
# Run before building to verify all required packages
# are installed. Exit code 0 = all good, 1 = missing deps.
# ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MISSING=0

# ── Detect distro ───────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|archarm|endeavouros|manjaro|garuda|artix)
                echo "arch"; return ;;
            fedora|rhel|centos|rocky|almalinux|nobara)
                echo "fedora"; return ;;
        esac
        case "$ID_LIKE" in
            *arch*) echo "arch"; return ;;
            *fedora*|*rhel*) echo "fedora"; return ;;
        esac
    fi
    if command -v pacman &>/dev/null; then
        echo "arch"; return
    elif command -v dnf &>/dev/null || command -v rpm &>/dev/null; then
        echo "fedora"; return
    fi
    echo "unknown"
}

DISTRO=$(detect_distro)

if [ "$DISTRO" = "unknown" ]; then
    printf "${RED}Unsupported distribution.${NC} This script supports Arch Linux and Fedora only.\n"
    exit 1
fi

# ── Generic dependency name → distro package name ───────
declare -A PKG_ARCH=(
    [libx11]="libx11"
    [libxft]="libxft"
    [libxinerama]="libxinerama"
    [imlib2]="imlib2"
    [libxcb]="libxcb"
    [xcb-util]="xcb-util"
    [freetype2]="freetype2"
    [fontconfig]="fontconfig"
)
declare -A PKG_FEDORA=(
    [libx11]="libX11-devel"
    [libxft]="libXft-devel"
    [libxinerama]="libXinerama-devel"
    [imlib2]="imlib2-devel"
    [libxcb]="libxcb-devel"
    [xcb-util]="xcb-util-devel"
    [freetype2]="freetype-devel"
    [fontconfig]="fontconfig-devel"
)

check_cmd() {
    if command -v "$1" &>/dev/null; then
        printf "  ${GREEN}✓${NC} %s\n" "$1"
    else
        printf "  ${RED}✗${NC} %s ${YELLOW}(missing)${NC}\n" "$1"
        MISSING=$((MISSING + 1))
    fi
}

# check_pkg: verify an actual (distro-specific) package name is installed
check_pkg() {
    local pkg="$1"
    if [ "$DISTRO" = "arch" ]; then
        if pacman -Qi "$pkg" &>/dev/null; then
            printf "  ${GREEN}✓${NC} %s\n" "$pkg"
        else
            printf "  ${RED}✗${NC} %s ${YELLOW}(not installed)${NC}\n" "$pkg"
            MISSING=$((MISSING + 1))
        fi
    else
        if rpm -q "$pkg" &>/dev/null; then
            printf "  ${GREEN}✓${NC} %s\n" "$pkg"
        else
            printf "  ${RED}✗${NC} %s ${YELLOW}(not installed)${NC}\n" "$pkg"
            MISSING=$((MISSING + 1))
        fi
    fi
}

# check_dep: takes a generic dependency name, resolves it to the correct
# package name for the running distro, then checks it
check_dep() {
    local generic="$1"
    local pkg
    if [ "$DISTRO" = "arch" ]; then
        pkg="${PKG_ARCH[$generic]:-$generic}"
    else
        pkg="${PKG_FEDORA[$generic]:-$generic}"
    fi
    check_pkg "$pkg"
}

check_base_devel() {
    if [ "$DISTRO" = "arch" ]; then
        if pacman -Qg base-devel &>/dev/null; then
            printf "  ${GREEN}✓${NC} base-devel\n"
        else
            printf "  ${RED}✗${NC} base-devel ${YELLOW}(not installed)${NC}\n"
            MISSING=$((MISSING + 1))
        fi
    else
        if dnf group list --installed 2>/dev/null | grep -qi "Development Tools"; then
            printf "  ${GREEN}✓${NC} Development Tools (group)\n"
        else
            printf "  ${RED}✗${NC} Development Tools ${YELLOW}(run: sudo dnf group install \"Development Tools\")${NC}\n"
            MISSING=$((MISSING + 1))
        fi
    fi
}

check_font() {
    if fc-list 2>/dev/null | command grep -qi "$1"; then
        printf "  ${GREEN}✓${NC} %s\n" "$1"
    else
        printf "  ${RED}✗${NC} %s ${YELLOW}(not found)${NC}\n" "$1"
        MISSING=$((MISSING + 1))
    fi
}

echo ""
if [ "$DISTRO" = "arch" ]; then
    echo "═══ dwm-titus Dependency Check (Arch Linux) ═══"
else
    echo "═══ dwm-titus Dependency Check (Fedora) ═══"
fi
echo ""

# ── Build dependencies ──────────────────────────────────
echo "Build Dependencies (required to compile):"
check_base_devel
for dep in libx11 libxft libxinerama imlib2 libxcb xcb-util freetype2 fontconfig; do
    check_dep "$dep"
done
check_cmd "cc"
check_cmd "make"
echo ""

# ── Xorg / Xlibre ───────────────────────────────────────
echo "X Server Components:"
if [ "$DISTRO" = "arch" ]; then
    # Accept either Xorg or Xlibre as the X server
    # Detect Xlibre by any installed xlibre-* package (server, drivers, etc.)
    if pacman -Qq 2>/dev/null | grep -q '^xlibre'; then
        xlibre_pkg=$(pacman -Qq 2>/dev/null | grep '^xlibre' | head -1)
        printf "  ${GREEN}✓${NC} Xlibre detected (%s)\n" "$xlibre_pkg"
    elif pacman -Qi xorg-server &>/dev/null; then
        printf "  ${GREEN}✓${NC} xorg-server\n"
    else
        printf "  ${RED}✗${NC} xorg-server or xlibre ${YELLOW}(not installed)${NC}\n"
        MISSING=$((MISSING + 1))
    fi
    for pkg in xorg-xinit xorg-xrandr xorg-xset xorg-xsetroot; do
        check_pkg "$pkg"
    done
else
    # Fedora: Xlibre isn't packaged upstream, but check for it just in case
    # someone built/installed it manually. xrandr/xset/xsetroot ship together
    # in xorg-x11-server-utils on Fedora, so check the binaries directly.
    if command -v Xlibre &>/dev/null; then
        printf "  ${GREEN}✓${NC} Xlibre detected\n"
    elif rpm -q xorg-x11-server-Xorg &>/dev/null; then
        printf "  ${GREEN}✓${NC} xorg-x11-server-Xorg\n"
    elif command -v Xorg &>/dev/null; then
        printf "  ${GREEN}✓${NC} Xorg binary found\n"
    else
        printf "  ${RED}✗${NC} xorg-x11-server-Xorg ${YELLOW}(not installed)${NC}\n"
        MISSING=$((MISSING + 1))
    fi
    check_cmd "startx"
    check_cmd "xrandr"
    check_cmd "xset"
    check_cmd "xsetroot"
fi

# ── Runtime dependencies ────────────────────────────────
echo "Runtime Dependencies (desktop experience):"
check_cmd "rofi"
check_cmd "picom"
check_cmd "dunst"
check_cmd "feh"
check_cmd "flameshot"
check_cmd "dex"
check_cmd "amixer"
echo ""

# ── Terminal emulators ──────────────────────────────────
echo "Terminal Emulators (at least one required):"
TERM_FOUND=0
for term in ghostty alacritty kitty st; do
    if command -v "$term" &>/dev/null; then
        printf "  ${GREEN}✓${NC} %s\n" "$term"
        TERM_FOUND=1
    fi
done
if [ $TERM_FOUND -eq 0 ]; then
    printf "  ${RED}✗${NC} No supported terminal found ${YELLOW}(install ghostty, alacritty, kitty, or st)${NC}\n"
    MISSING=$((MISSING + 1))
fi
echo ""

# ── Optional but recommended ────────────────────────────
echo "Optional (recommended):"
check_cmd "polybar"
check_cmd "xdg-open"
echo ""

# ── Fonts ───────────────────────────────────────────────
echo "Fonts:"
check_font "MesloLGS Nerd Font"
check_font "Noto Color Emoji"
echo ""

# ── Session entry ───────────────────────────────────────
echo "Session Setup:"
if [ -f /usr/share/xsessions/dwm.desktop ]; then
    printf "  ${GREEN}✓${NC} dwm.desktop in /usr/share/xsessions/\n"
else
    printf "  ${YELLOW}○${NC} dwm.desktop not found (run 'sudo make install')\n"
fi
if [ -f "$HOME/.xinitrc" ]; then
    printf "  ${GREEN}✓${NC} ~/.xinitrc exists\n"
else
    printf "  ${YELLOW}○${NC} ~/.xinitrc not found (needed for startx)\n"
fi
echo ""

# ── Summary ─────────────────────────────────────────────
if [ "$DISTRO" = "arch" ]; then
    INSTALL_HINT="sudo pacman -S <package>"
else
    INSTALL_HINT="sudo dnf install <package>"
fi

if [ $MISSING -eq 0 ]; then
    printf "${GREEN}All dependencies satisfied. Ready to build!${NC}\n"
    echo "  Run: make && sudo make install"
    exit 0
else
    printf "${RED}$MISSING missing dependency/dependencies.${NC}\n"
    echo "  Install missing packages with: $INSTALL_HINT"
    echo "  Or run: ./install.sh   (automated install)"
    exit 1
fi
echo ""
