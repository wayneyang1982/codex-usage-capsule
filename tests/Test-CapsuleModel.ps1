$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\Capsule.Model.psm1') -Force
$now=[DateTimeOffset]::FromUnixTimeSeconds(2000000)
function Check($want,$got){if($want -ne $got){throw "Expected [$want], got [$got]"}}
$weekly=[pscustomobject]@{usedPercent=61;windowDurationMins=10080;resetsAt=2000000+78624}
$short=[pscustomobject]@{usedPercent=12;windowDurationMins=300;resetsAt=2000000+2340}
$payload=[pscustomobject]@{rateLimits=[pscustomobject]@{primary=$weekly;secondary=$null;planType='pro'}}
Check '7d 61% | 87%' (Get-CapsuleModel $payload $now).Text
$payload.rateLimits.secondary=$short
Check "5h (12|87) $([char]0x00b7) 7d (61|87)" (Get-CapsuleModel $payload $now).Text
$payload.rateLimits.planType='free'
Check 2 (Get-CapsuleModel $payload $now).Rows.Count
Check 'Usage --' (Get-CapsuleModel $null $now).Text
$weekly.usedPercent=$null
Check 1 (Get-CapsuleModel $payload $now).Rows.Count
$short.resetsAt=1999999
Check '5h --% | 100%' (Get-CapsuleModel $payload $now).Text
$short.resetsAt=2018000
Check '5h 12% | 0%' (Get-CapsuleModel $payload $now).Text
$short.windowDurationMins=43200
Check '30d' (Get-CapsuleModel $payload $now).Rows[0].Label
Write-Output 'PASS: single, dual, Free, absent, null, expired, reset, other duration'
