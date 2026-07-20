#!/usr/bin/env bash
# Läs ljudnivån kontinuerligt och styr blue med den.
# Avbryt med Ctrl-C; sätt sedan tillbaka en fast färg.

cleanup() {
    freakctl set green 80
    exit 0
}
trap cleanup INT TERM

while true; do
    NBR="$(./visualnumber)"
    freakctl set green "$NBR"
    sleep 0.05
done
