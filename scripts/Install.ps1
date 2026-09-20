[CmdletBinding()]
param(
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Programs\CodexUsageCapsule'),
    [switch]$NoStartup,
    [switch]$NoStart
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:OS -ne 'Windows_NT'){throw 'Codex Usage Capsule currently supports Windows only.'}
if($PSVersionTable.PSVersion.Major -lt 5){throw 'Windows PowerShell 5.1 or later is required.'}
$repoRoot=Split-Path $PSScriptRoot -Parent
$sourceRoot=Join-Path $repoRoot 'src'
Import-Module (Join-Path $sourceRoot 'Capsule.Host.psm1') -Force
$codexLaunch=Find-CodexAppServerLaunchSpec
$resolvedRoot=[IO.Path]::GetFullPath($InstallRoot)
$taskName='CodexUsageCapsule'
$expectedVbs=Join-Path $resolvedRoot 'CodexCapsule-Silent.vbs'
$runtimeFiles=@('Capsule.Windows.ps1','Capsule.Model.psm1','Capsule.Layout.ps1','Capsule.Native.cs','Capsule.Startup.psm1','Capsule.Host.psm1','MenuAnchor.cs','CodexCapsule-Silent.vbs')
foreach($name in $runtimeFiles){if(!(Test-Path -LiteralPath (Join-Path $sourceRoot $name) -PathType Leaf)){throw "Missing release file: $name"}}
function Assert-SafeInstallRoot {
    $target=$resolvedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)
    $protected=@([IO.Path]::GetPathRoot($target),$env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA,[IO.Path]::GetTempPath()) | Where-Object {$_} | ForEach-Object {[IO.Path]::GetFullPath($_).TrimEnd([IO.Path]::DirectorySeparatorChar)}
    foreach($path in $protected){
        if($path.Equals($target,[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($target+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe install root: $resolvedRoot"}
    }
}
Assert-SafeInstallRoot
$markerPath=Join-Path $resolvedRoot '.codex-usage-capsule-install.json'
if(Test-Path -LiteralPath $resolvedRoot -PathType Container){
    $entries=@(Get-ChildItem -LiteralPath $resolvedRoot -Force)
    if($entries.Count -and !(Test-Path -LiteralPath $markerPath -PathType Leaf)){throw "Install directory is not empty and is not owned by Codex Usage Capsule: $resolvedRoot"}
    if(Test-Path -LiteralPath $markerPath -PathType Leaf){
        $oldMarker=Get-Content -LiteralPath $markerPath -Raw|ConvertFrom-Json
        if($oldMarker.installationId -ne 'codex-usage-capsule' -or !([IO.Path]::GetFullPath([string]$oldMarker.installRoot).Equals($resolvedRoot,[StringComparison]::OrdinalIgnoreCase))){throw 'Existing installation marker does not match the requested directory.'}
    }
}
function Stop-CapsuleProcess {
    $statusPath=Join-Path $env:LOCALAPPDATA 'CodexUsageCapsule\status.json'
    if(!(Test-Path -LiteralPath $statusPath)){return}
    try{$pidToStop=[int](Get-Content -LiteralPath $statusPath -Raw|ConvertFrom-Json).pid}catch{return}
    $root=Get-CimInstance Win32_Process -Filter "ProcessId=$pidToStop" -ErrorAction SilentlyContinue
    $expectedScript=[IO.Path]::Combine($resolvedRoot,'Capsule.Windows.ps1')
    if($null -eq $root -or $root.Name -ne 'powershell.exe' -or $root.CommandLine.IndexOf($expectedScript,[StringComparison]::OrdinalIgnoreCase) -lt 0){return}
    $snapshot=@(Get-CimInstance Win32_Process);$owned=[Collections.Generic.List[int]]::new();$owned.Add($pidToStop)
    for($i=0;$i -lt $owned.Count;$i++){foreach($child in $snapshot){if($child.ParentProcessId -eq $owned[$i]){$owned.Add([int]$child.ProcessId)}}}
    for($i=$owned.Count-1;$i -ge 0;$i--){Stop-Process -Id $owned[$i] -ErrorAction SilentlyContinue}
}
$existing=Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
if($null -ne $existing){
    $actions=@($existing.Actions)
    if($actions.Count -ne 1 -or [IO.Path]::GetFileName($actions[0].Execute) -ine 'wscript.exe' -or !($actions[0].Arguments.Trim('"').Equals($expectedVbs,[StringComparison]::OrdinalIgnoreCase))){throw "Scheduled task '$taskName' exists but is not owned by this Codex Usage Capsule installation."}
    Stop-ScheduledTask -InputObject $existing -ErrorAction SilentlyContinue
}
Stop-CapsuleProcess
[void][IO.Directory]::CreateDirectory($resolvedRoot)
foreach($name in $runtimeFiles){Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination (Join-Path $resolvedRoot $name) -Force}
$marker=@{product='Codex Usage Capsule';installationId='codex-usage-capsule';installRoot=$resolvedRoot;installedAt=[DateTimeOffset]::UtcNow.ToString('o');codexDistribution=$codexLaunch.Distribution;codexExecutable=$codexLaunch.Executable}
[IO.File]::WriteAllText((Join-Path $resolvedRoot '.codex-usage-capsule-install.json'),($marker|ConvertTo-Json))
if(!$NoStartup){
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action=New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $expectedVbs) -WorkingDirectory $resolvedRoot
    $trigger=New-ScheduledTaskTrigger -AtLogOn -User $identity
    $trigger.Delay='PT1M'
    $principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $task=New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Codex Usage Capsule: local Codex quota and pace widget.'
    Register-ScheduledTask -TaskName $taskName -TaskPath '\' -InputObject $task -Force | Out-Null
}
if(!$NoStart){
    if(!$NoStartup){Start-ScheduledTask -TaskName $taskName}
    else{Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f (Join-Path $resolvedRoot 'Capsule.Windows.ps1')) -WindowStyle Hidden}
}
[pscustomobject]@{Installed=$true;InstallRoot=$resolvedRoot;StartupEnabled=(-not $NoStartup);Started=(-not $NoStart);CodexDistribution=$codexLaunch.Distribution;CodexExecutable=$codexLaunch.Executable}
