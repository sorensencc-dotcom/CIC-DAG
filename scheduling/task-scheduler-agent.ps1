<#
.SYNOPSIS
  Centralized task scheduling agent for all automated workflows.
  Manages execution, dependencies, logging, and reporting.

.DESCRIPTION
  Reads task registry, executes scheduled tasks, tracks dependencies,
  logs results, and generates execution reports.

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\task-scheduler-agent.ps1' -Mode execute
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\task-scheduler-agent.ps1' -Mode report
#>

param(
  [string]$Mode = "execute",  # execute | report | validate | status
  [string]$TaskId = $null,    # run specific task
  [switch]$Force = $false     # force run even if not scheduled
)

$SchedulingRoot = "C:\CIC_MEDIA_LIBRARY\scheduling"
$RegistryFile = "$SchedulingRoot\task-registry.json"
$ExecutionLog = "$SchedulingRoot\execution-log.jsonl"
$ReportsDir = "$SchedulingRoot\reports"

# Create directories
@($SchedulingRoot, $ReportsDir) | ForEach-Object {
  if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $entry = "[$ts] [$Level] $Message"
  Write-Host $entry -ForegroundColor $(if($Level -eq "ERROR") { "Red" } elseif($Level -eq "OK") { "Green" } else { "White" })
  $entry | Add-Content "$SchedulingRoot\agent.log"
}

function Load-Registry {
  if (Test-Path $RegistryFile) {
    return Get-Content $RegistryFile | ConvertFrom-Json
  }
  Write-Log "Registry not found: $RegistryFile" "ERROR"
  return $null
}

function Save-Registry {
  param($Registry)
  $Registry | ConvertTo-Json -Depth 10 | Set-Content $RegistryFile -Force
}

function Log-Execution {
  param($TaskId, $Status, $Duration, $Error)
  $entry = @{
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    task_id = $TaskId
    status = $Status
    duration_seconds = $Duration
    error = $Error
  } | ConvertTo-Json -Compress
  $entry | Add-Content $ExecutionLog
}

function Get-TasksToRun {
  param($Registry, [switch]$ForceAll)

  $now = Get-Date
  $dayName = $now.DayOfWeek.ToString()
  $hourMin = $now.ToString("HH:mm")
  $tasksToRun = @()

  foreach ($task in $Registry.tasks) {
    if (-not $task.enabled) { continue }

    $shouldRun = $false

    if ($task.schedule -eq "weekly" -and $task.day_of_week -eq $dayName) {
      $scheduledTime = [TimeSpan]::Parse($task.time)
      $currentTime = $now.TimeOfDay
      # Run if within 5 minutes of scheduled time
      if ([Math]::Abs(($scheduledTime - $currentTime).TotalMinutes) -lt 5) {
        $shouldRun = $true
      }
    }
    elseif ($task.schedule -eq "daily") {
      $scheduledTime = [TimeSpan]::Parse($task.time)
      $currentTime = $now.TimeOfDay
      if ([Math]::Abs(($scheduledTime - $currentTime).TotalMinutes) -lt 5) {
        $shouldRun = $true
      }
    }

    if ($shouldRun -or $ForceAll) {
      $tasksToRun += $task
    }
  }

  return $tasksToRun
}

function Execute-Task {
  param($Task, $Registry)

  Write-Log "Executing: $($Task.name)" "INFO"
  $startTime = Get-Date

  # Check dependencies
  foreach ($depId in $Task.dependencies) {
    $depTask = $Registry.tasks | Where-Object { $_.id -eq $depId } | Select-Object -First 1
    if ($depTask -and $depTask.last_status -ne "success") {
      Write-Log "  ✗ Dependency failed: $depId" "ERROR"
      Log-Execution $Task.id "skipped" 0 "Dependency $depId failed"
      return $false
    }
  }

  # Run task
  try {
    if (Test-Path $Task.script) {
      $timeout = $Task.timeout_minutes * 60
      $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Task.script `
        -ErrorAction Stop 2>&1

      $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
      Write-Log "  ✓ Completed in ${duration}s" "OK"
      Log-Execution $Task.id "success" $duration $null

      return $true
    } else {
      throw "Script not found: $($Task.script)"
    }
  } catch {
    $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
    Write-Log "  ✗ Failed: $_" "ERROR"
    Log-Execution $Task.id "failed" $duration $_.Exception.Message
    return $false
  }
}

function Generate-Report {
  param($Registry)

  $report = @{
    generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    tasks = @()
    summary = @{
      total = $Registry.tasks.Count
      enabled = ($Registry.tasks | Where-Object { $_.enabled }).Count
      next_run = $null
    }
  }

  foreach ($task in $Registry.tasks | Sort-Object id) {
    $report.tasks += @{
      id = $task.id
      name = $task.name
      enabled = $task.enabled
      schedule = $task.schedule
      last_run = $task.last_run
      last_status = $task.last_status
      next_scheduled = if($task.enabled) { "$(Get-Date -Format 'yyyy-MM-dd') $($task.time)" } else { "disabled" }
    }
  }

  $reportPath = "$ReportsDir\next-scheduled-tasks.json"
  $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Force

  Write-Log "Report generated: $reportPath" "OK"
  return $report
}

# Main execution
Write-Log "Task Scheduler Agent started (mode: $Mode)" "INFO"

$registry = Load-Registry
if (-not $registry) { exit 1 }

switch ($Mode) {
  "execute" {
    $tasksToRun = Get-TasksToRun $registry
    Write-Log "Found $($tasksToRun.Count) tasks to execute" "INFO"

    foreach ($task in $tasksToRun) {
      Execute-Task $task $registry | Out-Null
    }
  }

  "report" {
    Generate-Report $registry | Out-Null
  }

  "status" {
    Write-Host "`n=== Task Scheduler Status ===" -ForegroundColor Cyan
    foreach ($task in $registry.tasks | Where-Object { $_.enabled }) {
      Write-Host "$($task.name)" -ForegroundColor Green
      Write-Host "  Schedule: $($task.schedule) $($task.day_of_week ?? '') $($task.time)" -ForegroundColor Cyan
      Write-Host "  Last run: $($task.last_run ?? 'never')" -ForegroundColor White
      Write-Host "  Last status: $($task.last_status ?? 'pending')" -ForegroundColor $(if($task.last_status -eq "success") { "Green" } else { "Yellow" })
    }
  }

  "validate" {
    $validTasks = 0
    foreach ($task in $registry.tasks) {
      if (Test-Path $task.script) {
        Write-Log "✓ $($task.id): script found" "OK"
        $validTasks++
      } else {
        Write-Log "✗ $($task.id): script not found at $($task.script)" "ERROR"
      }
    }
    Write-Log "Validation: $validTasks/$($registry.tasks.Count) tasks valid" "INFO"
  }
}

Write-Log "Agent completed" "INFO"
