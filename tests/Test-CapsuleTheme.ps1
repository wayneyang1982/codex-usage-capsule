$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
$path=Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Windows.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$null)
foreach($name in @('Brush','Get-CapsuleLight','Set-CapsuleTheme')){
    $node=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    . ([scriptblock]::Create($node.Extent.Text))
}
$border=New-Object System.Windows.Controls.Border
$text=New-Object System.Windows.Controls.TextBlock
$arrow=New-Object System.Windows.Controls.TextBlock
$script:themeMode='Light';Set-CapsuleTheme
if($border.Background.Color.ToString() -ne '#FFECEBF0' -or $text.Foreground.Color.ToString() -ne '#FF303139'){throw 'Light palette failed'}
$script:themeMode='Dark';Set-CapsuleTheme
if($border.Background.Color.ToString() -ne '#FF34363C' -or $text.Foreground.Color.ToString() -ne '#FFF0F0F3'){throw 'Dark palette failed'}
$script:themeMode='System';Set-CapsuleTheme
if($script:themeKey -notmatch '^System/(True|False)$'){throw 'System resolution failed'}
Write-Output 'PASS: actual theme functions / light, dark, system'
