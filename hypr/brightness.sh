#!/bin/bash
# Use a lockfile to prevent overlapping ddcutil calls
LOCKFILE="/tmp/brightness_adjusting"

if [ -f "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
# Adjusting both buses in the background
ddcutil -b 3 setvcp 10 "$1" 10 --noverify & 
ddcutil -b 6 setvcp 10 "$1" 10 --noverify &
wait
rm "$LOCKFILE"
