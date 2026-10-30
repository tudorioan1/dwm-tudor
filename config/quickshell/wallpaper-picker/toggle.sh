#!/bin/sh
# Deschide selectorul; daca e deja deschis, il inchide.
DIR="$HOME/.config/quickshell/wallpaper-picker"
# Ancorat pe numele binarului, ca sa nu se potriveasca cu scriptul insusi
pkill -f "^[^ ]*quickshell .*wallpaper-picker" && exit 0
exec quickshell -d -p "$DIR"
