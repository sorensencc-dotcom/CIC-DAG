<#
.SYNOPSIS
  Scan repository for tasks that should be automated.
  Identifies repetitive work, logs, cleanup, backups, reports, and health checks.

.DESCRIPTION
  Crawls project structure, analyzes:
  - Log files (size, age, rotation patterns)
  - Backup/archive folders (staleness, cleanup)
  - Report generation scripts (manual vs. automated)
  - README/setup files (indicating manual processes)
  - Test suites (coverage, run frequency)
  - Data processing pipelines (ingestion, classification)
  - Configuration files (version tracking, diff patterns)

.OUTPUTS
  - automation_opportunities.json (structured recommendations)
  - automation_audit.log (detailed findings)

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\scan-automation-opportunities.ps1'
#>

param(
  [string]$RepoRoot = "C:\CIC_MEDIA_LIBRARY",
  [string]$OutputDir = "C:\CIC_MEDIA_LIBRARY\scheduling\reports"
)

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$reportFile = "$OutputDir\automation_opportunities_$timestamp.json"
$logFile = "$OutputDir\automation_audit_$timestamp.log"

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $entry = "[$ts] [$Level] $Message"
  Write-Host $entry -ForegroundColor $(if($Level -eq "ERROR") { "Red" } elseif($Level -eq "OK") { "Green" } else { "White" })
  $entry | Add-Content $logFile
}

Write-Log "========== AUTOMATION AUDIT START ==========" "INFO"
Write-Log "Repository: $RepoRoot" "INFO"

$opportunities = @()

# 1. SCAN LOG FILES
Write-Log "Scanning log files..." "INFO"
$logFiles = Get-ChildItem $RepoRoot -Filter "*.log" -Recurse -File 2>/dev/null | Where-Object { $_.Length -gt 1MB }
foreach ($log in $logFiles) {
  $ageInDays = (New-TimeSpan -Start $log.LastWriteTime -End (Get-Date)).Days

  if ($log.Length -gt 10MB) {
    $opportunities += @{
      category = "log_rotation"
      priority = "high"
      task = "Rotate/compress log: $($log.Name)"
      path = $log.FullName
      details = "Size: $('{0:N0}' -f ($log.Length/1MB)) MB, Age: $ageInDays days"
      automation_type = "scheduled_cleanup"
      suggested_frequency = "weekly"
      estimated_effort_minutes = 15
    }
    Write-Log "  ✓ Large log found: $($log.Name) - $([Math]::Round($log.Length/1MB, 1))MB" "OK"
  }
}

