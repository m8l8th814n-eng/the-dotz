#!/usr/bin/env bash
if pkill -x wvkbd-deskintl; then
    exit 0
fi
setsid wv.sh >/dev/null 2>&1 < /dev/null &
disown
