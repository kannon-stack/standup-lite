#!/bin/bash
# Launch or install the portable Proxmox QEMU VM from WSL2 KVM.
set -euo pipefail

MODE="${1:-run}" # run | install | stop | status
DATA_DIR="${PVE_DATA_DIR:?set PVE_DATA_DIR to the Windows proxmox folder via wslpath}"
CACHE_DIR="${PVE_CACHE_DIR:?set PVE_CACHE_DIR}"
MEMORY_MB="${PVE_MEMORY_MB:-4096}"
VCPUS="${PVE_VCPUS:-4}"
SSH_PORT="${PVE_SSH_PORT:-2222}"
WEB_PORT="${PVE_WEB_PORT:-8006}"
VNC_DISPLAY="${PVE_VNC_DISPLAY:-1}"
DISK_NAME="${PVE_DISK_NAME:-pve.vhdx}"
AUTO_ISO_NAME="${PVE_AUTO_ISO_NAME:-proxmox-ve_9.2-1-auto.iso}"

DISK="$DATA_DIR/$DISK_NAME"
RUNDIR=/tmp/pve-portable
mkdir -p "$RUNDIR"
VARS="$RUNDIR/OVMF_VARS.fd"
PIDFILE="$RUNDIR/qemu.pid"
MONITOR="$RUNDIR/monitor.sock"
SERIAL="$RUNDIR/serial.log"
CODE=""
for cand in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
  if [[ -f "$cand" ]]; then CODE="$cand"; break; fi
done
[[ -n "$CODE" ]] || { echo "OVMF_CODE not found" >&2; exit 1; }

qemu_running() {
  if [[ -f "$PIDFILE" ]]; then
    pid=$(cat "$PIDFILE" || true)
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

stop_vm() {
  if [[ -S "$MONITOR" ]]; then
    python3 - <<PY
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    s.connect("$MONITOR")
    s.sendall(b"system_powerdown\n")
except Exception as e:
    sys.stderr.write(f"monitor: {e}\n")
finally:
    s.close()
PY
    for _ in $(seq 1 60); do
      qemu_running || { echo "Proxmox QEMU powered off"; return 0; }
      sleep 1
    done
  fi
  if qemu_running; then
    pid=$(cat "$PIDFILE")
    echo "forcing QEMU stop pid=$pid"
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
  fi
  if [[ -f "$VARS" ]]; then
    mkdir -p "$DATA_DIR"
    cp -f "$VARS" "$DATA_DIR/OVMF_VARS.fd" 2>/dev/null || true
  fi
  rm -f "$PIDFILE" "$MONITOR"
}

status_vm() {
  if qemu_running; then
    echo "running pid=$(cat "$PIDFILE")"
    exit 0
  fi
  echo "stopped"
  exit 1
}

if [[ "$MODE" == "stop" ]]; then stop_vm; exit 0; fi
if [[ "$MODE" == "status" ]]; then status_vm; fi

if qemu_running; then
  echo "already running pid=$(cat "$PIDFILE")"
  exit 0
fi

# UEFI vars must live on the Linux filesystem; pflash mmap is unreliable on /mnt/d.
if [[ -f "$DATA_DIR/OVMF_VARS.fd" ]]; then
  cp -f "$DATA_DIR/OVMF_VARS.fd" "$VARS"
fi
if [[ ! -f "$VARS" ]]; then
  for cand in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do
    if [[ -f "$cand" ]]; then cp "$cand" "$VARS"; break; fi
  done
fi
[[ -f "$DISK" ]] || { echo "missing disk $DISK" >&2; exit 1; }

ISO_ARGS=()
BOOTINDEX_DISK=1
if [[ "$MODE" == "install" ]]; then
  AUTO_ISO="$CACHE_DIR/$AUTO_ISO_NAME"
  [[ -f "$AUTO_ISO" ]] || { echo "missing auto ISO $AUTO_ISO" >&2; exit 1; }
  ISO_ARGS=(
    -drive "file=$AUTO_ISO,media=cdrom,if=none,id=cd0,readonly=on,format=raw"
    -device scsi-cd,drive=cd0,bootindex=0
  )
  BOOTINDEX_DISK=2
fi

# UEFI, nested KVM, no Secure Boot (plain OVMF_CODE, not secboot).
exec qemu-system-x86_64 \
  -name Proxmox \
  -machine q35,accel=kvm,usb=off \
  -cpu host \
  -enable-kvm \
  -smp "$VCPUS" \
  -m "$MEMORY_MB" \
  -drive "if=pflash,format=raw,readonly=on,file=$CODE" \
  -drive "if=pflash,format=raw,file=$VARS" \
  -device virtio-scsi-pci,id=scsi0 \
  -drive "file=$DISK,if=none,id=hd0,format=vhdx,cache=writeback,discard=unmap,aio=threads" \
  -device "scsi-hd,drive=hd0,bootindex=$BOOTINDEX_DISK" \
  "${ISO_ARGS[@]}" \
  -netdev "user,id=net0,hostfwd=tcp::${WEB_PORT}-:8006,hostfwd=tcp::${SSH_PORT}-:22" \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -vnc "0.0.0.0:${VNC_DISPLAY}" \
  -serial "file:$SERIAL" \
  -monitor "unix:$MONITOR,server,nowait" \
  -pidfile "$PIDFILE" \
  -daemonize
