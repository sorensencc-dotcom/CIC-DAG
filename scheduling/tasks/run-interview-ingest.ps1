<#
.SYNOPSIS
  Wrapper for interview-ingest.ps1 with logging and error handling.
  Runs the interview ingestion pipeline on a schedule.

.DESCRIPTION
  Executes the interview ingestion pipeline, captures results,
  logs to central audit trail, and reports status.

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\tasks\run-interview-ingest.ps1'
#>

$RootPath = "C:\CIC_MEDIA_LIBRARY"
$ScriptPath = "$RootPath\scripts\interview-ingest.ps1"
$LogPath = "$RootPath\logs\scheduled_runs"
$AuditLog = "$RootPath\scheduling\reports\interview_ingest_audit.jsonl"

if (-not (Test-Path $LogPath)) {
  New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$runLog = "$LogPath\interview_ingest_run_$timestamp.log"

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "[$ts] [$Level] $Message" | Tee-Object -FilePath $runLog -Append
}

Write-Log "========== INTERVIEW INGEST STARTED ==========" "INFO"
Write-Log "Script: $ScriptPath" "INFO"
Write-Log "Time: $(Get-Date)" "INFO"

if (-not (Test-Path $ScriptPath)) {
  Write-Log "ERROR: Script not found at $ScriptPath" "ERROR"
  exit 1
}

$startTime = Get-Date
try {
  Write-Log "Executing interview ingestion pipeline..." "INFO"
  & $ScriptPath -ErrorAction Stop 2>&1 | ForEach-Object {
    Write-Log "$_" "INFO"
  }

  $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
  Write-Log "✓ Interview ingest completed successfully" "OK"
  Write-Log "Duration: $duration seconds" "OK"

  # Log to audit trail
  $auditEntry = @{
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    task = "interview-ingest"
    status = "success"
    duration_seconds = $duration
    log_file = $runLog
  } | ConvertTo-Json -Compress

  $auditEntry | Add-Content $AuditLog

  exit 0
} catch {
  $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
  Write-Log "✗ Interview ingest failed: $_" "ERROR"
  Write-Log "Duration: $duration seconds" "ERROR"

  # Log failure to audit trail
  $auditEntry = @{
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    task = "interview-ingest"
    status = "failed"
    duration_seconds = $duration
    error = $_.Exception.Message
    log_file = $runLog
  } | ConvertTo-Json -Compress

  $auditEntry | Add-Content $AuditLog

  exit 1
}
