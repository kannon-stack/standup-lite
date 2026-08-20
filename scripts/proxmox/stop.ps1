. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\qemu.ps1"

Write-Host "Shutting down nested guests, then Proxmox, then the Hyper-V/QEMU VM."

$key = Join-Path $KeysDir "id_ed25519"
if (Test-Path $key) {
    try {
        Invoke-ProxmoxSsh "pct list >/dev/null 2>&1; qm list >/dev/null 2>&1; poweroff"
        Write-Host "Asked Proxmox to halt."
        Start-Sleep -Seconds 8
    } catch {
        Write-Host "SSH shutdown skipped (guest not reachable): $($_.Exception.Message)"
    }
}

if (Test-HyperVAvailable) {
    $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if ($vm -and $vm.State -ne 'Off') {
        Stop-VM -Name $VmName -Force
        $n = 0
        while ((Get-VM -Name $VmName).State -ne 'Off' -and $n -lt 60) {
            Start-Sleep -Seconds 2
            $n++
        }
        Write-Host "Hyper-V VM is Off"
        return
    }
}

$dataDir = Get-ProxmoxDataDir
if ($dataDir) {
    try {
        Invoke-QemuPve -Mode stop -DataDir $dataDir
    } catch {
        Write-Host "QEMU stop: $($_.Exception.Message)"
    }
} else {
    Write-Host "Lab drive not mounted; if QEMU is still running, start WSL and run wsl/qemu-pve.sh stop with PVE_DATA_DIR set."
}
Write-Host "Proxmox VM is off. You can now run eject.ps1."
