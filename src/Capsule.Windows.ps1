param([switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Capsule.Model.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Capsule.Startup.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Capsule.Host.psm1') -Force
. (Join-Path $PSScriptRoot 'Capsule.Layout.ps1')
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, UIAutomationClient, UIAutomationTypes
Add-Type -Path (Join-Path $PSScriptRoot 'Capsule.Native.cs')
Add-Type -Path (Join-Path $PSScriptRoot 'MenuAnchor.cs') -ReferencedAssemblies @([System.Windows.Automation.AutomationElement].Assembly.Location,[System.Windows.Automation.ControlType].Assembly.Location,[System.Windows.Rect].Assembly.Location)
try { [void][CapsuleNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) } catch {}
$created=$false
$mutexName=if($SmokeTest){'Local\CodexUsageCapsuleSmoke'}else{'Local\CodexUsageCapsule'}
$mutex=New-Object System.Threading.Mutex($true, $mutexName, [ref]$created)
if (!$created) { $mutex.Dispose(); exit }
$script:payload=$null
$script:lastRead=[DateTimeOffset]::MinValue
$script:nextRefresh=[DateTimeOffset]::MinValue
$script:nextStart=[DateTimeOffset]::MinValue
$script:serverInitialized=$false
$script:requestId=10
$script:serverError=''
$script:outsideHookError=''
$script:hostHandle=[IntPtr]::Zero
$script:forceExit=$false
$script:lastVisual=''
$script:bounds=$null
$script:reader=New-Object CapsuleReader
$script:model=Get-CapsuleModel $null
$script:diagnostic=Join-Path $env:LOCALAPPDATA $(if($SmokeTest){'CodexUsageCapsule\smoke-status.json'}else{'CodexUsageCapsule\status.json'})
$script:lastDiagnostic=''
$script:nextDiagnostic=[DateTimeOffset]::MinValue
$script:themePath=Join-Path $env:LOCALAPPDATA 'CodexUsageCapsule\appearance.json'
$script:themeMode='Light'
try {
    $savedTheme=Get-Content -LiteralPath $script:themePath -Raw -ErrorAction Stop | ConvertFrom-Json
    if($savedTheme.mode -in @('Light','Dark','System')){$script:themeMode=$savedTheme.mode}
} catch {}
$script:themeKey=''
$script:nextThemeCheck=[DateTimeOffset]::MinValue
$script:startupEnabled=$null
$script:startupError=''
try {$script:startupEnabled=[bool](Get-CapsuleStartupEnabled)}
catch {$script:startupError=$_.Exception.Message}
function Get-CapsuleLight {
    if($script:themeMode -ne 'System'){return $script:themeMode -eq 'Light'}
    try { return (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme).AppsUseLightTheme -eq 1 } catch {return $true}
}
function Set-CapsuleTheme {
    $light=Get-CapsuleLight
    $border.Background=Brush $(if($light){'#ECEBF0'}else{'#34363C'})
    $border.BorderBrush=Brush $(if($light){'#C9C7D0'}else{'#62646D'})
    $text.Foreground=Brush $(if($light){'#303139'}else{'#F0F0F3'})
    $arrow.Foreground=Brush $(if($light){'#70717B'}else{'#BEC1C9'})
    $script:themeKey="$($script:themeMode)/$light"
}
function Write-Status([string]$state) {
    if ($state -eq $script:lastDiagnostic -and [DateTimeOffset]::UtcNow -lt $script:nextDiagnostic) { return }
    $script:lastDiagnostic=$state
    $script:nextDiagnostic=[DateTimeOffset]::UtcNow.AddSeconds(15)
    # Runtime status only; no account identifiers, tokens, or credentials.
    $folder=Split-Path $script:diagnostic
    [void][IO.Directory]::CreateDirectory($folder)
    [IO.File]::WriteAllText($script:diagnostic, (@{pid=$PID;state=$state;text=$script:model.Text;rows=$script:model.Rows.Count;updated=[DateTimeOffset]::UtcNow.ToString('o');bounds=$script:bounds;appServerPid=$script:reader.ProcessId;lastError=$script:serverError;outsideClickError=$script:outsideHookError} | ConvertTo-Json -Depth 4))
}
function Brush([string]$color) { [System.Windows.Media.BrushConverter]::new().ConvertFromString($color) }
function Label([string]$value,[double]$size=12,[string]$color='#EDEDEF') {
    $t=New-Object System.Windows.Controls.TextBlock
    $t.Text=$value;$t.FontSize=$size;$t.Foreground=Brush $color;$t.FontFamily=[System.Windows.Media.FontFamily]::new('Segoe UI')
    return $t
}
$window=New-Object System.Windows.Window
$window.Title='Codex Capsule';$window.WindowStyle='None';$window.ResizeMode='NoResize';$window.AllowsTransparency=$true
$window.Background=[System.Windows.Media.Brushes]::Transparent;$window.ShowInTaskbar=$false;$window.ShowActivated=$false;$window.Topmost=$true;$window.SizeToContent='WidthAndHeight'
$border=New-Object System.Windows.Controls.Border
$border.CornerRadius=[System.Windows.CornerRadius]::new(14);$border.Padding=[System.Windows.Thickness]::new(10,4,10,4)
$border.Background=Brush '#3D4046';$border.BorderBrush=Brush '#A39780';$border.BorderThickness=[System.Windows.Thickness]::new(1)
$text=Label 'Usage --' 11
$capsuleRow=New-Object System.Windows.Controls.StackPanel
$capsuleRow.Orientation='Horizontal'
[void]$capsuleRow.Children.Add($text)
$arrow=Label ([string][char]0x25BE) 10 '#BEC1C9'
$arrow.Margin=[System.Windows.Thickness]::new(7,0,0,0)
$arrow.VerticalAlignment='Center'
[void]$capsuleRow.Children.Add($arrow)
$border.Child=$capsuleRow;$border.Cursor=[System.Windows.Input.Cursors]::Hand;$window.Content=$border
$window.Show();$widgetHandle=[System.Windows.Interop.WindowInteropHelper]::new($window).Handle
$style=[CapsuleNative]::GetWindowLongPtr($widgetHandle,-20).ToInt64() -bor 0x80 -bor 0x08000000
[void][CapsuleNative]::SetWindowLongPtr($widgetHandle,-20,[IntPtr]$style)
$window.Hide()
# WPF's outside-click capture is a fallback; the no-activate capsule also uses
# a mouse-down watcher only while details are open.
$popup=New-Object System.Windows.Controls.Primitives.Popup
$popup.PlacementTarget=$border;$popup.Placement='Bottom';$popup.VerticalOffset=8;$popup.StaysOpen=$false;$popup.AllowsTransparency=$true
$panelBorder=New-Object System.Windows.Controls.Border
$panelBorder.Width=290;$panelBorder.Padding=[System.Windows.Thickness]::new(18);$panelBorder.CornerRadius=[System.Windows.CornerRadius]::new(14)
$panelBorder.BorderThickness=[System.Windows.Thickness]::new(1)
$stack=New-Object System.Windows.Controls.StackPanel;$panelBorder.Child=$stack;$popup.Child=$panelBorder
$panelBorder.Focusable=$true
$panelBorder.add_PreviewKeyDown({if ($_.Key -eq [System.Windows.Input.Key]::Escape) {$popup.IsOpen=$false;$_.Handled=$true}})
$script:outsideClick=New-Object CapsuleOutsideClick
$script:widgetSource=[System.Windows.Interop.HwndSource]::FromHwnd($widgetHandle)
$script:outsideMessageHook=[System.Windows.Interop.HwndSourceHook]{
    param($hwnd,$msg,$wParam,$lParam,[ref]$handled)
    if($msg -eq [CapsuleOutsideClick]::OutsideMessage){
        if($popup.IsOpen -and $wParam.ToInt64() -eq $script:outsideClick.Generation){$popup.IsOpen=$false}
        $handled=$true
    }
    return [IntPtr]::Zero
}
$script:widgetSource.AddHook($script:outsideMessageHook)
function Build-Details {
    $stack.Children.Clear()
    $light=Get-CapsuleLight
    $fg=if($light){'#292A2E'}else{'#EDEDEF'}
    $muted=if($light){'#6E7079'}else{'#ABADB6'}
    $line=if($light){'#E5E5EA'}else{'#3C3D44'}
    $panelBorder.Background=Brush $(if($light){'#FCFCFD'}else{'#242529'});$panelBorder.BorderBrush=Brush $line
    $heading=New-Object System.Windows.Controls.DockPanel
    $plan=Label $script:model.Plan 10 $muted;[System.Windows.Controls.DockPanel]::SetDock($plan,'Right');[void]$heading.Children.Add($plan)
    $title=Label 'Usage' 14 $fg;$title.FontWeight='SemiBold';[void]$heading.Children.Add($title);[void]$stack.Children.Add($heading)
    foreach($row in $script:model.Rows) {
        $group=New-Object System.Windows.Controls.StackPanel;$group.Margin=[System.Windows.Thickness]::new(0,18,0,0)
        $name=if($row.Label -eq '7d'){'Weekly'}elseif($row.Label -eq '5h'){'5-hour'}else{"$($row.Label) window"}
        $head=New-Object System.Windows.Controls.DockPanel
        $used=Label $(if($row.Expired){'Refreshing...'}else{"$($row.Used)% used"}) 11 $muted
        [System.Windows.Controls.DockPanel]::SetDock($used,'Right');[void]$head.Children.Add($used);[void]$head.Children.Add((Label $name 12 $fg));[void]$group.Children.Add($head)
        $track=New-Object System.Windows.Controls.Canvas;$track.Height=12;$track.Margin=[System.Windows.Thickness]::new(0,10,0,8)
        $rail=New-Object System.Windows.Shapes.Rectangle;$rail.Width=252;$rail.Height=5;$rail.RadiusX=2.5;$rail.RadiusY=2.5;$rail.Fill=Brush $line
        [System.Windows.Controls.Canvas]::SetTop($rail,3);[void]$track.Children.Add($rail)
        if(!$row.Expired){$fill=New-Object System.Windows.Shapes.Rectangle;$fill.Width=252*[Math]::Min(100,$row.Used)/100;$fill.Height=5;$fill.RadiusX=2.5;$fill.RadiusY=2.5;$fill.Fill=Brush '#8D9CAB';[System.Windows.Controls.Canvas]::SetTop($fill,3);[void]$track.Children.Add($fill)}
        $tick=New-Object System.Windows.Shapes.Rectangle;$tick.Width=2;$tick.Height=11;$tick.Fill=Brush $fg;[System.Windows.Controls.Canvas]::SetLeft($tick,[Math]::Min(250,252*$row.Pace/100));[void]$track.Children.Add($tick);[void]$group.Children.Add($track)
        $foot=New-Object System.Windows.Controls.DockPanel
        $reset=Label "Resets in $($row.Remaining)" 10 $muted;[System.Windows.Controls.DockPanel]::SetDock($reset,'Right');[void]$foot.Children.Add($reset);[void]$foot.Children.Add((Label "Time elapsed $($row.Pace)%" 10 $muted));[void]$group.Children.Add($foot);[void]$stack.Children.Add($group)
    }
    if(!$script:model.Rows.Count){$empty=Label 'Usage data unavailable.' 12 $muted;$empty.Margin=[System.Windows.Thickness]::new(0,18,0,0);[void]$stack.Children.Add($empty)}
    $legend=Label "Bar: used quota   |   Marker: elapsed time" 10 $muted;$legend.Margin=[System.Windows.Thickness]::new(0,18,0,0);[void]$stack.Children.Add($legend)
    $age=if($script:lastRead -eq [DateTimeOffset]::MinValue){'Waiting for official data'}else{'Updated '+$script:lastRead.ToLocalTime().ToString('HH:mm:ss')}
    $stamp=Label $age 10 $muted;$stamp.Margin=[System.Windows.Thickness]::new(0,5,0,0);[void]$stack.Children.Add($stamp)
    $buttons=New-Object System.Windows.Controls.StackPanel;$buttons.Orientation='Horizontal';$buttons.Margin=[System.Windows.Thickness]::new(0,14,0,0)
    foreach($caption in @('Refresh','Exit')) {
        $button=New-Object System.Windows.Controls.Button;$button.Content=$caption;$button.FontSize=11;$button.Padding=[System.Windows.Thickness]::new(10,4,10,4);$button.Margin=[System.Windows.Thickness]::new(0,0,8,0)
        $button.Background=[System.Windows.Media.Brushes]::Transparent;$button.Foreground=Brush $fg;$button.BorderBrush=Brush $line
        if($caption -eq 'Refresh'){$button.add_Click({$script:nextRefresh=[DateTimeOffset]::MinValue;$popup.IsOpen=$false})}else{$button.add_Click({$script:forceExit=$true;$popup.IsOpen=$false;$window.Close()})}
        [void]$buttons.Children.Add($button)
    };[void]$stack.Children.Add($buttons)
    $themeLabel=Label 'Appearance' 10 $muted;$themeLabel.Margin=[System.Windows.Thickness]::new(0,14,0,6);[void]$stack.Children.Add($themeLabel)
    $themeButtons=New-Object System.Windows.Controls.StackPanel;$themeButtons.Orientation='Horizontal'
    foreach($mode in @('Light','Dark','System')){
        $choice=New-Object System.Windows.Controls.Button;$choice.Content=$mode;$choice.Tag=$mode
        $choice.FontSize=10;$choice.Padding=[System.Windows.Thickness]::new(9,4,9,4);$choice.Margin=[System.Windows.Thickness]::new(0,0,6,0)
        $choice.Foreground=Brush $fg;$choice.BorderBrush=Brush $line
        $choice.Background=if($mode -eq $script:themeMode){Brush $line}else{[System.Windows.Media.Brushes]::Transparent}
        $choice.ToolTip=if($mode -eq 'System'){'Follow Windows appearance (not Codex app settings)'}else{"Use $mode appearance"}
        $choice.add_Click({
            param($sender,$eventArgs)
            $script:themeMode=[string]$sender.Tag
            [void][IO.Directory]::CreateDirectory((Split-Path $script:themePath))
            [IO.File]::WriteAllText($script:themePath,(@{mode=$script:themeMode}|ConvertTo-Json))
            Set-CapsuleTheme
            Build-Details
        })
        [void]$themeButtons.Children.Add($choice)
    }
    [void]$stack.Children.Add($themeButtons)
    $startup=New-Object System.Windows.Controls.CheckBox
    $startup.Content='Start at sign-in';$startup.FontSize=11;$startup.Foreground=Brush $fg
    $startup.Margin=[System.Windows.Thickness]::new(0,16,0,0)
    $startup.ToolTip='Start silently one minute after Windows sign-in. Turning this off does not exit the current capsule.'
    if($null -ne $script:startupEnabled){$startup.IsChecked=$script:startupEnabled;$startup.Tag=$script:startupEnabled}
    else{$startup.IsEnabled=$false;$startup.ToolTip='Startup task unavailable: '+$script:startupError}
    $startup.add_Click({
        param($sender,$eventArgs)
        try{
            $sender.IsEnabled=$false
            $confirmed=Set-CapsuleStartupEnabled -Enabled ([bool]$sender.IsChecked)
            $script:startupEnabled=$confirmed
            $sender.IsChecked=$confirmed;$sender.Tag=$confirmed
        }catch{
            $sender.IsChecked=[bool]$sender.Tag
            [void][System.Windows.MessageBox]::Show(('Could not update startup: '+$_.Exception.Message),'Codex Capsule')
        }finally{$sender.IsEnabled=$true}
    })
    [void]$stack.Children.Add($startup)
}
Set-CapsuleTheme
# Outside-capture dismissal happens on mouse DOWN, before the trigger receives
# mouse UP. Track the exact Windows message, not a debounce timeout: consume
# that release without reopening, but allow a new press immediately.
$script:closedPressStamp=$null
$script:suppressTriggerRelease=$false
$popup.add_Opened({
    $arrow.Text=[string][char]0x25B4
    $script:outsideHookError=''
    try {
        $panelSource=[System.Windows.PresentationSource]::FromVisual($panelBorder)
        if($panelSource -isnot [System.Windows.Interop.HwndSource]){throw 'Popup window handle unavailable'}
        if(!$script:outsideClick.Start($widgetHandle,$panelSource.Handle)){
            throw "Mouse watcher unavailable (Win32 $($script:outsideClick.LastError))"
        }
    } catch {$script:outsideHookError=$_.Exception.Message}
})
$popup.add_Closed({
    $script:outsideClick.Stop()
    $arrow.Text=[string][char]0x25BE
    if([System.Windows.Input.Mouse]::LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed){
        $script:closedPressStamp=[CapsuleNative]::GetMessageTime()
        $script:suppressTriggerRelease=$true
    }
})
$border.add_PreviewMouseLeftButtonDown({
    $script:suppressTriggerRelease=($null -ne $script:closedPressStamp -and $_.Timestamp -eq $script:closedPressStamp)
})
$border.add_MouseLeftButtonUp({
    if($script:suppressTriggerRelease){$script:suppressTriggerRelease=$false}
    elseif($popup.IsOpen){$popup.IsOpen=$false}
    else{Build-Details;$popup.IsOpen=$true;[void]$panelBorder.Focus()}
    $script:closedPressStamp=$null
    $_.Handled=$true
})
function Hide-Capsule([string]$reason) {$popup.IsOpen=$false;$window.Hide();Write-Status $reason}
function Send-AppServer([hashtable]$message){$script:reader.Send(($message|ConvertTo-Json -Compress -Depth 8))}
function Request-RateLimits {
    if(!$script:reader.Running -or !$script:serverInitialized){return}
    $script:requestId++
    Send-AppServer @{method='account/rateLimits/read';id=$script:requestId}
    $script:nextRefresh=[DateTimeOffset]::UtcNow.AddSeconds(60)
}
$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(250)
$script:startTime=[DateTimeOffset]::UtcNow
$timer.add_Tick({
 try {
    $now=[DateTimeOffset]::UtcNow
    if($now -ge $script:nextThemeCheck){
        $script:nextThemeCheck=$now.AddSeconds(2)
        $currentTheme="$($script:themeMode)/$(Get-CapsuleLight)"
        if($currentTheme -ne $script:themeKey){Set-CapsuleTheme;if($popup.IsOpen){Build-Details}}
    }
    if(!$script:reader.Running -and $now -ge $script:nextStart) {
        $script:nextStart=$now.AddSeconds(20)
        $script:serverInitialized=$false
        $script:serverError=''
        $codex=Find-CodexAppServerLaunchSpec
        $script:reader.Start($codex.Executable,(Get-CodexAppServerArguments $codex))
        Send-AppServer @{method='initialize';id=0;params=@{clientInfo=@{name='codex_usage_capsule';title='Codex Usage Capsule';version='0.2.0'}}}
    }
    $output=$null
    while($script:reader.Read([ref]$output)) {
        try{
            $message=$output|ConvertFrom-Json
            if($message.id -eq 0 -and $null -ne $message.result){
                Send-AppServer @{method='initialized';params=@{}}
                $script:serverInitialized=$true
                Request-RateLimits
            } elseif($null -ne $message.result -and ($message.result.PSObject.Properties.Name -contains 'rateLimits' -or $message.result.PSObject.Properties.Name -contains 'rateLimitsByLimitId')){
                $script:payload=$message.result;$script:lastRead=$now;$script:serverError=''
            } elseif($message.method -eq 'account/rateLimits/updated'){
                $script:nextRefresh=[DateTimeOffset]::MinValue
            }
        }catch{$script:serverError='Invalid App Server response'}
    }
    $serverErrorLine=$null
    while($script:reader.ReadError([ref]$serverErrorLine)){$script:serverError=$serverErrorLine}
    if($script:reader.Running -and $now -ge $script:nextRefresh){Request-RateLimits}
    $script:model=Get-CapsuleModel $script:payload
    if(($now-$script:lastRead).TotalSeconds -gt 180){$script:model=Get-CapsuleModel $null}
    if(@($script:model.Rows|Where-Object Expired).Count -and $script:nextRefresh -gt $now.AddSeconds(10)){$script:nextRefresh=$now.AddSeconds(10)}
    if($script:lastVisual -ne $script:model.Text){$text.Text=$script:model.Text;$script:lastVisual=$text.Text;if($popup.IsOpen){Build-Details}}
    $fg=[CapsuleNative]::GetForegroundWindow();$ownerId=[uint32]0;[void][CapsuleNative]::GetWindowThreadProcessId($fg,[ref]$ownerId)
    if($ownerId -ne $PID){
        $proc=Get-Process -Id $ownerId -ErrorAction SilentlyContinue
        if($null -eq $proc -or !(Test-CodexDesktopProcess $proc)){Hide-Capsule 'host-not-foreground';return}
        $script:hostHandle=$fg
    }
    $hostHandle=$script:hostHandle
    if($hostHandle -eq [IntPtr]::Zero -or [CapsuleNative]::IsIconic($hostHandle) -or ![CapsuleNative]::IsWindowVisible($hostHandle)){Hide-Capsule 'host-hidden';return}
    $rect=New-Object CapsuleNative+RECT
    if(![CapsuleNative]::GetWindowRect($hostHandle,[ref]$rect)){Hide-Capsule 'host-unavailable';return}
    $dpi=[uint32][Math]::Max(96,[CapsuleNative]::GetDpiForWindow($hostHandle))
    $scale=$dpi/96.0
    [PaceMenuAnchor]::Request($hostHandle)
    $anchor=[PaceMenuAnchor]::Read($hostHandle,$rect.Left,$rect.Top,$rect.Right,$rect.Bottom,$dpi)
    if($null -eq $anchor){Hide-Capsule 'waiting-menu-anchor';return}
    $x=[int][Math]::Ceiling($anchor.Right+10*$scale)
    $available=($rect.Right-$x)/$scale-150
    $fit=Set-CapsuleFit -Border $border -Text $text -Arrow $arrow -FullText $script:model.Text -Available $available
    $border.ToolTip=$script:model.Text + '  (used | time elapsed)'
    if($fit -eq 'unavailable'){Hide-Capsule 'insufficient-titlebar-space';return}
    $w=[int][Math]::Ceiling($border.DesiredSize.Width*$scale);$h=[int][Math]::Ceiling($border.DesiredSize.Height*$scale);$y=[int][Math]::Round($anchor.CenterY-$h/2)
    $script:bounds=@{x=$x;y=$y;width=$w;height=$h;mode=$fit;availableDip=$available;anchorMode=$(if($anchor.Projected){'projected'}else{'verified'})}
    $popup.HorizontalOffset=[Math]::Min(0,($rect.Right-$x)/$scale-300)
    [void][CapsuleNative]::SetWindowPos($widgetHandle,[IntPtr](-1),$x,$y,$w,$h,0x10)
    if(!$window.IsVisible){$window.Show()}
    [void][CapsuleNative]::SetWindowPos($widgetHandle,[IntPtr](-1),$x,$y,$w,$h,0x50)
    Write-Status 'visible'
 } catch {Hide-Capsule ('error: '+$_.Exception.Message)}
 finally {if($SmokeTest -and ([DateTimeOffset]::UtcNow-$script:startTime).TotalSeconds -gt 12){Build-Details;Write-Status 'smoke-complete';$window.Close()}}
})
$window.add_Closed({$timer.Stop();$popup.IsOpen=$false;$script:outsideClick.Dispose();$script:widgetSource.RemoveHook($script:outsideMessageHook);$script:reader.Dispose();try{$mutex.ReleaseMutex()}catch{};$mutex.Dispose();[System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvokeShutdown([System.Windows.Threading.DispatcherPriority]::Normal)})
$timer.Start()
[void][System.Windows.Threading.Dispatcher]::Run()
