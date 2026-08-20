. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\qemu.ps1"

& "$PSScriptRoot\stop.ps1"

$dd = Get-ProxmoxDataDir
if ($dd -and (Invoke-QemuPve -Mode status -DataDir $dd)) {
    throw "QEMU is still running — will not eject."
}

if (Test-HyperVAvailable) {
    $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if ($vm -and $vm.State -ne 'Off') {
        throw "Hyper-V VM $VmName is still $($vm.State). Refusing to eject."
    }
}

$drive = Get-ProxmoxDrive
if (-not $drive) {
    Write-Host "Lab volume already gone."
    return
}

$letter = $drive.TrimEnd(':')
Write-Host "Flushing volume $drive ..."
try {
    Write-VolumeCache -DriveLetter $letter -ErrorAction Stop
} catch {
    Write-Host "Write-VolumeCache: $($_.Exception.Message)"
}

$ejected = $false
try {
    $shell = New-Object -ComObject Shell.Application
    $ns = $shell.NameSpace(17)
    foreach ($item in $ns.Items()) {
        if ($item.Path -eq $drive -or $item.Path -eq "$drive\") {
            $item.InvokeVerb("Eject")
            $ejected = $true
            break
        }
    }
} catch {
    Write-Host "Shell eject failed: $($_.Exception.Message)"
}

if (-not $ejected) {
    Write-Host "Use Safely Remove Hardware for $drive, then unplug the USB-C cable."
} else {
    Start-Sleep -Seconds 2
    Write-Host "Eject issued for $drive. Unplug the USB-C NVMe when Windows says it is safe."
}
