. "$PSScriptRoot\lib.ps1"

function New-ProxmoxHyperVVM {
    param([string]$DataDir, [string]$Vhdx, [string]$IsoPath)
    $exists = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Host "Hyper-V VM $VmName already exists"
        return
    }
    $switch = Get-VMSwitch | Where-Object { $_.SwitchType -eq 'External' } | Select-Object -First 1
    if (-not $switch) {
        $switch = Get-VMSwitch | Where-Object { $_.Name -eq 'Default Switch' } | Select-Object -First 1
    }
    if (-not $switch) { throw "No Hyper-V virtual switch found. Create Default Switch or an External switch." }

    New-VM -Name $VmName -Generation 2 -MemoryStartupBytes ($MemoryMb * 1MB) -VHDPath $Vhdx -SwitchName $switch.Name | Out-Null
    Set-VM -Name $VmName -CheckpointType Disabled -AutomaticCheckpointsEnabled $false -Notes "Portable Proxmox on USB-C NVMe. Do not checkpoint."
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false
    Set-VMProcessor -VMName $VmName -Count $VCpus -ExposeVirtualizationExtensions $true
    Set-VMFirmware -VMName $VmName -EnableSecureBoot Off
    if ($IsoPath -and (Test-Path $IsoPath)) {
        Add-VMDvdDrive -VMName $VmName -Path $IsoPath
        $dvd = Get-VMDvdDrive -VMName $VmName
        Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd
    }
    Write-Host "Created Hyper-V VM $VmName (Gen2, Secure Boot off, nested virt on, checkpoints disabled)"
}

$dataDir = Get-ProxmoxDataDir -Wait
if (-not $dataDir) {
    throw "USB-C NVMe not found. Plug it in, format NTFS, label the volume PROXMOX, then re-run."
}
New-Item -ItemType Directory -Force -Path $dataDir, (Join-Path $dataDir "iso"), (Join-Path $dataDir "vm-config") | Out-Null
$vhdx = Join-Path $dataDir $DiskName
if (-not (Test-Path $vhdx)) {
    $wslData = ConvertTo-WslPath $dataDir
    $sub = if ($env:PVE_VHDX_SUBFORMAT) { $env:PVE_VHDX_SUBFORMAT } else { "fixed" }
    Write-Host "Creating $sub VHDX $($DiskGb)G at $vhdx"
    Invoke-PveWsl "mkdir -p '$wslData' && qemu-img create -f vhdx -o subformat=$sub '$wslData/$DiskName' $($DiskGb)G"
} else {
    Write-Host "VHDX already exists: $vhdx"
}

if (Test-HyperVAvailable) {
    $iso = Join-Path $CacheDir $AutoIsoName
    New-ProxmoxHyperVVM -DataDir $dataDir -Vhdx $vhdx -IsoPath $iso
} else {
    Write-Host "Hyper-V not available; VM will be started with WSL2 QEMU+KVM (UEFI, Secure Boot off, -cpu host)."
    @"
VmName=$VmName
Vhdx=$vhdx
MemoryMb=$MemoryMb
VCpus=$VCpus
Hypervisor=wsl-qemu
Nested=on
SecureBoot=off
Checkpoints=disabled
"@ | Set-Content (Join-Path $dataDir "vm-config\vm.txt")
}
Write-Host "VM disk and config ready under $dataDir"
