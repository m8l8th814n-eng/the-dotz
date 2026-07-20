#!/usr/bin/env bash
# btwatch - bevakar Bluetooth kontinuerligt och ansluter önskade enheter
# så fort de dyker upp. Återansluter automatiskt om de tappar kontakten.
#
# Konfig: lägg dina mål i TARGETS nedan. Varje post är antingen en
#   MAC-adress  (t.ex. "B8:F6:53:11:22:33")  - exakt och snabbast, eller
#   en namndel  (t.ex. "JBL")                - matchas mot enhetens namn.
#
# Kör:   ./btwatch.sh
#        ./btwatch.sh "JBL" "B8:F6:53:11:22:33"   # mål via argument
#
# Avsluta med Ctrl-C.

set -u

# --- konfiguration -------------------------------------------------------
TARGETS=( "JBL" )      # standardmål om inga argument ges
INTERVAL=4             # sekunder mellan anslutningsförsök
# -------------------------------------------------------------------------

# argument överstyr standardlistan
if [ "$#" -gt 0 ]; then
    TARGETS=( "$@" )
fi

is_mac() { [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; }
log()    { printf '%(%H:%M:%S)T  %s\n' -1 "$*"; }

# håll en scan igång i bakgrunden via en ihållande bluetoothctl-session
coproc BT ( bluetoothctl )
BT_PID=$!
printf 'power on\nagent on\ndefault-agent\nscan on\n' >&"${BT[1]}"

cleanup() {
    printf 'scan off\n' >&"${BT[1]}" 2>/dev/null
    kill "$BT_PID" 2>/dev/null
    log "btwatch avslutad."
    exit 0
}
trap cleanup INT TERM

# slå upp en MAC för ett mål (MAC ges direkt, namn söks bland sedda enheter)
resolve_mac() {
    local t="$1"
    if is_mac "$t"; then
        printf '%s' "$t"
        return 0
    fi
    # matcha namndel (skiftlägesokänsligt) mot kända/sedda enheter
    bluetoothctl devices 2>/dev/null \
        | grep -i -- "$t" \
        | awk '{print $2; exit}'
}

# anslut (parkoppla + lita på vid behov) om inte redan ansluten
ensure_connected() {
    local mac="$1" info
    info="$(bluetoothctl info "$mac" 2>/dev/null)"

    case "$info" in
        *"Connected: yes"*) return 0 ;;   # redan ansluten, gör inget
    esac

    if ! grep -q "Paired: yes" <<<"$info"; then
        log "Parkopplar $mac ..."
        bluetoothctl pair "$mac"  >/dev/null 2>&1
    fi
    if ! grep -q "Trusted: yes" <<<"$info"; then
        bluetoothctl trust "$mac" >/dev/null 2>&1
    fi

    log "Ansluter $mac ..."
    if bluetoothctl connect "$mac" >/dev/null 2>&1; then
        log "✓ Ansluten: $mac"
    fi
}

log "btwatch startad. Bevakar: ${TARGETS[*]}"
log "Scannar och ansluter automatiskt. Ctrl-C för att avsluta."

while true; do
    for t in "${TARGETS[@]}"; do
        mac="$(resolve_mac "$t")"
        [ -n "$mac" ] && ensure_connected "$mac"
    done
    sleep "$INTERVAL"
done
