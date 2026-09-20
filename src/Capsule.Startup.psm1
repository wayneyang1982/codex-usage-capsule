Set-StrictMode -Version Latest
function Get-CapsuleStartupTask {
    $task=Get-ScheduledTask -TaskName 'CodexUsageCapsule' -TaskPath '\' -ErrorAction Stop
    $expected=Join-Path $PSScriptRoot 'CodexCapsule-Silent.vbs'
    $actions=@($task.Actions)
    if($actions.Count -ne 1 -or [IO.Path]::GetFileName($actions[0].Execute) -ine 'wscript.exe' -or $actions[0].Arguments.Trim('"') -ine $expected){throw 'Startup task target does not match this installation.'}
    return $task
}
function Get-CapsuleStartupEnabled {
    $task=Get-CapsuleStartupTask
    return [bool]$task.Settings.Enabled
}
function Set-CapsuleStartupEnabled {
    param([Parameter(Mandatory)][bool]$Enabled)
    $task=Get-CapsuleStartupTask
    # Enabling/disabling does not stop the current instance or rewrite its
    # hidden VBS action, logon delay, identity, or other task settings.
    if($Enabled){$task | Enable-ScheduledTask -ErrorAction Stop | Out-Null}
    else{$task | Disable-ScheduledTask -ErrorAction Stop | Out-Null}
    $actual=Get-CapsuleStartupEnabled
    if($actual -ne $Enabled){throw 'Windows did not confirm the startup setting.'}
    return $actual
}
Export-ModuleMember -Function Get-CapsuleStartupEnabled,Set-CapsuleStartupEnabled
