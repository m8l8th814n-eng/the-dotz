#!/usr/bin/env bash
set -euo pipefail

PROFILE_PATH=/sys/firmware/acpi/platform_profile
CPUBASE=/sys/devices/system/cpu

mode=${1:-performance}

case "$mode" in
  quiet)       epp=power ;;
  balanced)    epp=balance_performance ;;
  performance) epp=performance ;;
  status)      epp= ;;
  *) echo "usage: $0 {quiet|balanced|performance|status}" >&2; exit 1 ;;
esac

if [[ "$mode" != status && $EUID -ne 0 ]]; then
  exec sudo "$0" "$mode"
fi

if [[ "$mode" != status ]]; then
  echo "$mode" > "$PROFILE_PATH"
  for f in "$CPUBASE"/cpu[0-9]*/cpufreq/energy_performance_preference; do
    echo "$epp" > "$f"
  done
fi

printf 'profile : %s\n' "$(cat "$PROFILE_PATH")"
printf 'EPP     : %s\n' "$(cat "$CPUBASE"/cpu0/cpufreq/energy_performance_preference)"
printf 'governor: %s\n' "$(cat "$CPUBASE"/cpu0/cpufreq/scaling_governor)"
printf 'boost   : %s\n' "$(cat "$CPUBASE"/cpufreq/boost 2>/dev/null || echo n/a)"
printf 'max MHz : %s\n' "$(( $(cat "$CPUBASE"/cpu*/cpufreq/scaling_cur_freq | sort -n | tail -1) / 1000 ))"
