#!/usr/bin/env bash
# Ramp: sätt green från 4 till 80 i ett svep.
# Avbryt med Ctrl-C; sätt sedan tillbaka en fast färg.

cleanup() {
    freakctl set green 81
    exit 0
}
trap cleanup INT TERM

for ((i = 4; i <= 80; i++)); do
    freakctl set green "$i" >/dev/null
    sleep 0.01
done
