#!/bin/bash

# .xinitrc — only used when starting dwm via startx (not SDDM)
# Autostart (DPMS, dbus env, picom, dunst, polybar, etc.) is launched
# explicitly here — NOT via dwm's own built-in autostart patch, since that
# doesn't reliably fire on every setup.

AUTOSTART="${XDG_DATA_HOME:-$HOME/.local/share}/dwm-titus/scripts/autostart.sh"
[ -x "$AUTOSTART" ] && "$AUTOSTART" &

dbus-run-session -- sh -c 'exec dwm'
