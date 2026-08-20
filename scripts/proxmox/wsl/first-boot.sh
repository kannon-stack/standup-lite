#!/bin/bash
# Runs once on the installed Proxmox node (after network is up).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LOG=/root/portable-first-boot.log
exec > >(tee -a "$LOG") 2>&1
echo "=== portable Proxmox first-boot $(date -Is) ==="

if [[ -f /etc/apt/sources.list.d/pve-enterprise.list ]]; then
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/pve-enterprise.list || true
fi
if [[ -f /etc/apt/sources.list.d/ceph.list ]]; then
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/ceph.list || true
fi

cat >/etc/apt/sources.list.d/pve-no-subscription.list <<'EOF'
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription
EOF

echo "options kvm-intel nested=Y" >/etc/modprobe.d/kvm-intel.conf
echo "options kvm-amd nested=1" >/etc/modprobe.d/kvm-amd.conf
modprobe -r kvm_intel 2>/dev/null || true
modprobe kvm_intel nested=Y 2>/dev/null || true

mkdir -p /root
cat >/root/PORTABLE-LAB.txt <<'EOF'
Portable Proxmox nested guests
- For KVM VMs use CPU type "host" (Hardware -> Processors).
- Prefer LXC containers (pct) over nested KVM; they are much faster.
- Do not take Hyper-V checkpoints of this VM.
- Shut down all guests, then this node, then eject the USB-C NVMe.
EOF

# Default CPU type for new QEMU VMs created from the API/CLI when args omit cpu.
# Snippets: apply "cpu-host" when creating a VM.
mkdir -p /var/lib/vz/snippets
cat >/var/lib/vz/snippets/cpu-host.conf <<'EOF'
cpu: host
numa: 0
EOF

pvesm set local --content iso,vztmpl,backup,snippets 2>/dev/null || true

apt-get update -y || true

if command -v pveam >/dev/null 2>&1; then
  pveam update || true
  tmpl=$(pveam available --section system | awk '/alpine-3\.[0-9]+-default/ {print $2}' | tail -1)
  if [[ -n "${tmpl:-}" ]]; then
    pveam download local "$tmpl" || true
    localtmpl="local:vztmpl/${tmpl##*/}"
    if ! pct status 100 >/dev/null 2>&1; then
      pct create 100 "$localtmpl" \
        --hostname alpine-test \
        --memory 128 \
        --swap 128 \
        --cores 1 \
        --rootfs local-lvm:2 \
        --unprivileged 1 \
        --features nesting=1 \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --onboot 0 || true
      echo "Created LXC 100 (alpine-test). Start with: pct start 100"
    fi
  fi
fi

echo "=== first-boot complete $(date -Is) ==="