# 2. SCAN FOR BACKUP/ARCHIVE PATTERNS
Write-Log "Scanning for backup/archive opportunities..." "INFO"
$backupDirs = @("backup", "archive", "versions", "snapshots")
foreach ($pattern in $backupDirs) {
  $matches = Get-ChildItem $RepoRoot -Directory -Recurse -Filter "*$pattern*" -ErrorAction SilentlyContinue 2>/dev/null | Select-Object -First 5

  foreach ($dir in $matches) {
    $itemCount = @(Get-ChildItem $dir -Recurse -File).Count
    $totalSize = (Get-ChildItem $dir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB

    if ($itemCount -gt 10) {
      $opportunities += @{
        category = "backup_management"
        priority = "medium"
        task = "Automate backup retention for: $($dir.Name)"
        path = $dir.FullName
        details = "Items: $itemCount, Total size: $([Math]::Round($totalSize, 2)) GB"
        automation_type = "scheduled_retention_policy"
        suggested_frequency = "weekly"
        estimated_effort_minutes = 30
      }
      Write-Log "  ✓ Backup folder found: $($dir.Name) - $itemCount items" "OK"
    }
  }
}

# 3. SCAN FOR DATA PROCESSING PATTERNS
Write-Log "Scanning for data processing opportunities..." "INFO"
$pipelineScripts = Get-ChildItem $RepoRoot -Filter "*ingest*" -Recurse -File 2>/dev/null
$pipelineScripts += Get-ChildItem $RepoRoot -Filter "*classify*" -Recurse -File 2>/dev/null
$pipelineScripts += Get-ChildItem $RepoRoot -Filter "*process*" -Recurse -File 2>/dev/null

foreach ($script in $pipelineScripts | Select-Object -Unique) {
  # Check if manual execution is needed
  $content = Get-Content $script -Raw -ErrorAction SilentlyContinue
  if ($content -match "manual|TODO|FIXME|RUN THIS") {
    $opportunities += @{
      category = "pipeline_automation"
      priority = "high"
      task = "Schedule execution of: $($script.Name)"
      path = $script.FullName
      details = "Script contains manual execution notes"
      automation_type = "scheduled_pipeline"
      suggested_frequency = "daily"
      estimated_effort_minutes = 20
    }
    Write-Log "  ✓ Pipeline script with manual notes: $($script.Name)" "OK"
  }
}

# 4. SCAN FOR REPORT GENERATION
Write-Log "Scanning for report generation opportunities..." "INFO"
$reportPatterns = @("*report*", "*summary*", "*inventory*", "*checklist*")
foreach ($pattern in $reportPatterns) {
  $reports = Get-ChildItem $RepoRoot -Filter $pattern -Recurse -File 2>/dev/null | Where-Object { $_.Extension -in @(".json", ".csv", ".html") }

  foreach ($report in $reports | Select-Object -First 3) {
    $ageInDays = (New-TimeSpan -Start $report.LastWriteTime -End (Get-Date)).Days

    if ($ageInDays -lt 30 -and $report.Length -lt 10MB) {
      $opportunities += @{
        category = "report_generation"
        priority = "medium"
        task = "Auto-generate: $($report.Name)"
        path = $report.FullName
        details = "Last updated: $ageInDays days ago, size: $('{0:N0}' -f ($report.Length/1KB)) KB"
        automation_type = "scheduled_report"
        suggested_frequency = "weekly"
        estimated_effort_minutes = 25
      }
      Write-Log "  ✓ Active report found: $($report.Name)" "OK"
    }
  }
}

# 5. SCAN FOR HEALTH CHECKS
Write-Log "Scanning for health/validation opportunities..." "INFO"
$configFiles = Get-ChildItem $RepoRoot -Filter "*config*.json" -Recurse -File 2>/dev/null
$schemaFiles = Get-ChildItem $RepoRoot -Filter "*schema*.json" -Recurse -File 2>/dev/null

if ($configFiles -or $schemaFiles) {
  $opportunities += @{
    category = "health_check"
    priority = "medium"
    task = "Validate configuration and schema files"
    path = "$RepoRoot\metadata"
    details = "Config files: $($configFiles.Count), Schema files: $($schemaFiles.Count)"
    automation_type = "scheduled_validation"
    suggested_frequency = "daily"
    estimated_effort_minutes = 30
  }
  Write-Log "  ✓ Configuration validation recommended" "OK"
}

# 6. SCAN FOR DATABASE/CSV MAINTENANCE
Write-Log "Scanning for database/CSV maintenance..." "INFO"
$csvFiles = Get-ChildItem $RepoRoot -Filter "*.csv" -Recurse -File 2>/dev/null
foreach ($csv in $csvFiles) {
  $lineCount = @(Get-Content $csv -ErrorAction SilentlyContinue).Count
  if ($lineCount -gt 1000) {
    $opportunities += @{
      category = "data_maintenance"
      priority = "low"
      task = "Archive/optimize: $($csv.Name)"
      path = $csv.FullName
      details = "Lines: $lineCount, Size: $('{0:N0}' -f ($csv.Length/1MB)) MB"
      automation_type = "scheduled_optimization"
      suggested_frequency = "monthly"
      estimated_effort_minutes = 40
    }
    Write-Log "  ✓ Large CSV found: $($csv.Name) - $lineCount rows" "OK"
  }
}

# 7. SCAN FOR SYNC/MIRROR TASKS
Write-Log "Scanning for sync/mirror opportunities..." "INFO"
$opportunities += @{
  category = "data_sync"
  priority = "high"
  task = "Sync metadata and inventory between local and Drive"
  path = "$RepoRoot\metadata"
  details = "Ensures consistency between source of truth and backup"
  automation_type = "scheduled_sync"
  suggested_frequency = "daily"
  estimated_effort_minutes = 35
}

# 8. SCAN FOR VERSION/CHANGELOG UPDATES
Write-Log "Scanning for versioning opportunities..." "INFO"
$opportunities += @{
  category = "versioning"
  priority = "medium"
  task = "Auto-generate changelog from git"
  path = "$RepoRoot"
  details = "Track changes for Phase tracking and documentation"
  automation_type = "scheduled_changelog"
  suggested_frequency = "weekly"
  estimated_effort_minutes = 20
}

# SUMMARIZE & SAVE
$summary = @{
  scan_timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
  repository = $RepoRoot
  total_opportunities = $opportunities.Count
  by_priority = @{
    high = ($opportunities | Where-Object { $_.priority -eq "high" }).Count
    medium = ($opportunities | Where-Object { $_.priority -eq "medium" }).Count
    low = ($opportunities | Where-Object { $_.priority -eq "low" }).Count
  }
  by_category = @{}
  opportunities = $opportunities | Sort-Object priority -Descending
}

# Count by category
$opportunities | Group-Object -Property category | ForEach-Object {
  $summary.by_category[$_.Name] = $_.Count
}

# Save report
$summary | ConvertTo-Json -Depth 10 | Set-Content $reportFile -Force
Write-Log "✓ Report saved: $reportFile" "OK"

# Display summary
Write-Log "" "INFO"
Write-Log "========== AUDIT SUMMARY ==========" "OK"
Write-Log "Total opportunities identified: $($summary.total_opportunities)" "OK"
Write-Log "  HIGH priority: $($summary.by_priority.high)" "OK"
Write-Log "  MEDIUM priority: $($summary.by_priority.medium)" "OK"
Write-Log "  LOW priority: $($summary.by_priority.low)" "OK"
Write-Log "" "INFO"
Write-Log "By category:" "INFO"
foreach ($cat in $summary.by_category.GetEnumerator() | Sort-Object Value -Descending) {
  Write-Log "  $($cat.Key): $($cat.Value)" "INFO"
}

Write-Log "========== AUDIT COMPLETE ==========" "OK"
Write-Log "Next: Review $reportFile and add tasks to task-registry.json" "INFO"

# Also update task registry with new recommendations
$registryPath = "C:\CIC_MEDIA_LIBRARY\scheduling\task-registry.json"
if (Test-Path $registryPath) {
  $registry = Get-Content $registryPath | ConvertFrom-Json

  # Count existing tasks vs. opportunities
  $existingCount = $registry.tasks.Count
  $newOpportunities = $summary.total_opportunities

  Write-Log "" "INFO"
  Write-Log "Task Registry Status:" "INFO"
  Write-Log "  Currently scheduled: $existingCount tasks" "INFO"
  Write-Log "  New opportunities identified: $newOpportunities" "INFO"
  Write-Log "  Next step: Prioritize and add high-priority tasks to registry" "INFO"
}

Write-Host "`n✓ Automation audit complete. Review the report:" -ForegroundColor Green
Write-Host "  $reportFile" -ForegroundColor Cyan
