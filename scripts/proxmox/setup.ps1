# Requires: USB-C NVMe mounted (NTFS, label PROXMOX recommended)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host "=== Portable Proxmox setup ==="
& "$PSScriptRoot\prereq-check.ps1"
if ($LASTEXITCODE -eq 2) {
    Write-Host "Waiting up to 3 minutes for the USB-C NVMe..."
    . "$PSScriptRoot\lib.ps1"
    $null = Wait-ProxmoxDrive -TimeoutSeconds 180
    & "$PSScriptRoot\prereq-check.ps1"
    if ($LASTEXITCODE -eq 2) {
        throw "USB-C NVMe still not mounted. Format it NTFS, label PROXMOX, assign a drive letter, then re-run setup.ps1."
    }
}
& "$PSScriptRoot\install-proxmox.ps1"
