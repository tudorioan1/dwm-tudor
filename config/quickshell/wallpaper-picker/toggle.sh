#!/bin/sh
DIR="$HOME/.config/quickshell/wallpaper-picker"
pkill -f "^[^ ]*quickshell .*wallpaper-picker" && exit 0
exec quickshell -d -p "$DIR"
