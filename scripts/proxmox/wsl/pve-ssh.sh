#!/bin/bash
# WSL helper: SSH into the portable Proxmox VM (QEMU hostfwd).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="$ROOT/keys/id_ed25519"
exec ssh -i "$KEY" -p "${PVE_SSH_PORT:-2222}" -o StrictHostKeyChecking=no root@127.0.0.1 "$@"
