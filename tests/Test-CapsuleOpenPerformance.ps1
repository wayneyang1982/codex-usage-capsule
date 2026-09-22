$ErrorActionPreference='Stop'
$path=Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Windows.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$null)
$build=$ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Build-Details'},$true)
if($null -eq $build){throw 'Build-Details not found'}
$taskCalls=@($build.FindAll({param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Get-CapsuleStartupEnabled'},$true))
if($taskCalls.Count){throw 'Opening details must not query Task Scheduler synchronously'}
$source=Get-Content -LiteralPath $path -Raw
if($source -notmatch '\$script:startupEnabled=\$confirmed'){throw 'Startup cache is not updated after a user change'}
Write-Output 'PASS: details build avoids Task Scheduler and keeps startup cache current'
