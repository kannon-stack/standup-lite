#!/bin/bash
# Idempotent nested/LXC setup. Run via SSH after install if first-boot did not.
set -euo pipefail
if [[ ! -f /root/portable-first-boot.log ]] || ! grep -q "first-boot complete" /root/portable-first-boot.log 2>/dev/null; then
  bash /root/first-boot.sh
fi
echo "nested intel: $(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo n/a)"
echo "kvm: $(ls /dev/kvm 2>/dev/null || echo missing)"
pct list || true
