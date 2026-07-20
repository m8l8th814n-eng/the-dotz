#!/usr/bin/env bash
for v in "${@:2}"; do "${0%/*}/hypr-set.sh" "$1" "$v" >/dev/null; sleep "${DELAY:-0.05}"; done
