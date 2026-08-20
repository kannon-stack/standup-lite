. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\qemu.ps1"
Repair-ShellScripts | Out-Null
Initialize-ProxmoxSecrets | Out-Null
$answer = New-ProxmoxAnswerFile
Write-Host "Wrote answer file (password is only in secrets.env)."
Write-Host $answer
