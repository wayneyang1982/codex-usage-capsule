[CmdletBinding()]
param([switch]$RequireInstalledCodex)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Host.psm1') -Force
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('codex-capsule-host-'+[guid]::NewGuid().ToString('N'))
$oldPath=$env:PATH;$oldInstallDir=$env:CODEX_INSTALL_DIR;$oldLocalAppData=$env:LOCALAPPDATA
try{
    $app=Join-Path $sandbox 'app';$resources=Join-Path $app 'resources'
    [void][IO.Directory]::CreateDirectory($resources)
    [IO.File]::WriteAllBytes((Join-Path $resources 'codex.exe'),[byte[]]@(77,90))
    $fake=[pscustomobject]@{ProcessName='ChatGPT';Path=(Join-Path $app 'ChatGPT.exe')}
    if(!(Test-CodexDesktopProcess $fake)){throw 'Valid layout was rejected'}
    $fake.Path=Join-Path $sandbox 'Other\ChatGPT.exe'
    if(Test-CodexDesktopProcess $fake){throw 'Invalid layout was accepted'}

    $standalone=Join-Path $sandbox 'standalone';[void][IO.Directory]::CreateDirectory($standalone)
    [IO.File]::WriteAllBytes((Join-Path $standalone 'codex.exe'),[byte[]]@(77,90))
    $env:CODEX_INSTALL_DIR=$standalone;$env:LOCALAPPDATA=(Join-Path $sandbox 'empty-local');$env:PATH=$sandbox
    $nativeSpec=Find-CodexAppServerLaunchSpec
    if($nativeSpec.Distribution -ne 'standalone' -or $nativeSpec.ArgumentsPrefix){throw 'Standalone CLI resolution failed'}

    $npm=Join-Path $sandbox 'npm';$js=Join-Path $npm 'node_modules\@openai\codex\bin'
    [void][IO.Directory]::CreateDirectory($js)
    [IO.File]::WriteAllBytes((Join-Path $npm 'codex.cmd'),[byte[]]@(64,69,67,72,79))
    [IO.File]::WriteAllBytes((Join-Path $npm 'node.exe'),[byte[]]@(77,90))
    [IO.File]::WriteAllText((Join-Path $js 'codex.js'),'// test fixture')
    $env:CODEX_INSTALL_DIR=(Join-Path $sandbox 'missing');$env:PATH=$npm
    $npmSpec=Find-CodexAppServerLaunchSpec
    if($npmSpec.Distribution -ne 'npm' -or $npmSpec.Executable -ne (Join-Path $npm 'node.exe') -or $npmSpec.ArgumentsPrefix -notmatch 'codex\.js"$'){throw 'npm CLI resolution failed'}

    $env:PATH=(Join-Path $sandbox 'missing-path')
    $missingFailed=$false
    try{[void](Find-CodexAppServerLaunchSpec)}catch{$missingFailed=$_.Exception.Message -match 'Codex CLI was not found'}
    if(!$missingFailed){throw 'Missing CLI must fail with actionable guidance'}
}finally{
    $env:PATH=$oldPath;$env:CODEX_INSTALL_DIR=$oldInstallDir;$env:LOCALAPPDATA=$oldLocalAppData
    if(Test-Path -LiteralPath $sandbox){Remove-Item -LiteralPath $sandbox -Recurse -Force}
}
if($RequireInstalledCodex){
    $spec=Find-CodexAppServerLaunchSpec
    if(!(Test-Path -LiteralPath $spec.Executable -PathType Leaf)){throw 'CLI executable was not resolved'}
    if($spec.Distribution -notin @('standalone','npm')){throw "Unexpected distribution: $($spec.Distribution)"}
    $arguments=Get-CodexAppServerArguments $spec
    if($arguments -notmatch 'app-server --listen stdio://$'){throw "Unexpected arguments: $arguments"}
    $processes=@(Get-CodexDesktopProcesses)
    foreach($process in $processes){if(!(Test-CodexDesktopProcess $process)){throw 'Resolver and validator disagree'}}
    Write-Output "PASS: host layout; CLI=$($spec.Distribution); desktop processes=$($processes.Count)"
}else{Write-Output 'PASS: host layout unit test'}
