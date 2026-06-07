<#
.SYNOPSIS
  Display scheduled tasks and their status at a glance.
#>

$SchedulingRoot = "C:\CIC_MEDIA_LIBRARY\scheduling"
$RegistryFile = "$SchedulingRoot\task-registry.json"
$LogFile = "$SchedulingRoot\execution-log.jsonl"

if (-not (Test-Path $RegistryFile)) {
  Write-Host "Registry not found" -ForegroundColor Red
  exit 1
}

$registry = Get-Content $RegistryFile | ConvertFrom-Json

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SCHEDULED TASKS — Cast Iron Charlie DAM              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nNext Scheduled Runs:" -ForegroundColor Green

$now = Get-Date
$nextWeek = $now.AddDays(7)

foreach ($task in $registry.tasks | Where-Object { $_.enabled } | Sort-Object time) {
  $status = if ($task.last_status -eq "success") { "✓" } elseif ($task.last_status -eq "failed") { "✗" } else { "?" }

  Write-Host "`n$status $($task.name)" -ForegroundColor $(if($task.last_status -eq "success") { "Green" } else { "Yellow" })
  Write-Host "   Schedule: $($task.schedule) — $($task.day_of_week) @ $($task.time)" -ForegroundColor Cyan
  Write-Host "   Last run: $($task.last_run ?? 'never')" -ForegroundColor White

  if ($task.dependencies.Count -gt 0) {
    Write-Host "   Dependencies: $($task.dependencies -join ', ')" -ForegroundColor DarkGray
  }
}

Write-Host "`n" -ForegroundColor White

# Recent executions
if (Test-Path $LogFile) {
  Write-Host "Recent Executions:" -ForegroundColor Green
  $recent = @(Get-Content $LogFile | ConvertFrom-Json | Sort-Object timestamp -Descending | Select-Object -First 10)

  $recent | ForEach-Object {
    $statusColor = if($_.status -eq "success") { "Green" } elseif($_.status -eq "failed") { "Red" } else { "Yellow" }
    Write-Host "  [$($_.timestamp)] $($_.task_id): $($_.status) ($($_.duration_seconds)s)" -ForegroundColor $statusColor
  }
} else {
  Write-Host "  (no execution history yet)" -ForegroundColor DarkGray
}

Write-Host "`nManagement Commands:" -ForegroundColor Cyan
Write-Host "  Show status:   & '$SchedulingRoot\task-scheduler-agent.ps1' -Mode status" -ForegroundColor White
Write-Host "  Show report:   & '$SchedulingRoot\task-scheduler-agent.ps1' -Mode report" -ForegroundColor White
Write-Host "  Validate:      & '$SchedulingRoot\task-scheduler-agent.ps1' -Mode validate" -ForegroundColor White
Write-Host "  Run manually:  & '$SchedulingRoot\task-scheduler-agent.ps1' -Mode execute -Force" -ForegroundColor White
Write-Host ""
