Set-StrictMode -Version Latest
function Get-CapsuleModel {
    param($Payload, [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow)
    $bucket = $null
    if ($null -ne $Payload) {
        if ($Payload.PSObject.Properties.Name -contains 'rateLimitsByLimitId' -and $null -ne $Payload.rateLimitsByLimitId -and $Payload.rateLimitsByLimitId.PSObject.Properties.Name -contains 'codex') { $bucket = $Payload.rateLimitsByLimitId.codex }
        elseif ($Payload.PSObject.Properties.Name -contains 'rateLimits') { $bucket = $Payload.rateLimits }
    }
    $rows = @(); $plan = ''
    if ($null -ne $bucket) {
        if ($bucket.PSObject.Properties.Name -contains 'planType') { $plan = [string]$bucket.planType }
        foreach ($key in @('primary','secondary')) {
            if ($bucket.PSObject.Properties.Name -notcontains $key) { continue }
            $w = $bucket.$key
            if ($null -eq $w) { continue }
            if (@('usedPercent','windowDurationMins','resetsAt' | Where-Object { $w.PSObject.Properties.Name -notcontains $_ -or $null -eq $w.$_ }).Count) { continue }
            $duration = [double]$w.windowDurationMins
            if ($duration -le 0 -or [double]$w.usedPercent -lt 0) { continue }
            $seconds = [Math]::Max(0, [long]$w.resetsAt - $Now.ToUnixTimeSeconds())
            $pace = [Math]::Round([Math]::Max(0, [Math]::Min(100, (1 - $seconds / ($duration * 60)) * 100)))
            $label = if ($duration % 1440 -eq 0) { "$([int]($duration / 1440))d" } elseif ($duration % 60 -eq 0) { "$([int]($duration / 60))h" } else { "$($duration)m" }
            $mins = [int][Math]::Floor($seconds / 60)
            $remaining = if ($mins -ge 1440) { '{0}d {1}h' -f [Math]::Floor($mins / 1440), [Math]::Floor(($mins % 1440) / 60) } elseif ($mins -ge 60) { '{0}h {1}m' -f [Math]::Floor($mins / 60), ($mins % 60) } else { "${mins}m" }
            $rows += [pscustomobject]@{ Label=$label; Used=[int][Math]::Round([double]$w.usedPercent); Pace=[int]$pace; Duration=$duration; ResetsAt=[long]$w.resetsAt; Remaining=$remaining; Expired=($seconds -eq 0) }
        }
    }
    $rows = @($rows | Sort-Object Duration)
    $parts = @($rows | ForEach-Object {
        $usage = if ($_.Expired) { '--' } else { [string]$_.Used }
        if ($rows.Count -eq 1) { '{0} {1}% | {2}%' -f $_.Label,$usage,$_.Pace } else { '{0} ({1}|{2})' -f $_.Label,$usage,$_.Pace }
    })
    [pscustomobject]@{ Plan=$plan; Rows=$rows; Text=$(if ($parts.Count) { $parts -join " $([char]0x00b7) " } else { 'Usage --' }) }
}
Export-ModuleMember -Function Get-CapsuleModel
