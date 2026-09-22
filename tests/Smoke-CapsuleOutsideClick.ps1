$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Native.cs')
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class CapsuleSmokeMessage{[DllImport("user32.dll")]public static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,IntPtr l);}'
$window=New-Object System.Windows.Window
$window.WindowStyle='None';$window.ShowInTaskbar=$false;$window.ShowActivated=$false
$window.Opacity=0;$window.Left=-10000;$window.Top=-10000;$window.Width=80;$window.Height=60
$target=New-Object System.Windows.Controls.Border
$window.Content=$target
$popup=New-Object System.Windows.Controls.Primitives.Popup
$popup.PlacementTarget=$target;$popup.StaysOpen=$false
$panel=New-Object System.Windows.Controls.Border
$panel.Width=40;$panel.Height=40;$popup.Child=$panel
$watcher=New-Object CapsuleOutsideClick
try {
    $window.Show()
    $widgetHandle=[System.Windows.Interop.WindowInteropHelper]::new($window).Handle
    $popup.IsOpen=$true
    $panelSource=[System.Windows.PresentationSource]::FromVisual($panel)
    if($panelSource -isnot [System.Windows.Interop.HwndSource]){throw 'Popup HWND unavailable'}
    if(!$watcher.Start($widgetHandle,$panelSource.Handle)){
        throw "Low-level mouse hook unavailable: $($watcher.LastError)"
    }
    if(!$watcher.Active){throw 'Hook did not remain active'}
    $source=[System.Windows.Interop.HwndSource]::FromHwnd($widgetHandle)
    $messageHook=[System.Windows.Interop.HwndSourceHook]{
        param($hwnd,$msg,$wParam,$lParam,[ref]$handled)
        if($msg -eq [CapsuleOutsideClick]::OutsideMessage){
            if($popup.IsOpen -and $wParam.ToInt64() -eq $watcher.Generation){$popup.IsOpen=$false}
            $handled=$true
        }
        return [IntPtr]::Zero
    }
    $source.AddHook($messageHook)
    [void][CapsuleSmokeMessage]::SendMessage($widgetHandle,[CapsuleOutsideClick]::OutsideMessage,[IntPtr]$watcher.Generation,[IntPtr]::Zero)
    if($popup.IsOpen){throw 'Outside-click message did not close popup'}
    $oldGeneration=$watcher.Generation
    $watcher.Stop();$popup.IsOpen=$true
    if(!$watcher.Start($widgetHandle,$panelSource.Handle)){throw 'Hook did not restart'}
    [void][CapsuleSmokeMessage]::SendMessage($widgetHandle,[CapsuleOutsideClick]::OutsideMessage,[IntPtr]$oldGeneration,[IntPtr]::Zero)
    if(!$popup.IsOpen){throw 'Stale outside click closed a new popup session'}
    [void][CapsuleSmokeMessage]::SendMessage($widgetHandle,[CapsuleOutsideClick]::OutsideMessage,[IntPtr]$watcher.Generation,[IntPtr]::Zero)
    if($popup.IsOpen){throw 'Current outside click did not close popup'}
    $source.RemoveHook($messageHook)
    Write-Output 'PASS: native popup HWND, temporary mouse hook, and close message'
} finally {
    $watcher.Dispose()
    $popup.IsOpen=$false
    $window.Close()
}
