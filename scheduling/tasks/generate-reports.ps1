<#
.SYNOPSIS
  Auto-generate operational reports from current DAM state.
  Creates: inventory report, media summary, topic breakdown, quality score.

.DESCRIPTION
  Generates fresh reports from master_media_inventory.csv and logs:
  - Inventory Report: full item list with metadata
  - Summary Report: counts by topic, type, rights status
  - Quality Report: breakdown by quality rating
  - Topic Report: detailed breakdown per research topic

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\tasks\generate-reports.ps1'
#>

param(
  [string]$RepositoryRoot = "C:\CIC_MEDIA_LIBRARY"
)

$MetadataPath = "$RepositoryRoot\metadata"
$OperationsPath = "$RepositoryRoot\operations"
$ReportsPath = "$RepositoryRoot\scheduling\reports"
$LogPath = "$RepositoryRoot\logs\scheduled_runs"
$InventoryFile = "$MetadataPath\master_media_inventory.csv"
$AuditLog = "$ReportsPath\report_generation_audit.jsonl"

if (-not (Test-Path $LogPath)) {
  New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$runLog = "$LogPath\generate_reports_$timestamp.log"

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "[$ts] [$Level] $Message" | Tee-Object -FilePath $runLog -Append
}

Write-Log "========== REPORT GENERATION START ==========" "INFO"
Write-Log "Repository: $RepositoryRoot" "INFO"

if (-not (Test-Path $InventoryFile)) {
  Write-Log "ERROR: Inventory file not found: $InventoryFile" "ERROR"
  exit 1
}

$startTime = Get-Date

