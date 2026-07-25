#!/bin/bash

# Verificăm care este prima limbă setată în acest moment
current_layout=$(setxkbmap -query | awk '/layout/ {print $2}' | cut -d, -f1)

if [ "$current_layout" = "us" ]; then
    # Dacă e US, mutăm RO pe prima poziție
    setxkbmap -layout ro,us -variant std, -option grp:alt_shift_toggle
else
    # Dacă e RO, mutăm US pe prima poziție
    setxkbmap -layout us,ro -variant ,std -option grp:alt_shift_toggle
fi
