[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs\CodexUsageCapsule'),
    [switch]$RemoveSettings
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$resolvedRoot=[IO.Path]::GetFullPath($InstallRoot)
function Assert-SafeInstallRoot {
    $target=$resolvedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)
    $protected=@([IO.Path]::GetPathRoot($target),$env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA,[IO.Path]::GetTempPath()) | Where-Object {$_} | ForEach-Object {[IO.Path]::GetFullPath($_).TrimEnd([IO.Path]::DirectorySeparatorChar)}
    foreach($path in $protected){
        if($path.Equals($target,[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($target+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe install root: $resolvedRoot"}
    }
}
Assert-SafeInstallRoot
$markerPath=Join-Path $resolvedRoot '.codex-usage-capsule-install.json'
if(!(Test-Path -LiteralPath $markerPath -PathType Leaf)){throw "Installation marker not found: $markerPath"}
$marker=Get-Content -LiteralPath $markerPath -Raw|ConvertFrom-Json
if($marker.installationId -ne 'codex-usage-capsule' -or [IO.Path]::GetFullPath([string]$marker.installRoot) -ne $resolvedRoot){throw 'Installation marker does not match the requested directory.'}
$taskName='CodexUsageCapsule'
$task=Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
if($null -ne $task){
    $actions=@($task.Actions)
    if($actions.Count -ne 1 -or [IO.Path]::GetFileName($actions[0].Execute) -ine 'wscript.exe' -or $actions[0].Arguments.Trim('"') -ine (Join-Path $resolvedRoot 'CodexCapsule-Silent.vbs')){throw "Scheduled task '$taskName' is not owned by this installation."}
}
if($PSCmdlet.ShouldProcess($resolvedRoot,'Uninstall Codex Usage Capsule')){
    if($null -ne $task){Stop-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue}
    $statusPath=Join-Path $env:LOCALAPPDATA 'CodexUsageCapsule\status.json'
    if(Test-Path -LiteralPath $statusPath){
        try{$pidToStop=[int](Get-Content -LiteralPath $statusPath -Raw|ConvertFrom-Json).pid}catch{$pidToStop=0}
        if($pidToStop){
            $root=Get-CimInstance Win32_Process -Filter "ProcessId=$pidToStop" -ErrorAction SilentlyContinue
            $expectedScript=[IO.Path]::Combine($resolvedRoot,'Capsule.Windows.ps1')
            if($null -ne $root -and $root.Name -eq 'powershell.exe' -and $root.CommandLine.IndexOf($expectedScript,[StringComparison]::OrdinalIgnoreCase) -ge 0){
                $snapshot=@(Get-CimInstance Win32_Process);$owned=[Collections.Generic.List[int]]::new();$owned.Add($pidToStop)
                for($i=0;$i -lt $owned.Count;$i++){foreach($child in $snapshot){if($child.ParentProcessId -eq $owned[$i]){$owned.Add([int]$child.ProcessId)}}}
                for($i=$owned.Count-1;$i -ge 0;$i--){Stop-Process -Id $owned[$i] -ErrorAction SilentlyContinue}
            }
        }
    }
    if($null -ne $task){Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false}
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    if($RemoveSettings){Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'CodexUsageCapsule') -Recurse -Force -ErrorAction SilentlyContinue}
}
[pscustomobject]@{Uninstalled=$true;InstallRoot=$resolvedRoot;SettingsRemoved=[bool]$RemoveSettings}