try {
  # Load inventory
  Write-Log "Loading inventory..." "INFO"
  $inventory = @(Import-Csv $InventoryFile)
  $itemCount = $inventory.Count
  Write-Log "  Loaded $itemCount items" "OK"

  # REPORT 1: Inventory Summary
  Write-Log "Generating inventory summary..." "INFO"
  $summarySave = "$OperationsPath\inventory_summary_$(Get-Date -Format 'yyyy-MM-dd').json"

  $summary = @{
    generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    total_items = $itemCount
    by_type = @{}
    by_topic = @{}
    by_rights = @{}
    quality_distribution = @{}
    inventory_file = $InventoryFile
  }

  # Count by type
  $inventory | Group-Object -Property type | ForEach-Object {
    $summary.by_type[$_.Name] = $_.Count
  }

  # Count by topic
  $inventory | Group-Object -Property primary_topic | ForEach-Object {
    $summary.by_topic[$_.Name] = $_.Count
  }

  # Count by rights
  $inventory | Group-Object -Property rights_status | ForEach-Object {
    $summary.by_rights[$_.Name] = $_.Count
  }

  # Quality distribution
  $inventory | Group-Object -Property quality_rating | ForEach-Object {
    $summary.quality_distribution[$_.Name] = $_.Count
  }

  $summary | ConvertTo-Json -Depth 5 | Set-Content $summarySave -Force
  Write-Log "  ✓ Summary saved: $(Split-Path $summarySave -Leaf)" "OK"

  # REPORT 2: Topic Breakdown
  Write-Log "Generating topic breakdown..." "INFO"
  $topicBreakdown = @{
    generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    topics = @{}
  }

  $inventory | Group-Object -Property primary_topic | ForEach-Object {
    $topicName = $_.Name
    $items = $_.Group

    $topicBreakdown.topics[$topicName] = @{
      total_items = $items.Count
      photos = ($items | Where-Object { $_.type -eq 'Photograph' }).Count
      documents = ($items | Where-Object { $_.type -eq 'Document' }).Count
      pre_cleared = ($items | Where-Object { $_.rights_status -eq 'pre_cleared' }).Count
      needs_clearance = ($items | Where-Object { $_.rights_status -eq 'needs_clearance' }).Count
      avg_quality = [Math]::Round(($items | Measure-Object -Property quality_rating -Average).Average, 1)
      items = @($items | Select-Object -Property media_id, filename, type, rights_status, quality_rating)
    }
  }

  $topicSave = "$OperationsPath\topic_breakdown_$(Get-Date -Format 'yyyy-MM-dd').json"
  $topicBreakdown | ConvertTo-Json -Depth 10 | Set-Content $topicSave -Force
  Write-Log "  ✓ Topic breakdown saved: $(Split-Path $topicSave -Leaf)" "OK"

  # REPORT 3: Quality Distribution Report
  Write-Log "Generating quality distribution..." "INFO"
  $qualityReport = @{
    generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    quality_scale = "1-10: 1=poor, 10=excellent"
    distribution = @{}
    recommendations = @()
  }

  $inventory | Group-Object -Property quality_rating | Sort-Object Name | ForEach-Object {
    $rating = $_.Name
    $items = $_.Group
    $qualityReport.distribution[$rating] = @{
      count = $items.Count
      percentage = [Math]::Round(($items.Count / $itemCount) * 100, 1)
      topics = @($items | Group-Object -Property primary_topic | ForEach-Object { $_.Name })
    }
  }

  # Generate recommendations
  $lowQuality = $inventory | Where-Object { [int]$_.quality_rating -lt 4 }
  if ($lowQuality.Count -gt 0) {
    $qualityReport.recommendations += "Review $($lowQuality.Count) low-quality items (rating <4)"
  }

  $highQuality = $inventory | Where-Object { [int]$_.quality_rating -ge 8 }
  if ($highQuality.Count -gt 0) {
    $qualityReport.recommendations += "Consider $($highQuality.Count) high-quality items for marketing (rating 8-10)"
  }

  $qualitySave = "$OperationsPath\quality_report_$(Get-Date -Format 'yyyy-MM-dd').json"
  $qualityReport | ConvertTo-Json -Depth 5 | Set-Content $qualitySave -Force
  Write-Log "  ✓ Quality report saved: $(Split-Path $qualitySave -Leaf)" "OK"

  # REPORT 4: Rights Clearance Report
  Write-Log "Generating rights clearance status..." "INFO"
  $rightsReport = @{
    generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    pre_cleared_count = ($inventory | Where-Object { $_.rights_status -eq 'pre_cleared' }).Count
    needs_clearance_count = ($inventory | Where-Object { $_.rights_status -eq 'needs_clearance' }).Count
    clearance_percentage = 0
    items_needing_clearance = @()
  }

  $rightsReport.clearance_percentage = [Math]::Round(
    ($rightsReport.pre_cleared_count / $itemCount) * 100,
    1
  )

  $rightsReport.items_needing_clearance = @(
    $inventory | Where-Object { $_.rights_status -eq 'needs_clearance' } |
    Select-Object -Property media_id, filename, archive_origin |
    Sort-Object -Property archive_origin
  )

  $rightsSave = "$OperationsPath\rights_clearance_$(Get-Date -Format 'yyyy-MM-dd').json"
  $rightsReport | ConvertTo-Json -Depth 5 | Set-Content $rightsSave -Force
  Write-Log "  ✓ Rights clearance report saved: $(Split-Path $rightsSave -Leaf)" "OK"

  $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
  Write-Log "" "INFO"
  Write-Log "========== REPORTS GENERATED ==========" "OK"
  Write-Log "  Inventory Summary: $(Split-Path $summarySave -Leaf)" "OK"
  Write-Log "  Topic Breakdown: $(Split-Path $topicSave -Leaf)" "OK"
  Write-Log "  Quality Report: $(Split-Path $qualitySave -Leaf)" "OK"
  Write-Log "  Rights Clearance: $(Split-Path $rightsSave -Leaf)" "OK"
  Write-Log "Duration: $duration seconds" "OK"

  # Log to audit
  $auditEntry = @{
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    task = "report-generation"
    status = "success"
    duration_seconds = $duration
    reports_generated = 4
    items_processed = $itemCount
    log_file = $runLog
  } | ConvertTo-Json -Compress

  $auditEntry | Add-Content $AuditLog

  Write-Log "========== COMPLETE ==========" "OK"
  exit 0

} catch {
  Write-Log "✗ Error: $_" "ERROR"

  $auditEntry = @{
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    task = "report-generation"
    status = "failed"
    error = $_.Exception.Message
    log_file = $runLog
  } | ConvertTo-Json -Compress

  $auditEntry | Add-Content $AuditLog
  exit 1
}
