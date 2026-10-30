#!/bin/bash
# ─────────────────────────────────────────────────────────
# dwm-tudor — optional steps asked at the end of the installers.
# Sourced by install-arch.sh / install-debian.sh / install-fedora.sh.
#
# The caller provides info / ok / warn and (for the GTK step) a distro-specific
# install_gtk_theme_packages() (Papirus + the build prerequisites of the Materia theme).
# Every public function returns 0: a skipped or failed optional step never aborts the installer.
# ─────────────────────────────────────────────────────────

# confirm "<question>": yes by default (just press Enter). With no terminal (piped or
# unattended run) the answer is no, so nothing optional happens silently.
confirm() {
    [ -t 0 ] || return 1
    local reply
    read -r -p "$1 [Y/n] " reply
    case "$reply" in [nN]*) return 1 ;; *) return 0 ;; esac
}

# ═════════════════════════ Backup of your existing files ═════════════════════════
# Everything the installer (make install) or the optional steps below may overwrite or edit is
# copied first to ~/backup-files/<date-time>/, keeping its path relative to your home. It is a
# COPY, not a move: ~/.config/dwm-tudor (your hotkeys, themes, rules) is preserved by
# `make install`, so moving it away would reset your settings. Symlinked dotfiles are
# followed (-L): make install writes THROUGH a symlink, so the real files need saving.
BACKUP_ROOT="${DWM_BACKUP_ROOT:-$HOME/backup-files}"
BACKUP_DIR=""

_backup_candidates() {
    cat <<'EOF'
.xinitrc
.bashrc
.gtkrc-2.0
.icons/default/index.theme
.config/alacritty
.config/kitty
.config/ghostty
.config/polybar
.config/rofi
.config/dunst
.config/picom
.config/quickshell
.config/dwm-tudor
.config/gtk-3.0/settings.ini
.config/gtk-4.0/settings.ini
.config/qt5ct
.config/qt6ct
EOF
}

backup_user_files() {
    local rel list=() stamp
    while IFS= read -r rel; do
        if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then list+=("$rel"); fi
    done < <(_backup_candidates)
    if [ "${#list[@]}" -eq 0 ]; then
        info "No existing configuration to back up."
        return 0
    fi
    stamp="$(date +%Y-%m-%d_%H-%M-%S)"
    BACKUP_DIR="$BACKUP_ROOT/$stamp"
    if ! mkdir -p "$BACKUP_DIR"; then
        warn "Could not create $BACKUP_DIR - continuing without a backup."
        BACKUP_DIR=""
        return 0
    fi
    for rel in "${list[@]}"; do
        ( cd "$HOME" && { cp -aL --parents "$rel" "$BACKUP_DIR/" 2>/dev/null || cp -a --parents "$rel" "$BACKUP_DIR/"; } ) \
            || warn "Could not back up ~/$rel"
    done
    echo ""
    ok "Your original files that the installer will change were backed up to: $BACKUP_DIR"
    printf '      ~/%s\n' "${list[@]}"
    echo ""
    return 0
}

# ═════════════════════════ Bash prompt ═════════════════════════
setup_bash_prompt() {
    local dir="$HOME/mybash"
    echo ""
    if ! confirm "Do you want to install my customised bash prompt ?"; then
        info "Skipping the bash prompt."
        return 0
    fi
    if [ -d "$dir/.git" ]; then
        info "$dir already exists - updating it."
        git -C "$dir" pull --ff-only || warn "Could not update $dir - using the existing copy."
    elif [ -e "$dir" ]; then
        warn "$dir exists but is not a git checkout - skipping the bash prompt."
        return 0
    else
        git clone https://github.com/tudorioan1/mybash.git "$dir" \
            || { warn "Could not clone mybash."; return 0; }
    fi
    if [ ! -f "$dir/install.sh" ]; then
        warn "$dir/install.sh not found - skipping the bash prompt."
        return 0
    fi
    chmod +x "$dir/install.sh"
    if ( cd "$dir" && ./install.sh ); then
        ok "Bash prompt installed."
    else
        warn "The mybash installer reported an error."
    fi
    return 0
}

