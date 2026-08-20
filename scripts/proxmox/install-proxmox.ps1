. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\qemu.ps1"

Repair-ShellScripts
Initialize-ProxmoxSecrets | Out-Null
$iso = Ensure-ProxmoxIso
Write-Host "Verifying ISO checksum..."
Test-IsoChecksum $iso
$answer = New-ProxmoxAnswerFile
Write-Host "Answer file: $answer"

$autoIso = Join-Path $CacheDir $AutoIsoName
if (-not (Test-Path $autoIso) -or (Get-Item $autoIso).Length -lt 1GB) {
    Write-Host "Preparing automated installer ISO (copied off /mnt/c for xorriso)..."
    $wslPrep = ConvertTo-WslPath (Join-Path $WslDir "prepare-iso.sh")
    $wslIso = ConvertTo-WslPath $iso
    $wslAnswer = ConvertTo-WslPath $answer
    $wslBoot = ConvertTo-WslPath (Join-Path $WslDir "first-boot.sh")
    $wslOut = ConvertTo-WslPath $autoIso
    Invoke-PveWsl "bash '$wslPrep' '$wslIso' '$wslAnswer' '$wslBoot' '$wslOut'"
}

& "$PSScriptRoot\create-vm.ps1"

$dataDir = Get-ProxmoxDataDir
Copy-Item $iso (Join-Path $dataDir "iso\$IsoName") -Force -ErrorAction SilentlyContinue
Copy-Item $autoIso (Join-Path $dataDir "iso\$AutoIsoName") -Force -ErrorAction SilentlyContinue

if (Test-HyperVAvailable -and (Get-VM -Name $VmName -ErrorAction SilentlyContinue)) {
    $dvd = Get-VMDvdDrive -VMName $VmName
    Set-VMDvdDrive -VMName $VmName -Path $autoIso
    Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd
    Start-VM -Name $VmName
    Write-Host "Hyper-V install started. Automated installer will power off when done."
    $n = 0
    while ((Get-VM -Name $VmName).State -ne 'Off' -and $n -lt 360) {
        Start-Sleep -Seconds 10
        $n++
        if (($n % 6) -eq 0) { Write-Host "  still installing... $([int]($n*10/60)) min" }
    }
    Set-VMDvdDrive -VMName $VmName -Path $null
    $hdd = Get-VMHardDiskDrive -VMName $VmName | Select-Object -First 1
    Set-VMFirmware -VMName $VmName -FirstBootDevice $hdd
    Start-VM -Name $VmName
    Write-Host "Proxmox installed. Find the VM IP with Get-VMNetworkAdapter -VMName $VmName"
    return
}

Write-Host "Starting unattended QEMU install (VNC 127.0.0.1:590$VncDisplay)..."
Invoke-QemuPve -Mode install -DataDir $dataDir
Start-Sleep -Seconds 5
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 2700) {
    $running = Invoke-QemuPve -Mode status -DataDir $dataDir
    if (-not $running) {
        Write-Host "Installer QEMU exited after $($sw.Elapsed.ToString('mm\:ss'))"
        break
    }
    if (($sw.Elapsed.TotalSeconds % 60) -lt 15) {
        Write-Host "  installer still running $($sw.Elapsed.ToString('mm\:ss'))"
    }
    Start-Sleep -Seconds 10
}

Write-Host "Booting installed Proxmox from disk..."
Invoke-QemuPve -Mode run -DataDir $dataDir
Wait-ProxmoxSsh
Start-Sleep -Seconds 20
Copy-ToProxmox (Join-Path $WslDir "first-boot.sh") "/root/first-boot.sh"
Copy-ToProxmox (Join-Path $WslDir "configure-pve.sh") "/root/configure-pve.sh"
Invoke-ProxmoxSsh "sed -i 's/\r$//' /root/first-boot.sh /root/configure-pve.sh; chmod +x /root/first-boot.sh /root/configure-pve.sh; bash /root/configure-pve.sh"

Write-Host @"
Proxmox VE is installed.
  Web UI: https://127.0.0.1:$WebPort
  SSH:    ssh -i $KeysDir\id_ed25519 -p $SshPort root@127.0.0.1
  Password: $SecretsPath
"@
