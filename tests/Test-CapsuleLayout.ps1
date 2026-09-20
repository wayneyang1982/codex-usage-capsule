$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Layout.ps1')
$border=New-Object System.Windows.Controls.Border
$border.BorderThickness=[System.Windows.Thickness]::new(1)
$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$border.Child=$row
$text=New-Object System.Windows.Controls.TextBlock;$text.FontFamily=[System.Windows.Media.FontFamily]::new('Segoe UI');$text.FontSize=11
$arrow=New-Object System.Windows.Controls.TextBlock;$arrow.Text=[string][char]0x25BE;$arrow.FontSize=10
[void]$row.Children.Add($text);[void]$row.Children.Add($arrow)
foreach($value in @('7d 61% | 57%',"5h (12|87) $([char]0x00b7) 7d (61|97)", 'Usage --')){
    foreach($space in @(300,104,90,80,50,24)){
        $mode=Set-CapsuleFit $border $text $arrow $value $space
        if($mode -eq 'unavailable' -or $border.DesiredSize.Width -gt $space){throw "Does not fit: $value / $space / $mode"}
    }
    $mode=Set-CapsuleFit $border $text $arrow $value 300
    if($mode -ne 'full' -or $text.Text -ne $value){throw 'Growing window failed to restore full format'}
}
$mode=Set-CapsuleFit $border $text $arrow '7d 61% | 57%' 90
if($mode -ne 'compact'){throw "Expected percentages to fit at 90 DIP; got $mode"}
Write-Output 'PASS: actual WPF measurement / 3 formats x 6 widths, compact percentages, restored full format'