# ═════════════════════════ Default browser ═════════════════════════
# Lists the web browsers installed on this system as: <desktop id> TAB <name> TAB <command>.
# Browsers are recognised the standard way, by Categories=WebBrowser in their .desktop file
# (native, Flatpak and Snap), so it works the same on every distro. Terminal browsers,
# hidden entries and web-app launchers are skipped.
_scan_browsers() {
    local dirs=() xdg_dirs d f id seen=" " row ex cmd
    dirs+=("${XDG_DATA_HOME:-$HOME/.local/share}/applications")
    IFS=: read -ra xdg_dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for d in "${xdg_dirs[@]}"; do dirs+=("$d/applications"); done
    dirs+=("/var/lib/flatpak/exports/share/applications"
           "$HOME/.local/share/flatpak/exports/share/applications"
           "/var/lib/snapd/desktop/applications")
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        for f in "$d"/*.desktop; do
            [ -f "$f" ] || continue
            id="$(basename "$f")"
            case "$seen" in *" $id "*) continue ;; esac
            row="$(awk '
                /^\[/ { in_entry = ($0 == "[Desktop Entry]"); next }
                !in_entry { next }
                /^Name=/ && nm == "" { nm = substr($0, 6) }
                /^Exec=/ && ex == "" { ex = substr($0, 6) }
                /^Categories=/ { cats = $0 }
                /^(NoDisplay|Hidden|Terminal)=true/ { skip = 1 }
                END { if (cats ~ /WebBrowser/ && !skip && nm != "" && ex != "") printf "%s\t%s\n", nm, ex }
            ' "$f")"
            [ -n "$row" ] || continue
            seen="$seen$id "
            ex="${row#*$'\t'}"
            # drop the desktop-entry field codes (%u %U ...) and Flatpak's @@u ... @@ markers
            cmd="$(printf '%s' "$ex" | sed -E 's/@@u?//g; s/%[A-Za-z]//g; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
            printf '%s\t%s\t%s\n' "$id" "${row%%$'\t'*}" "$cmd"
        done
    done
}

# Point the `browser` variable of hotkeys.toml at the chosen command. SUPER+B uses it.
_hotkeys_set_browser() {
    local cmd="$1" name="$2" esc
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/dwm-tudor/hotkeys.toml"
    if [ ! -f "$file" ]; then
        warn "$file not found - set  browser = \"$cmd\"  in its [vars] section yourself."
        return 0
    fi
    if ! grep -q '^browser[[:space:]]*=' "$file"; then
        warn "No 'browser' variable in $file - set it by hand: browser = \"$cmd\""
        return 0
    fi
    esc="${cmd//\\/\\\\}"; esc="${esc//\"/\\\"}"                  # TOML string escaping
    esc="$(printf '%s' "$esc" | sed -e 's/[\\&|]/\\&/g')"          # sed replacement escaping
    sed -i -E "s|^browser[[:space:]]*=.*|browser = \"${esc}\"|" "$file"
    # exec=[...] runs ONE program; cmd="..." goes through sh, so commands with arguments
    # (flatpak run ..., snap run ...) work too.
    sed -i -E '/mod="SUPER",[[:space:]]*key="b"/ s/exec=\["\$browser"\]/cmd="$browser"/' "$file"
    ok "SUPER+B now opens $name."
}

setup_default_browser() {
    local ids=() names=() cmds=() id name cmd i choice=""
    echo ""
    while IFS=$'\t' read -r id name cmd; do
        ids+=("$id"); names+=("$name"); cmds+=("$cmd")
    done < <(_scan_browsers)
    if [ "${#ids[@]}" -eq 0 ]; then
        info "No web browser found - skipping the default browser step."
        return 0
    fi
    if [ ! -t 0 ]; then
        info "Not interactive - keeping the current browser setting."
        return 0
    fi
    echo "What web browser should be the default one ?"
    for i in "${!ids[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${names[$i]}"; done
    echo "  0) Keep the current setting"
    while true; do
        read -r -p "Choice [0-${#ids[@]}, Enter = keep]: " choice || choice=""
        if [ -z "$choice" ] || [ "$choice" = "0" ]; then
            info "Keeping the current browser setting."
            return 0
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#ids[@]}" ]; then
            break
        fi
        warn "Please type a number between 0 and ${#ids[@]}."
    done
    id="${ids[$((choice - 1))]}"; name="${names[$((choice - 1))]}"; cmd="${cmds[$((choice - 1))]}"

    # 1) system-wide default: links in other apps, xdg-open, ...
    if command -v xdg-settings &>/dev/null && xdg-settings set default-web-browser "$id" 2>/dev/null; then
        ok "System default browser: $name."
    elif command -v xdg-mime &>/dev/null \
         && xdg-mime default "$id" x-scheme-handler/http x-scheme-handler/https text/html 2>/dev/null; then
        ok "System default browser: $name."
    else
        warn "Could not set the system default browser (xdg-utils missing?)."
    fi
    # 2) the SUPER+B keybind
    _hotkeys_set_browser "$cmd" "$name"
    return 0
}

# ═════════════════════════ GTK look ═════════════════════════
# Is a theme / icon / cursor theme installed? <themes|icons> <name>
_theme_dir_exists() {
    local d
    for d in "$HOME/.local/share/$1/$2" "$HOME/.$1/$2" "/usr/share/$1/$2" "/usr/local/share/$1/$2"; do
        [ -d "$d" ] && return 0
    done
    return 1
}

# Bibata cursor: official method from the project's README - download the release archive of
# the variant and unpack it into ~/.local/share/icons. The release has one archive per variant
# (Bibata-Modern-Ice.tar.xz, Bibata-Modern-Classic.tar.xz, ...), there is no all-in-one file.
_fetch_bibata() {
    local name="$1" dest="$HOME/.local/share/icons" tmp
    local url="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/${name}.tar.xz"
    _theme_dir_exists icons "$name" && return 0
    if ! command -v curl &>/dev/null || ! command -v xz &>/dev/null; then
        warn "curl and xz are needed to install the Bibata cursor - skipping it."
        return 0
    fi
    info "Downloading the Bibata cursor ($name) from GitHub..."
    tmp="$(mktemp -d)"
    if curl -fL --retry 3 -o "$tmp/$name.tar.xz" "$url" \
       && mkdir -p "$dest" && tar -xJf "$tmp/$name.tar.xz" -C "$dest" \
       && _theme_dir_exists icons "$name"; then
        ok "$name installed in $dest."
    else
        warn "Could not install $name. Download $name.tar.xz from https://github.com/ful1e5/Bibata_Cursor/releases and unpack it into $dest"
    fi
    rm -rf "$tmp"
    return 0
}

# Materia GTK theme: built from the official GitHub repository with Meson, exactly as its
# INSTALL.md describes, into the user's ~/.local (no sudo needed). The distro packages are not
# an option: the name differs per distro and Fedora does not ship it. Needs meson, ninja and
# npm (or dart-sass), which install_gtk_theme_packages() provides.
_install_materia() {
    local name="$1" tmp log
    # both variants are needed: theme-apply.sh switches Materia-dark <-> Materia-light with the theme
    if _theme_dir_exists themes "$name" && _theme_dir_exists themes "Materia-light"; then return 0; fi
    if ! command -v git &>/dev/null || ! command -v meson &>/dev/null; then
        warn "git and meson are needed to build the $name theme - skipping it."
        return 0
    fi
    info "Building the Materia GTK theme from GitHub (takes about a minute)..."
    tmp="$(mktemp -d)"
    log="$tmp/build.log"
    if git clone --depth 1 https://github.com/nana-4/materia-theme "$tmp/materia-theme" >"$log" 2>&1 \
       && ( cd "$tmp/materia-theme" \
            && meson setup _build -Dprefix="$HOME/.local" -Dcolors=dark,light -Dsizes=default \
            && meson install -C _build ) >>"$log" 2>&1 \
       && _theme_dir_exists themes "$name"; then
        ok "$name installed in ~/.local/share/themes."
    else
        warn "Could not build $name. End of the build log:"
        tail -n 12 "$log" | sed 's/^/    /'
        warn "Manual instructions: https://github.com/nana-4/materia-theme/blob/master/INSTALL.md"
    fi
    rm -rf "$tmp"
    return 0
}

# set or add key=value in the [Settings] group of a GTK ini file, keeping everything else
_ini_set() {
    local file="$1" key="$2" value="$3"
    mkdir -p "$(dirname "$file")"
    if [ ! -f "$file" ]; then
        printf '[Settings]\n%s=%s\n' "$key" "$value" > "$file"
    elif grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    elif grep -q '^\[Settings\]' "$file"; then
        sed -i "/^\[Settings\]/a ${key}=${value}" "$file"
    else
        printf '\n[Settings]\n%s=%s\n' "$key" "$value" >> "$file"
    fi
}

# same for ~/.gtkrc-2.0 (key="value" lines)
_gtkrc_set() {
    local file="$HOME/.gtkrc-2.0" key="$1" value="$2"
    if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$file"
    else
        printf '%s="%s"\n' "$key" "$value" >> "$file"
    fi
}

# best effort: also tell GSettings (GTK4 apps, Flatpaks, portals). Uses a throw-away session
# bus when the installer runs from a TTY without one.
_gsettings_set() {
    command -v gsettings &>/dev/null || return 0
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null || true
    elif command -v dbus-run-session &>/dev/null; then
        dbus-run-session -- gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null || true
    fi
    return 0
}

setup_gtk_look() {
    local theme="Materia-dark" icons="Papirus-Dark" cursor="Bibata-Modern-Ice"
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" ini set_list=""
    echo ""
    if ! confirm "Do you want to set the GTK look ($theme theme, $icons icons, $cursor cursor)? If not, your current GTK theme, icons and cursor stay as they are."; then
        info "Leaving the GTK theme, icons and cursor as they are."
        return 0
    fi

    # Papirus comes from the distro packages (same name everywhere); the hook also installs what
    # the Materia build needs. Materia and Bibata are fetched from their official GitHub projects.
    if declare -F install_gtk_theme_packages >/dev/null; then
        install_gtk_theme_packages || warn "Some GTK packages could not be installed."
    fi
    _install_materia "$theme"
    _fetch_bibata "$cursor"

    # only apply the parts that are really installed
    if _theme_dir_exists themes "$theme"; then
        for ini in "$cfg/gtk-3.0/settings.ini" "$cfg/gtk-4.0/settings.ini"; do _ini_set "$ini" gtk-theme-name "$theme"; done
        _gtkrc_set gtk-theme-name "$theme"
        _gsettings_set gtk-theme "$theme"
        set_list="$set_list $theme"
    else
        warn "GTK theme $theme is not installed - leaving the GTK theme as it is."
    fi
    if _theme_dir_exists icons "$icons"; then
        for ini in "$cfg/gtk-3.0/settings.ini" "$cfg/gtk-4.0/settings.ini"; do _ini_set "$ini" gtk-icon-theme-name "$icons"; done
        _gtkrc_set gtk-icon-theme-name "$icons"
        _gsettings_set icon-theme "$icons"
        set_list="$set_list $icons"
    else
        warn "Icon theme $icons is not installed - leaving the icons as they are."
    fi
    if _theme_dir_exists icons "$cursor"; then
        for ini in "$cfg/gtk-3.0/settings.ini" "$cfg/gtk-4.0/settings.ini"; do _ini_set "$ini" gtk-cursor-theme-name "$cursor"; done
        _gtkrc_set gtk-cursor-theme-name "$cursor"
        _gsettings_set cursor-theme "$cursor"
        # X11 cursor for everything that is not GTK (dwm's root window, Qt, Xlib apps)
        mkdir -p "$HOME/.icons/default"
        printf '[Icon Theme]\nName=Default\nComment=Default Cursor Theme\nInherits=%s\n' "$cursor" \
            > "$HOME/.icons/default/index.theme"
        set_list="$set_list $cursor"
    else
        warn "Cursor theme $cursor is not installed - leaving the cursor as it is."
    fi
    if [ -n "$set_list" ]; then
        set_list="${set_list# }"
        ok "GTK look set: ${set_list// /, }"
        info "Change it later with nwg-look; it is kept across restarts (theme-apply.sh only syncs dark/light mode)."
    fi
    return 0
}
