function Set-CapsuleFit {
    param($Border, $Text, $Arrow, [string]$FullText, [double]$Available)
    # Measure actual WPF glyphs at the current font size; never shrink the font.
    $variants=@(
        @{Text=$FullText;Pad=10;Gap=7;Mode='full'},
        @{Text=($FullText -replace '\s*\|\s*','|' -replace '\s*\u00b7\s*',[string][char]0x00b7);Pad=5;Gap=4;Mode='compact'},
        @{Text='Usage';Pad=5;Gap=4;Mode='entry'},
        @{Text='';Pad=5;Gap=0;Mode='arrow'}
    )
    foreach($variant in $variants){
        $Text.Text=$variant.Text
        $Border.Padding=[System.Windows.Thickness]::new($variant.Pad,4,$variant.Pad,4)
        $Arrow.Margin=[System.Windows.Thickness]::new($variant.Gap,0,0,0)
        $Text.InvalidateMeasure()
        $Arrow.InvalidateMeasure()
        $Border.Child.InvalidateMeasure()
        $Border.InvalidateMeasure()
        $Border.Measure([System.Windows.Size]::new([double]::PositiveInfinity,[double]::PositiveInfinity))
        if($Border.DesiredSize.Width -le $Available){return $variant.Mode}
    }
    # No safe title-bar pixels at all: do not cover Help or caption buttons.
    return 'unavailable'
}
