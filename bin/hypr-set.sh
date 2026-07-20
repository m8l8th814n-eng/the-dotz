#!/usr/bin/env bash
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: ${0##*/} <keyword> <value>   ex: decoration:rounding 12" >&2; exit 1; }

kw=$1 val=$2

if [[ $val =~ ^-?[0-9]+(\.[0-9]+)?$ || $val == true || $val == false ]]; then
    lit=$val
else
    lit="\"$val\""
fi

IFS=: read -ra parts <<< "$kw"
expr=$lit
for (( i=${#parts[@]}-1; i>=0; i-- )); do
    expr="{ ${parts[i]} = $expr }"
done

hyprctl eval "hl.config($expr)" >/dev/null
hyprctl getoption "$kw"
