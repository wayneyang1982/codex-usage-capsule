$ErrorActionPreference='Stop'
Add-Type -AssemblyName WindowsBase,UIAutomationClient,UIAutomationTypes
$source=Join-Path (Split-Path $PSScriptRoot -Parent) 'src\MenuAnchor.cs'
Add-Type -Path $source -ReferencedAssemblies @([System.Windows.Automation.AutomationElement].Assembly.Location,[System.Windows.Automation.ControlType].Assembly.Location,[System.Windows.Rect].Assembly.Location)
function Rect([int]$left,[int]$top,[int]$right,[int]$bottom){
    $r=New-Object PaceMenuAnchor+Rect
    $r.Left=$left;$r.Top=$top;$r.Right=$right;$r.Bottom=$bottom
    return $r
}
$now=[DateTime]::UtcNow
$anchor=New-Object PaceMenuAnchor+Snapshot
$anchor.Handle=[IntPtr]123
$anchor.Host=Rect 100 100 900 700
$anchor.Right=455;$anchor.CenterY=125;$anchor.Dpi=96;$anchor.Captured=$now
$same=[PaceMenuAnchor]::Project($anchor,(Rect 100 100 900 700),[uint32]96,$now)
if($null -eq $same -or $same.Translated -or $same.Right -ne 455){throw 'Verified anchor changed'}
$move=[PaceMenuAnchor]::Project($anchor,(Rect 250 180 1050 780),[uint32]96,$now)
if($null -eq $move -or !$move.Translated -or $move.Right -ne 605 -or $move.CenterY -ne 205){throw 'Window translation failed'}
if($null -ne [PaceMenuAnchor]::Project($anchor,(Rect 250 180 1040 780),[uint32]96,$now)){throw 'Resize reused stale anchor'}
if($null -ne [PaceMenuAnchor]::Project($anchor,(Rect 250 180 1050 780),[uint32]144,$now)){throw 'DPI transition reused stale anchor'}
if($null -ne [PaceMenuAnchor]::Project($anchor,(Rect 250 180 1050 780),[uint32]96,$now.AddSeconds(31))){throw 'Expired anchor was reused'}
$anchor.Right=950
if($null -ne [PaceMenuAnchor]::Project($anchor,(Rect 100 100 900 700),[uint32]96,$now)){throw 'Out-of-window anchor was accepted'}
Write-Output 'PASS: verified anchor, move projection, resize/DPI rejection, expiration and bounds'
