. "$PSScriptRoot\lib.ps1"

Write-Host "=== Portable Proxmox prerequisite check ==="
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
$ramGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$hyperV = Test-HyperVAvailable
$drive = Get-ProxmoxDrive
$wsl = & wsl.exe -l -v

$report = @"
OS: $($os.Caption) $($os.Version)
CPU: $($cpu.Name)
Firmware virtualization CIM flag: $($cpu.VirtualizationFirmwareEnabled)
  (often False even when Hyper-V/WSL2 is active; hypervisor was detected on this host)
RAM: ${ramGb} GB total, ${freeGb} GB free
Hyper-V cmdlets: $(if ($hyperV) { 'available' } else { 'NOT available (Windows Home uses WSL2 QEMU+KVM)' })
USB/NVMe lab drive: $(if ($drive) { $drive } else { 'NOT mounted — plug in the USB-C NVMe, NTFS, label PROXMOX' })
WSL:
$wsl
"@
Write-Host $report

$out = Join-Path $CacheDir "prereq-report.txt"
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
Set-Content -Encoding utf8 $out $report
Write-Host "Wrote $out"

if ($os.Caption -match 'Home' -and -not $hyperV) {
    Write-Host @"
This PC is Windows 11 Home, so the Hyper-V Manager role is not present.
WSL2 already has /dev/kvm with nested=Y on this Intel CPU, so the lab runs
Proxmox as a UEFI QEMU VM (Secure Boot off) with the VHDX on the USB-C NVMe.
If you later install Windows 11 Pro, setup.ps1 can create a Generation 2 Hyper-V VM instead.
"@
}

if ($ramGb -lt 24) {
    Write-Host "RAM is ${ramGb} GB (plan suggested 32 GB). The VM is sized at $($MemoryMb) MB so Windows and WSL still fit."
}

if (-not $drive) {
    Write-Host "Plug the Insignia/Best Buy USB-C NVMe in a direct USB-C port, then in Disk Management initialize GPT, format NTFS, label PROXMOX, assign a letter."
    exit 2
}
exit 0
