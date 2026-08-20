#!/bin/bash
set -euo pipefail
ISO_IN="${1:?usage: prepare-iso.sh <stock.iso> <answer.toml> <first-boot.sh> <out.iso>}"
ANSWER="${2:?}"
FIRST_BOOT="${3:?}"
ISO_OUT="${4:?}"

if [[ ! -f "$ISO_IN" ]]; then
  echo "missing ISO: $ISO_IN" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
# Copy onto Linux filesystem; xorriso is slow/unreliable on /mnt/c drvfs.
cp -f "$ISO_IN" "$tmpdir/in.iso"
cp -f "$ANSWER" "$tmpdir/answer.toml"
cp -f "$FIRST_BOOT" "$tmpdir/first-boot.sh"
chmod +x "$tmpdir/first-boot.sh"

proxmox-auto-install-assistant validate-answer "$tmpdir/answer.toml"
proxmox-auto-install-assistant prepare-iso "$tmpdir/in.iso" \
  --fetch-from iso \
  --answer-file "$tmpdir/answer.toml" \
  --on-first-boot "$tmpdir/first-boot.sh" \
  --output "$tmpdir/out.iso"

mkdir -p "$(dirname "$ISO_OUT")"
cp -f "$tmpdir/out.iso" "$ISO_OUT"
echo "prepared $ISO_OUT"
