[CmdletBinding()]
param(
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs\CodexUsageCapsule'),
    [switch]$Json
)
$ErrorActionPreference='Stop'
$resolvedRoot=[IO.Path]::GetFullPath($InstallRoot)
$markerPath=Join-Path $resolvedRoot '.codex-usage-capsule-install.json'
$installed=$false
if(Test-Path -LiteralPath $markerPath -PathType Leaf){
    try{
        $marker=Get-Content -LiteralPath $markerPath -Raw|ConvertFrom-Json
        $installed=$marker.installationId -eq 'codex-usage-capsule' -and ([IO.Path]::GetFullPath([string]$marker.installRoot)).Equals($resolvedRoot,[StringComparison]::OrdinalIgnoreCase)
    }catch{}
}
$task=Get-ScheduledTask -TaskName 'CodexUsageCapsule' -TaskPath '\' -ErrorAction SilentlyContinue
$taskOwned=$false
if($null -ne $task){
    $actions=@($task.Actions)
    $expectedVbs=Join-Path $resolvedRoot 'CodexCapsule-Silent.vbs'
    $taskOwned=$actions.Count -eq 1 -and [IO.Path]::GetFileName($actions[0].Execute) -ieq 'wscript.exe' -and $actions[0].Arguments.Trim('"').Equals($expectedVbs,[StringComparison]::OrdinalIgnoreCase)
}
$statusPath=Join-Path $env:LOCALAPPDATA 'CodexUsageCapsule\status.json'
$runtime=$null
if(Test-Path -LiteralPath $statusPath){try{$runtime=Get-Content -LiteralPath $statusPath -Raw|ConvertFrom-Json}catch{}}
$alive=$false
if($null -ne $runtime -and $runtime.pid){
    $process=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$runtime.pid)" -ErrorAction SilentlyContinue
    $expectedScript=Join-Path $resolvedRoot 'Capsule.Windows.ps1'
    $alive=$null -ne $process -and $process.Name -eq 'powershell.exe' -and $process.CommandLine.IndexOf($expectedScript,[StringComparison]::OrdinalIgnoreCase) -ge 0
}
$result=[pscustomobject]@{
    Installed=$installed
    InstallRoot=$resolvedRoot
    StartupRegistered=($null -ne $task)
    StartupOwned=$taskOwned
    StartupEnabled=if($taskOwned){[bool]$task.Settings.Enabled}else{$false}
    TaskState=if($null -ne $task){[string]$task.State}else{'NotInstalled'}
    ProcessAlive=$alive
    Runtime=$runtime
}
if($Json){$result|ConvertTo-Json -Depth 8}else{$result}
