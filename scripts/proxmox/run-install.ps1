. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\qemu.ps1"
$dataDir = Get-ProxmoxDataDir
if (-not $dataDir) { throw "USB-C NVMe not mounted" }
$autoIso = Join-Path $CacheDir $AutoIsoName
if (-not (Test-Path $autoIso)) { throw "Missing $autoIso" }
Write-Host "Starting unattended install. VNC 127.0.0.1:590$VncDisplay"
Invoke-QemuPve -Mode install -DataDir $dataDir
Write-Host "QEMU installer daemonized. Polling until it power-off..."
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 2700) {
    Start-Sleep -Seconds 15
    $running = Invoke-QemuPve -Mode status -DataDir $dataDir
    if (-not $running) {
        Write-Host "Installer finished after $($sw.Elapsed.ToString('mm\:ss'))"
        break
    }
    Write-Host "  still installing $($sw.Elapsed.ToString('mm\:ss'))"
}
if (Invoke-QemuPve -Mode status -DataDir $dataDir) {
    throw "Installer still running after timeout. Check VNC and $dataDir\serial.log"
}
Write-Host "Booting installed disk..."
Invoke-QemuPve -Mode run -DataDir $dataDir
Wait-ProxmoxSsh
Start-Sleep -Seconds 30
Copy-ToProxmox (Join-Path $WslDir "first-boot.sh") "/root/first-boot.sh"
Copy-ToProxmox (Join-Path $WslDir "configure-pve.sh") "/root/configure-pve.sh"
Invoke-ProxmoxSsh "sed -i 's/\r`$//' /root/first-boot.sh /root/configure-pve.sh; chmod +x /root/first-boot.sh /root/configure-pve.sh; bash /root/configure-pve.sh"
Write-Host "Install complete. Web UI https://127.0.0.1:$WebPort"
