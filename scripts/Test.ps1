[CmdletBinding()]
param([switch]$RequireInstalledCodex)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$parseTargets=@(Get-ChildItem (Join-Path $repoRoot 'src'),(Join-Path $repoRoot 'scripts'),(Join-Path $repoRoot 'tests') -Include '*.ps1','*.psm1' -Recurse)
foreach($file in $parseTargets){
    $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$null,[ref]$errors)
    if($errors.Count){throw "Parse errors in $($file.FullName): $($errors|Out-String)"}
}
Get-ChildItem (Join-Path $repoRoot 'tests') -Filter 'Test-*.ps1' | Sort-Object Name | ForEach-Object {
    $arguments=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$_.FullName)
    if($RequireInstalledCodex -and $_.Name -eq 'Test-CapsuleHost.ps1'){$arguments+='-RequireInstalledCodex'}
    & powershell.exe @arguments
    if($LASTEXITCODE -ne 0){throw "Test failed: $($_.Name)"}
}
Write-Output "PASS: parsed $($parseTargets.Count) PowerShell files and completed all tests"
