<#
.SYNOPSIS
  Daily sync of metadata and inventory between local DAM and Google Drive.
  Keeps backup current and detects divergence.

.DESCRIPTION
  Copies key DAM files to Drive backup location:
  - master_media_inventory.csv
  - search_index.json
  - treatment_crossref_index.json
  - follow_ops_checklist.json (operations)

  Also verifies checksums and logs sync status.

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\tasks\sync-inventory-to-drive.ps1'
#>

$RootPath = "C:\CIC_MEDIA_LIBRARY"
$MetadataPath = "$RootPath\metadata"
$OperationsPath = "$RootPath\operations"
$DriveBackupPath = "G:\My Drive\Cast Iron Charlie — Documentary Project\Backups\DAM_Metadata"
$LogPath = "$RootPath\logs\scheduled_runs"
$AuditLog = "$RootPath\scheduling\reports\drive_sync_audit.jsonl"

if (-not (Test-Path $LogPath)) {
  New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

if (-not (Test-Path $DriveBackupPath)) {
  Write-Host "WARNING: Drive backup path not accessible: $DriveBackupPath" -ForegroundColor Yellow
  Write-Host "Ensure Google Drive desktop app is running and path is mounted." -ForegroundColor Yellow
  exit 1
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$runLog = "$LogPath\drive_sync_$timestamp.log"

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "[$ts] [$Level] $Message" | Tee-Object -FilePath $runLog -Append
}

function Get-FileHash256 {
  param([string]$FilePath)
  if (Test-Path $FilePath) {
    return (Get-FileHash $FilePath -Algorithm SHA256).Hash
  }
  return $null
}

Write-Log "========== DRIVE SYNC STARTED ==========" "INFO"
Write-Log "Local metadata path: $MetadataPath" "INFO"
Write-Log "Drive backup path: $DriveBackupPath" "INFO"
Write-Log "Time: $(Get-Date)" "INFO"

$filesToSync = @(
  @{ name = "master_media_inventory.csv"; path = "$MetadataPath\master_media_inventory.csv" },
  @{ name = "search_index.json"; path = "$MetadataPath\search_index.json" },
  @{ name = "treatment_crossref_index.json"; path = "$MetadataPath\treatment_crossref_index.json" },
  @{ name = "follow_ops_checklist.json"; path = "$OperationsPath\follow_ops_checklist.json" }
)

$startTime = Get-Date
$syncCount = 0
$skipCount = 0
$errorCount = 0
$syncDetails = @()

foreach ($file in $filesToSync) {
  $srcPath = $file.path
  $srcName = $file.name
  $dstPath = Join-Path $DriveBackupPath $srcName

  if (-not (Test-Path $srcPath)) {
    Write-Log "SKIP: $srcName (not found)" "WARN"
    $skipCount++
    $syncDetails += @{
      file = $srcName
      status = "skipped"
      reason = "source not found"
    }
    continue
  }

  try {
    $srcHash = Get-FileHash256 $srcPath
    $dstHash = if (Test-Path $dstPath) { Get-FileHash256 $dstPath } else { $null }

    # Only copy if different or doesn't exist on Drive
    if ($srcHash -ne $dstHash) {
      Copy-Item $srcPath -Destination $dstPath -Force
      Write-Log "✓ Synced: $srcName" "OK"
      $syncCount++
      $syncDetails += @{
        file = $srcName
        status = "synced"
        source_hash = $srcHash
        destination_hash = Get-FileHash256 $dstPath
      }
    } else {
      Write-Log "SKIP: $srcName (no changes)" "INFO"
      $skipCount++
      $syncDetails += @{
        file = $srcName
        status = "skipped"
        reason = "checksum match"
      }
    }
  } catch {
    Write-Log "✗ ERROR syncing $srcName : $_" "ERROR"
    $errorCount++
    $syncDetails += @{
      file = $srcName
      status = "failed"
      error = $_.Exception.Message
    }
  }
}

$duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)

Write-Log "" "INFO"
Write-Log "========== SYNC SUMMARY ==========" "OK"
Write-Log "Files synced: $syncCount" "OK"
Write-Log "Files skipped: $skipCount" "INFO"
Write-Log "Errors: $errorCount" $(if ($errorCount -gt 0) { "ERROR" } else { "OK" })
Write-Log "Duration: $duration seconds" "INFO"

# Log to audit trail
$auditEntry = @{
  timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
  task = "drive-sync"
  status = if ($errorCount -eq 0) { "success" } else { "partial" }
  duration_seconds = $duration
  files_synced = $syncCount
  files_skipped = $skipCount
  errors = $errorCount
  details = $syncDetails
  log_file = $runLog
} | ConvertTo-Json -Compress -Depth 5

$auditEntry | Add-Content $AuditLog

Write-Log "Audit logged: $AuditLog" "INFO"
Write-Log "========== DRIVE SYNC COMPLETE ==========" "OK"

exit $(if ($errorCount -gt 0) { 1 } else { 0 })
