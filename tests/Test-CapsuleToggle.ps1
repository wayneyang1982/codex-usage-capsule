$ErrorActionPreference='Stop'
$path=Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Windows.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$null)
function Handler($name){
    $node=$ast.Find({param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -eq $name},$true)
    [scriptblock]::Create($node.Arguments[0].ScriptBlock.Extent.Text.TrimStart('{').TrimEnd('}'))
}
$down=Handler 'add_PreviewMouseLeftButtonDown'
$up=Handler 'add_MouseLeftButtonUp'
$popup=[pscustomobject]@{IsOpen=$false}
$panelBorder=New-Object psobject
$panelBorder | Add-Member ScriptMethod Focus {$true}
function Build-Details {}
function Press($stamp){[pscustomobject]@{Timestamp=$stamp;Handled=$false} | ForEach-Object $down}
function Release{[pscustomobject]@{Handled=$false} | ForEach-Object $up}
$script:closedPressStamp=$null;$script:suppressTriggerRelease=$false
Press 100;Release
if(!$popup.IsOpen){throw 'Initial click must open'}
# WPF outside-capture closes first, on the same mouse-down message.
$popup.IsOpen=$false;$script:closedPressStamp=200;$script:suppressTriggerRelease=$true
Press 200;Release
if($popup.IsOpen){throw 'Dismissal click reopened popup'}
Press 201;Release
if(!$popup.IsOpen){throw 'Immediate next click must reopen; no debounce'}
# Closing click can be consumed by capture without reaching the trigger.
$popup.IsOpen=$false;$script:closedPressStamp=300;$script:suppressTriggerRelease=$true
Press 301;Release
if(!$popup.IsOpen){throw 'Consumed outside click blocked subsequent trigger click'}
# Release delivered without a trigger down must also stay closed.
$popup.IsOpen=$false;$script:closedPressStamp=400;$script:suppressTriggerRelease=$true
Release
if($popup.IsOpen){throw 'Orphan release reopened popup'}
Write-Output 'PASS: actual trigger handlers / open, close-race, immediate reopen, consumed click, release-only'
