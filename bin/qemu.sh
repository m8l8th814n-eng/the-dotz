#!/usr/bin/env bash
set -euo pipefail

DISK="${QEMU_TEST_DISK:-$HOME/.local/share/qemu-test/testdisk.qcow2}"
DISK_SIZE="${QEMU_TEST_DISK_SIZE:-16G}"
VM_NAME="${VM_NAME:-iso-test}"
MEMORY="${MEMORY:-4G}"
CPUS="${CPUS:-4}"
SPICE_PORT="${SPICE_PORT:-5931}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<EOF
Usage:
  $0 isofil.iso

Env:
  QEMU_TEST_DISK=$DISK
  QEMU_TEST_DISK_SIZE=$DISK_SIZE
  MEMORY=$MEMORY
  CPUS=$CPUS
  DRY_RUN=1
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "saknar kommando: $1"
}

pick_first_existing() {
  local path
  for path in "$@"; do
    [[ -r "$path" ]] && {
      printf '%s\n' "$path"
      return 0
    }
  done
  return 1
}

ISO="${1:-}"
[[ -n "$ISO" && "$ISO" != "-h" && "$ISO" != "--help" ]] || {
  usage
  exit 0
}

need_cmd qemu-system-x86_64
need_cmd qemu-img

[[ -r "$ISO" ]] || die "hittar inte ISO: $ISO"

mkdir -p "$(dirname "$DISK")"
if [[ ! -e "$DISK" ]]; then
  printf 'Creating %s (%s)\n' "$DISK" "$DISK_SIZE" >&2
  qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
fi

OVMF_CODE="$(pick_first_existing \
  /usr/share/edk2/x64/OVMF_CODE.4m.fd \
  /usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd \
  /usr/share/OVMF/OVMF_CODE.4m.fd)" || die "hittar inte OVMF_CODE"
OVMF_VARS_TEMPLATE="$(pick_first_existing \
  /usr/share/edk2/x64/OVMF_VARS.4m.fd \
  /usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd \
  /usr/share/OVMF/OVMF_VARS.4m.fd)" || die "hittar inte OVMF_VARS"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/qemu-test/$VM_NAME"
OVMF_VARS="$STATE_DIR/OVMF_VARS.fd"
mkdir -p "$STATE_DIR"
[[ -e "$OVMF_VARS" ]] || cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

ACCEL_ARGS=(-accel tcg,thread=multi)
CPU_ARGS=(-cpu max)
if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  ACCEL_ARGS=(-enable-kvm -accel kvm)
  CPU_ARGS=(-cpu host)
else
  printf 'warning: /dev/kvm saknas eller är inte skrivbar, kör långsammare med TCG.\n' >&2
fi

DISPLAY_ARGS=(-display gtk)
GPU_ARGS=(-device virtio-vga)
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  DISPLAY_ARGS=(-display curses)
  GPU_ARGS=(-device VGA)
fi
RENDERNODE=""
for node in /dev/dri/renderD*; do
  [[ -e "$node" ]] || continue
  RENDERNODE="$node"
  break
done

if [[ "${DISPLAY_ARGS[*]}" == "-display gtk" && -n "$RENDERNODE" && -r "$RENDERNODE" && -w "$RENDERNODE" ]]; then
  DISPLAY_ARGS=(-display gtk,gl=on)
  GPU_ARGS=(-device virtio-vga-gl)
  printf 'Using render node: %s\n' "$RENDERNODE" >&2
elif [[ "${DISPLAY_ARGS[*]}" == "-display gtk" ]]; then
  printf 'warning: ingen användbar /dev/dri/renderD* hittades, kör utan virgl.\n' >&2
else
  printf 'warning: ingen grafisk display hittades, kör med curses.\n' >&2
fi

printf 'Disk: %s\n' "$DISK" >&2
printf 'ISO:  %s\n' "$ISO" >&2
printf 'SPICE: spice://127.0.0.1:%s\n' "$SPICE_PORT" >&2

QEMU_ARGS=(
  -name "$VM_NAME" \
  -machine q35 \
  "${ACCEL_ARGS[@]}" \
  "${CPU_ARGS[@]}" \
  -smp "$CPUS" \
  -m "$MEMORY" \
  -boot menu=on \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS" \
  -drive file="$DISK",if=virtio,format=qcow2,cache=writeback,discard=unmap \
  -drive file="$ISO",if=none,id=cdrom,media=cdrom,readonly=on \
  -device ide-cd,drive=cdrom,bootindex=1 \
  -device qemu-xhci,id=xhci \
  -device usb-tablet \
  -nic user,model=virtio-net-pci \
  -device virtio-balloon-pci \
  -audiodev pipewire,id=audio0 \
  -device ich9-intel-hda \
  -device hda-output,audiodev=audio0 \
  -spice "port=$SPICE_PORT,disable-ticketing=on" \
  -device virtio-serial-pci \
  -chardev spicevmc,id=vdagent,name=vdagent \
  -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
  "${DISPLAY_ARGS[@]}" \
  "${GPU_ARGS[@]}"
)

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'qemu-system-x86_64'
  printf ' %q' "${QEMU_ARGS[@]}"
  printf '\n'
  exit 0
fi

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
