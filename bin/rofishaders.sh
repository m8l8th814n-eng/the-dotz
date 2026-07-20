#!/usr/sbin/bash
PROMPT="hyprshade on"

hyprctl eval 'hl.config({ debug = { damage_tracking = 0 } })' >/dev/null 2>&1

# Bara riktiga screen-shaders: samplar skärmen (sampler2D tex), har void main
# och saknar #include. Sållar bort Hyprlands interna shaders (surface, quad,
# border, shadow ...) som annars ger "shader could not be found"-fel.
list_shaders() {
    shopt -s nullglob
    local files=(
        ~/.config/hypr/shaders/*.frag ~/.config/hypr/shaders/*.glsl
        /usr/share/hyprshade/shaders/*.frag /usr/share/hyprshade/shaders/*.glsl
    )
    [ "${#files[@]}" -gt 0 ] || return
    awk '
        FNR==1 && NR>1 { emit() }
        FNR==1 { file=FILENAME; inc=0; tex=0; mn=0 }
        /#include|ALLOW_INCLUDES/ { inc=1 }
        /uniform[ \t]+sampler2D[ \t]+tex/ { tex=1 }
        /void[ \t]+main/ { mn=1 }
        END { emit() }
        function emit(){ if(!inc && tex && mn){ n=file; sub(/.*\//,"",n); sub(/\.[^.]*$/,"",n); print n } }
    ' "${files[@]}" 2>/dev/null | sort -u
}

while :; do
    mapfile -t shaders < <(list_shaders)
    current="$(hyprshade current 2>/dev/null)"

    menu=""
    for s in "${shaders[@]}"; do
        [ "$s" = "$current" ] && menu+="● $s"$'\n' || menu+="○ $s"$'\n'
    done
    menu+="turn shader off"$'\n'
    menu+="⏻ quitto"

    header="hyprshade"
    [ -n "$current" ] && header="hyprshade — now: $current"

    choice="$(printf '%s' "$menu" | rofi -dmenu -i -p "$PROMPT" -mesg "$header")"
    [ -n "$choice" ] || exit 0

    case "$choice" in
        "⏻ quitto")        exit 0 ;;
        "turn shader off") hyprshade off ;;
        *)                 hyprshade on "${choice#* }" ;;
    esac
done
