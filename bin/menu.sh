#!/usr/sbin/env bash
PROMPT="hyprshade on"

die() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "rofishaders" "$1"
    fi
    echo "rofishaders: $1" >&2
    exit 1
}

hyprctl eval 'hl.config({ debug = { damage_tracking = 0 } })' >/dev/null 2>&1

list_shaders() {
    hyprshade ls 2>/dev/null | sed 's/^[[:space:]]*[*+][[:space:]]*//; s/[[:space:]]*$//' \
        | grep -v '^$' | sort -u
}

while :; do
    mapfile -t shaders < <(list_shaders)
    [ "${#shaders[@]}" -gt 0 ] || die "no shaders (hyprshade ls)"

    current="$(hyprshade current 2>/dev/null)"

    # Bygg menyn: markera aktiv shader med ●, övriga med ○.
    menu=""
    for s in "${shaders[@]}"; do
        if [ "$s" = "$current" ]; then
            menu+="● $s"$'\n'
        else
            menu+="○ $s"$'\n'
        fi
    done
    menu+="turn shader off"$'\n'
    menu+="⏻ quitto"

    header="hyprshade"
    [ -n "$current" ] && header="hyprshade — now: $current"

    choice="$(printf '%s' "$menu" | rofi -dmenu -i -p "$PROMPT" -mesg "$header")"

    # Escape / tom = avsluta
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "⏻ quitto")
            exit 0
            ;;
        "turn shader off")
            hyprshade off
            ;;
        *)
            # Ta bort statusprefixet (● / ○ + mellanslag).
            name="${choice#* }"
            hyprshade on "$name" 2>/dev/null \
                || notify-send "rofishaders" "no load man... $name" 2>/dev/null
            ;;
    esac
done
