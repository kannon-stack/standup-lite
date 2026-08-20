. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\qemu.ps1"

$dataDir = Get-ProxmoxDataDir
if (-not $dataDir) { throw "USB-C NVMe not mounted. Plug it in before starting Proxmox." }
$vhdx = Join-Path $dataDir $DiskName
if (-not (Test-Path $vhdx)) { throw "Missing $vhdx. Run setup.ps1 first." }

if (Test-HyperVAvailable) {
    $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.State -ne 'Running') {
            Start-VM -Name $VmName
            Write-Host "Started Hyper-V VM $VmName"
        } else {
            Write-Host "$VmName is already running"
        }
        Get-VMNetworkAdapter -VMName $VmName | Select-Object Name, IPAddresses
        return
    }
}

Invoke-QemuPve -Mode run -DataDir $dataDir
Write-Host @"
Proxmox QEMU started.
  Web UI: https://127.0.0.1:$WebPort  (self-signed cert)
  SSH:    ssh -i $KeysDir\id_ed25519 -p $SshPort root@127.0.0.1
  VNC:    127.0.0.1:590$VncDisplay
Password is in $SecretsPath
From WSL: ssh -i $(ConvertTo-WslPath "$KeysDir\id_ed25519") -p $SshPort root@127.0.0.1
"@
