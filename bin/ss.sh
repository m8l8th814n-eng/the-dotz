#!/bin/bash
# Omarchy-style screensaver. Bind it however you like.
hyprshade on crt
TXT="/home/simon/backgrounds/ss.png"

if [ ! -f "$TXT" ]; then
    echo "ss.sh: missing $TXT" >&2
    #exit 1
fi

if [ "$1" != "--inner" ]; then
    exec foot --app-id=not-omarchy --fullscreen -- "$0" --inner
fi

cleanup() {
    [ -n "$TTE_PID" ] && kill "$TTE_PID" 2>/dev/null
    printf '\033[?25h'
    exit 0
}
trap cleanup SIGINT SIGTERM SIGHUP SIGQUIT EXIT

printf '\033]11;rgb:00/00/00\007'
printf '\033[?25l'
clear

while true; do
  	jp2a -z --colors /home/simon/backgrounds/ss.png |tte \
        --frame-rate 120 --existing-color-handling always  \
        --reuse-canvas --anchor-canvas c --anchor-text c \
        --random-effect \
        --no-eol --no-restore-cursor &
    TTE_PID=$!

    while kill -0 "$TTE_PID" 2>/dev/null; do
        if read -rsn1 -t 1; then
            cleanup
        fi
    done
done
hyprshade off

