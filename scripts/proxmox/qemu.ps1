. "$PSScriptRoot\lib.ps1"

function Get-QemuEnvExports([string]$DataDir) {
    $wslData = (ConvertTo-WslPath $DataDir).Trim()
    $wslCache = (ConvertTo-WslPath $CacheDir).Trim()
    return "export PVE_DATA_DIR='$wslData' PVE_CACHE_DIR='$wslCache' PVE_MEMORY_MB=$MemoryMb PVE_VCPUS=$VCpus PVE_SSH_PORT=$SshPort PVE_WEB_PORT=$WebPort PVE_VNC_DISPLAY=$VncDisplay PVE_DISK_NAME='$DiskName' PVE_AUTO_ISO_NAME='$AutoIsoName'"
}

function Repair-ShellScripts {
    $wslScripts = ConvertTo-WslPath $WslDir
    Invoke-PveWsl "find '$wslScripts' -name '*.sh' -exec sed -i 's/\r`$//' {} +"
}

function Invoke-QemuPve {
    param(
        [ValidateSet('run','install','stop','status')]
        [string]$Mode,
        [string]$DataDir
    )
    if ($Mode -ne 'status') {
        Repair-ShellScripts
    }
    $wslScript = ConvertTo-WslPath (Join-Path $WslDir "qemu-pve.sh")
    $exports = Get-QemuEnvExports $DataDir
    $code = Invoke-PveWsl -IgnoreExit "$exports; bash '$wslScript' $Mode"
    if ($Mode -eq 'status') { return ($code -eq 0) }
    if ($code -ne 0) { throw "qemu-pve.sh $Mode failed (exit $code)" }
}

function Wait-ProxmoxSsh {
    param([int]$TimeoutSeconds = 2700)
    $key = Join-Path $KeysDir "id_ed25519"
    $known = Join-Path $CacheDir "known_hosts"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host "Waiting for SSH on 127.0.0.1:$SshPort (installer can take 10-20 minutes)..."
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        & ssh.exe -i $key -p $SshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=$known -o ConnectTimeout=3 -o BatchMode=yes root@127.0.0.1 "true" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SSH is up after $($sw.Elapsed.ToString('mm\:ss'))"
            return
        }
        Start-Sleep -Seconds 8
    }
    throw "Timed out waiting for Proxmox SSH. Check WSL /tmp/pve-portable/serial.log or VNC 127.0.0.1:590$VncDisplay"
}

function Invoke-ProxmoxSsh {
    param([Parameter(Mandatory)][string]$RemoteCommand)
    $key = Join-Path $KeysDir "id_ed25519"
    $known = Join-Path $CacheDir "known_hosts"
    & ssh.exe -i $key -p $SshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=$known root@127.0.0.1 $RemoteCommand
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed: $RemoteCommand"
    }
}

function Copy-ToProxmox {
    param([string]$Local, [string]$Remote)
    $key = Join-Path $KeysDir "id_ed25519"
    $known = Join-Path $CacheDir "known_hosts"
    & scp.exe -i $key -P $SshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=$known $Local "root@127.0.0.1:$Remote"
    if ($LASTEXITCODE -ne 0) { throw "scp failed: $Local -> $Remote" }
}
