#!/bin/bash
# ─────────────────────────────────────────────────────────
# resume-hook.sh — keeps the screen from staying black after suspend/resume.
#
# Why it happens: after resuming, some GPU drivers (notably NVIDIA's proprietary one) hand back
# empty video memory. picom (use-damage = true) only repaints the regions that change, so
# everything else stays black until a window triggers a redraw - which is why opening a program
# "fixes" it. The wallpaper pixmap created by feh lives in video memory too.
#
# What it does: listens for systemd-logind's PrepareForSleep signal and, once the machine is
# back, wakes the display, re-creates the wallpaper (~/.fehbg), RESTARTS picom with the very
# same command line it was running with (SIGUSR1 / a config reload was not enough: its GL state
# does not survive the suspend) and forces an expose of every window.
# Started from autostart.sh. Needs gdbus (glib) or dbus-monitor.
# ─────────────────────────────────────────────────────────

# Restart picom exactly as it was started (same flags, same binary). Does nothing if picom is not
# running: it never starts a compositor the user does not use.
restart_picom() {
    local pid i
    local -a args=()
    pid="$(pgrep -u "$(id -u)" -x picom | head -n1)"
    if [ -z "$pid" ]; then return 0; fi
    mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null
    if [ "${#args[@]}" -eq 0 ]; then args=(picom -b --backend glx); fi
    pkill -u "$(id -u)" -x picom 2>/dev/null
    for i in $(seq 1 25); do                  # wait (max 5 s) until it is really gone
        pgrep -u "$(id -u)" -x picom >/dev/null 2>&1 || break
        sleep 0.2
    done
    "${args[@]}" >/dev/null 2>&1 &
    return 0
}

fix_display() {
    sleep 2                                   # give the GPU/driver time to come back
    xset dpms force on 2>/dev/null
    if [ -x "$HOME/.fehbg" ]; then "$HOME/.fehbg" >/dev/null 2>&1; fi   # wallpaper first, picom reads it
    restart_picom
    if command -v xrefresh >/dev/null 2>&1; then sleep 1; xrefresh 2>/dev/null; fi
    return 0
}

# Prints the raw logind signal stream (gdbus preferred, dbus-monitor as fallback)
watch_logind() {
    if command -v gdbus >/dev/null 2>&1; then
        gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 2>/dev/null
    elif command -v dbus-monitor >/dev/null 2>&1; then
        dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>/dev/null
    else
        echo "resume-hook: neither gdbus nor dbus-monitor found - nothing to watch" >&2
        return 1
    fi
}

# Reads the stream on stdin; PrepareForSleep(false) means "just resumed".
handle_stream() {
    local line armed=0
    while IFS= read -r line; do
        case "$line" in
            *PrepareForSleep*"(false,)"*) fix_display & ;;                            # gdbus
            *"member=PrepareForSleep"*)   armed=1 ;;                                  # dbus-monitor: header ...
            *"boolean false"*)            if [ "$armed" = 1 ]; then fix_display & fi; armed=0 ;;   # ... then the value
            *"boolean true"*)             armed=0 ;;
        esac
    done
}

main() {
    if ! command -v gdbus >/dev/null 2>&1 && ! command -v dbus-monitor >/dev/null 2>&1; then
        echo "resume-hook: neither gdbus nor dbus-monitor found - nothing to watch" >&2
        exit 1
    fi
    while true; do
        watch_logind | handle_stream
        sleep 5          # the watcher ended (bus restarted?): start it again
    done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main; fi
