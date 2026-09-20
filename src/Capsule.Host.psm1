Set-StrictMode -Version Latest

function Get-CodexDesktopProcesses {
    @(Get-Process -Name 'ChatGPT' -ErrorAction SilentlyContinue | Where-Object {
        try {
            $candidate=Join-Path (Split-Path $_.Path -Parent) 'resources\codex.exe'
            Test-Path -LiteralPath $candidate -PathType Leaf
        } catch { $false }
    })
}

function Test-CodexDesktopProcess {
    param([Parameter(Mandatory)]$Process)
    try {
        if($Process.ProcessName -ne 'ChatGPT'){return $false}
        return Test-Path -LiteralPath (Join-Path (Split-Path $Process.Path -Parent) 'resources\codex.exe') -PathType Leaf
    } catch { return $false }
}

function Quote-CapsuleArgument {
    param([Parameter(Mandatory)][string]$Value)
    if($Value.Contains('"')){throw 'Executable paths containing quotation marks are not supported.'}
    return '"'+$Value+'"'
}

function New-CapsuleLaunchSpec {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [string]$ArgumentsPrefix='',
        [Parameter(Mandatory)][ValidateSet('standalone','npm')][string]$Distribution
    )
    [pscustomobject]@{
        Executable=[IO.Path]::GetFullPath($Executable)
        ArgumentsPrefix=$ArgumentsPrefix
        Distribution=$Distribution
    }
}

function Find-CodexAppServerLaunchSpec {
    # The executable inside the packaged Codex Desktop app is intentionally not
    # used here. Windows package ACLs do not expose it as a public process entry
    # point. Resolve only user-callable Codex CLI installations.
    $nativeCandidates=[Collections.Generic.List[string]]::new()
    if($env:CODEX_INSTALL_DIR){$nativeCandidates.Add((Join-Path $env:CODEX_INSTALL_DIR 'codex.exe'))}
    if($env:LOCALAPPDATA){$nativeCandidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe'))}
    $native=Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($null -ne $native){$nativeCandidates.Add($native.Source)}
    foreach($candidate in $nativeCandidates){
        if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){
            return New-CapsuleLaunchSpec -Executable (Resolve-Path -LiteralPath $candidate).Path -Distribution standalone
        }
    }

    $cmd=Get-Command codex.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($null -ne $cmd){
        $npmRoot=Split-Path $cmd.Source -Parent
        $script=Join-Path $npmRoot 'node_modules\@openai\codex\bin\codex.js'
        if(Test-Path -LiteralPath $script -PathType Leaf){
            $nodeCandidate=Join-Path $npmRoot 'node.exe'
            if(!(Test-Path -LiteralPath $nodeCandidate -PathType Leaf)){
                $node=Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
                if($null -ne $node){$nodeCandidate=$node.Source}
            }
            if(Test-Path -LiteralPath $nodeCandidate -PathType Leaf){
                return New-CapsuleLaunchSpec -Executable (Resolve-Path -LiteralPath $nodeCandidate).Path -ArgumentsPrefix (Quote-CapsuleArgument (Resolve-Path -LiteralPath $script).Path) -Distribution npm
            }
        }
    }
    throw ('Codex CLI was not found. Install the official Windows CLI, then run Codex once to sign in. '+
        'See https://developers.openai.com/codex/cli')
}

function Get-CodexAppServerArguments {
    param([Parameter(Mandatory)]$LaunchSpec)
    $parts=@()
    if($LaunchSpec.ArgumentsPrefix){$parts+=[string]$LaunchSpec.ArgumentsPrefix}
    $parts+='app-server'
    $parts+='--listen stdio://'
    return ($parts -join ' ')
}

Export-ModuleMember -Function Get-CodexDesktopProcesses,Test-CodexDesktopProcess,Find-CodexAppServerLaunchSpec,Get-CodexAppServerArguments
