#!/bin/bash

# Citește layout-ul curent direct din X11
current=$(setxkbmap -query | grep layout | awk '{print $2}')

case "$current" in
    ro) setxkbmap us ;;
    us) setxkbmap ro ;;
    *)  setxkbmap us ;;  # fallback
esac
