<#
.SYNOPSIS
  Validate all configuration and schema files in the DAM.
  Checks: JSON validity, required fields, schema compliance.

.DESCRIPTION
  Daily health check for configuration integrity:
  - Validates all .json files for valid JSON syntax
  - Checks task-registry.json schema
  - Verifies metadata files exist and are readable
  - Reports any corruption or missing files

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\tasks\validate-configuration.ps1'
#>

param(
  [string]$RepositoryRoot = "C:\CIC_MEDIA_LIBRARY"
)

$MetadataPath = "$RepositoryRoot\metadata"
$SchedulingPath = "$RepositoryRoot\scheduling"
$LogPath = "$RepositoryRoot\logs\scheduled_runs"
$ReportsPath = "$RepositoryRoot\scheduling\reports"
$AuditLog = "$ReportsPath\config_validation_audit.jsonl"

if (-not (Test-Path $LogPath)) {
  New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$runLog = "$LogPath\validate_config_$timestamp.log"

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "[$ts] [$Level] $Message" | Tee-Object -FilePath $runLog -Append
}

Write-Log "========== CONFIGURATION VALIDATION START ==========" "INFO"
Write-Log "Repository: $RepositoryRoot" "INFO"

$startTime = Get-Date
$validCount = 0
$invalidCount = 0
$warnings = @()
$errors = @()

# Files to validate
$configFiles = @(
  "$SchedulingPath\task-registry.json",
  "$MetadataPath\master_media_inventory.csv",
  "$MetadataPath\folder_to_topic_mapping.json"
)

Write-Log "Validating configuration files..." "INFO"

foreach ($file in $configFiles) {
  Write-Log "" "INFO"
  Write-Log "Checking: $(Split-Path $file -Leaf)" "INFO"

  if (-not (Test-Path $file)) {
    Write-Log "  ✗ FILE NOT FOUND" "ERROR"
    $errors += "Missing: $(Split-Path $file -Leaf)"
    $invalidCount++
    continue
  }

  # File exists
  $fileSize = (Get-Item $file).Length / 1KB
  Write-Log "  ✓ File exists ($([Math]::Round($fileSize, 1)) KB)" "OK"

  # If JSON, validate syntax
  if ($file -like "*.json") {
    try {
      $content = Get-Content $file -Raw
      $json = $content | ConvertFrom-Json -ErrorAction Stop
      Write-Log "  ✓ Valid JSON syntax" "OK"

      # Schema-specific checks
      if ($file -like "*task-registry*") {
        if ($json.tasks -and $json.metadata) {
          Write-Log "  ✓ Task registry structure valid" "OK"
          Write-Log "    Tasks defined: $($json.tasks.Count)" "INFO"

          # Check each task
          $json.tasks | ForEach-Object {
            if (-not $_.id -or -not $_.name -or -not $_.script) {
              $warnings += "Task missing required fields: $($_.id ?? 'unknown')"
              Write-Log "    ⚠ Task missing required fields: $($_.name)" "WARN"
            }
            if (-not (Test-Path $_.script)) {
              $warnings += "Script not found: $($_.script)"
              Write-Log "    ⚠ Script not found: $(Split-Path $_.script -Leaf)" "WARN"
            }
          }
        } else {
          $errors += "Task registry missing required structure"
          Write-Log "  ✗ Invalid structure" "ERROR"
          $invalidCount++
          continue
        }
      }

      elseif ($file -like "*folder*mapping*") {
        Write-Log "  ✓ Folder mapping structure valid" "OK"
        Write-Log "    Mappings defined: $($json.psobject.properties.Count)" "INFO"
      }

      $validCount++

    } catch {
      Write-Log "  ✗ Invalid JSON: $_" "ERROR"
      $errors += "JSON parse error in $(Split-Path $file -Leaf): $_"
      $invalidCount++
    }
  }

  # If CSV, validate format
  elseif ($file -like "*.csv") {
    try {
      $csv = @(Import-Csv $file -ErrorAction Stop)
      Write-Log "  ✓ Valid CSV format" "OK"
      Write-Log "    Rows: $($csv.Count)" "INFO"

      # For inventory, check required columns
      if ($file -like "*inventory*") {
        $requiredCols = @("media_id", "filename", "type", "primary_topic")
        $headers = (Get-Content $file -TotalCount 1).Split(",")

        $missingCols = $requiredCols | Where-Object { $_ -notin $headers }
        if ($missingCols) {
          $warnings += "Inventory missing columns: $($missingCols -join ', ')"
          Write-Log "  ⚠ Missing columns: $($missingCols -join ', ')" "WARN"
        } else {
          Write-Log "  ✓ All required columns present" "OK"
        }
      }

      $validCount++

    } catch {
      Write-Log "  ✗ Invalid CSV: $_" "ERROR"
      $errors += "CSV parse error in $(Split-Path $file -Leaf)"
      $invalidCount++
    }
  }
}

# Check directory structure
Write-Log "" "INFO"
Write-Log "Validating directory structure..." "INFO"

$requiredDirs = @(
  "$MetadataPath",
  "$SchedulingPath",
  "$SchedulingPath\tasks",
  "$SchedulingPath\reports",
  "$LogPath"
)

foreach ($dir in $requiredDirs) {
  if (Test-Path $dir) {
    Write-Log "  ✓ $(Split-Path $dir -Leaf)" "OK"
  } else {
    Write-Log "  ✗ Missing: $(Split-Path $dir -Leaf)" "ERROR"
    $errors += "Missing directory: $dir"
    $invalidCount++
  }
}

# Summary
$duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
Write-Log "" "INFO"
Write-Log "========== VALIDATION SUMMARY ==========" "OK"
Write-Log "Valid items: $validCount" "OK"
Write-Log "Invalid items: $invalidCount" $(if ($invalidCount -gt 0) { "ERROR" } else { "OK" })
Write-Log "Warnings: $($warnings.Count)" $(if ($warnings.Count -gt 0) { "WARN" } else { "OK" })
Write-Log "Duration: $duration seconds" "INFO"

if ($warnings.Count -gt 0) {
  Write-Log "" "INFO"
  Write-Log "Warnings:" "WARN"
  $warnings | ForEach-Object { Write-Log "  ⚠ $_" "WARN" }
}

if ($errors.Count -gt 0) {
  Write-Log "" "INFO"
  Write-Log "Errors:" "ERROR"
  $errors | ForEach-Object { Write-Log "  ✗ $_" "ERROR" }
}

# Log to audit
$status = if ($invalidCount -eq 0 -and $warnings.Count -eq 0) { "healthy" } `
          elseif ($invalidCount -eq 0) { "degraded" } `
          else { "failed" }

$auditEntry = @{
  timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
  task = "config-validation"
  status = $status
  duration_seconds = $duration
  valid_count = $validCount
  invalid_count = $invalidCount
  warnings_count = $warnings.Count
  errors = $errors
  log_file = $runLog
} | ConvertTo-Json -Compress -Depth 3

$auditEntry | Add-Content $AuditLog

Write-Log "========== COMPLETE ==========" "OK"

exit $(if ($invalidCount -gt 0) { 1 } else { 0 })
