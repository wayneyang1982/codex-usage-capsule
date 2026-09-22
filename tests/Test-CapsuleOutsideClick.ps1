$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Native.cs')
function Rect([int]$left,[int]$top,[int]$right,[int]$bottom){
    $r=New-Object CapsuleNative+RECT
    $r.Left=$left;$r.Top=$top;$r.Right=$right;$r.Bottom=$bottom
    return $r
}
$capsule=Rect 100 100 240 140
$panel=Rect 100 148 390 450
foreach($point in @(@(100,100),@(239,139),@(100,148),@(389,449))){
    if([CapsuleOutsideClick]::IsOutside($point[0],$point[1],$capsule,$panel)){throw "Internal click counted as outside: $point"}
}
foreach($point in @(@(99,100),@(240,139),@(100,141),@(390,449),@(200,450))){
    if(![CapsuleOutsideClick]::IsOutside($point[0],$point[1],$capsule,$panel)){throw "External click was ignored: $point"}
}
Write-Output 'PASS: capsule/panel hit tests and outside click boundaries'
