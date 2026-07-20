#!/bin/sh
# therm.sh - thermal logger that survives a hard reboot. no color, no deps.
# usage:
#   ./therm.sh            log temps+freqs every 1s until reboot/ctrl-c
#   ./therm.sh 2          same, every 2s
#   ./therm.sh report     after reboot: show critical trips + what it died at

LOG=${THERM_LOG:-/var/log/therm.log}
# fall back if /var/log not writable
if ! ( : >> "$LOG" ) 2>/dev/null; then
  LOG=./therm.log
fi

md2c() { echo $(( ${1:-0} / 1000 )); }   # millidegrees/millihertz -> int

crits() {
  for z in /sys/class/thermal/thermal_zone*; do
    [ -e "$z/type" ] || continue
    ty=$(cat "$z/type" 2>/dev/null)
    for tp in "$z"/trip_point_*_type; do
      [ -e "$tp" ] || continue
      kind=$(cat "$tp" 2>/dev/null)
      base=${tp%_type}
      tv=$(cat "${base}_temp" 2>/dev/null)
      [ -n "$tv" ] && printf '  %-14s %-10s %sC\n' "$ty" "$kind" "$(md2c "$tv")"
    done
  done
}

temps() {
  for z in /sys/class/thermal/thermal_zone*; do
    [ -e "$z/temp" ] || continue
    ty=$(cat "$z/type" 2>/dev/null)
    tv=$(cat "$z/temp" 2>/dev/null)
    printf '%s=%sC ' "$ty" "$(md2c "$tv")"
  done
}

freqs() {
  printf 'MHz:'
  for c in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    [ -e "$c" ] || continue
    printf ' %s' "$(md2c "$(cat "$c" 2>/dev/null)")"
  done
}

if [ "$1" = "report" ]; then
  echo "=== critical / trip points (the reboot threshold) ==="
  crits
  echo
  echo "=== last lines before reboot (log: $LOG) ==="
  tail -n 20 "$LOG" 2>/dev/null
  echo
  echo "hottest temps seen:"
  awk '{for(i=1;i<=NF;i++){n=split($i,a,"=");if(n==2){gsub(/C/,"",a[2]);
       if(a[2]+0>m[a[1]])m[a[1]]=a[2]+0}}}
       END{for(k in m)printf "  %-14s %sC\n",k,m[k]}' "$LOG" 2>/dev/null
  exit 0
fi

INT=${1:-1}
{
  echo "# start $(date +%s) interval=${INT}s"
  echo "# critical trips:"
  crits
} >> "$LOG"
sync

trap 'echo; echo "stopped. run: $0 report"; exit 0' INT TERM

echo "logging to $LOG every ${INT}s. load the device now. ctrl-c to stop."
while :; do
  printf 'ts=%s %s| %s\n' "$(date +%s)" "$(temps)" "$(freqs)" >> "$LOG"
  sync
  sleep "$INT"
done
