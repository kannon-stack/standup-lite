# Portable Proxmox on USB-C NVMe

Windows stays the host. The Proxmox disk is a VHDX on the USB-C NVMe. WSL Ubuntu is the operator shell (SSH / start-stop). Unplug the drive only after a clean shutdown.

## This PC

- Windows 11 **Home** — Hyper-V Manager is not available. The lab uses **WSL2 QEMU+KVM** instead (Intel i7-1195G7, `/dev/kvm`, nested=Y).
- If you later use Windows 11 Pro, `create-vm.ps1` builds a Generation 2 Hyper-V VM: nested virtualization on, Secure Boot off, checkpoints disabled.
- Host RAM is 16 GB, so the Proxmox VM is sized at **4 GB / 4 vCPUs**. Prefer LXC guests over nested KVM.
- Enclosure: Best Buy / Insignia `NS-PCNVMEHDE` on **D:** (NTFS, label **PROXMOX**, 238 GB). Plug it into a **direct USB-C port**, not a hub.

## One-time disk prep

1. Plug in the NVMe. In Disk Management, initialize **GPT**, format **NTFS**, label **PROXMOX**, assign a letter (P: is fine).
2. Disable USB selective suspend for that controller (Power Options) so Windows does not sleep the disk while the VM runs.
3. Never unplug while the VM is running.

Layout created on the volume:

```
X:\proxmox\
  pve.vhdx          # 64 GB fixed VHDX (override with PVE_VHDX_SUBFORMAT=dynamic)
  iso\              # copy of the installer
  vm-config\
  OVMF_VARS.fd
```

## Commands

From PowerShell in `scripts/proxmox`:

```powershell
.\prereq-check.ps1
.\setup.ps1          # download ISO, create VHDX, unattended install
.\start.ps1
.\stop.ps1
.\eject.ps1          # stop, flush, Safely Remove
```

From WSL Ubuntu:

```bash
cd /mnt/c/Users/admin/standup-lite/scripts/proxmox
bash wsl/pve-ssh.sh
# or: ssh -i keys/id_ed25519 -p 2222 root@127.0.0.1
```

- Web UI: `https://127.0.0.1:8006` (self-signed certificate)
- VNC during install / troubleshooting: `127.0.0.1:5901`
- Root password: `scripts/proxmox/secrets.env` (gitignored, local only)
- SSH key: `scripts/proxmox/keys/id_ed25519` (gitignored private key)

## Nested guests

Inside Proxmox, create KVM VMs with CPU type **host**. Prefer **LXC** (`pct`) for inner workloads. First-boot created unprivileged Alpine container **CT 100** (`alpine-test`). Start it with `pct start 100`. A QEMU snippet is at `/var/lib/vz/snippets/cpu-host.conf`.

Do not use Hyper-V checkpoints on this VM. Differencing disks break if the USB drive is moved or unplugged.

## Shutdown then remove

1. `.\stop.ps1` — guests, then Proxmox, then QEMU/Hyper-V until Off
2. `.\eject.ps1` — flush and eject
3. Unplug the USB-C cable

Skipping this can corrupt the VHDX and lose the lab. Do not run `wsl --shutdown` or unplug the drive while QEMU is running.

## What this is for

Portable homelab on one stick, Windows and WSL still usable. Not for production, surprise disconnects, or I/O-heavy databases. Nested Windows guests will be painful on 16 GB RAM.
