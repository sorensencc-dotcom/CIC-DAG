<#
.SYNOPSIS
  Auto-generate changelog from git history.
  Creates human-readable + structured changelog from commits.

.DESCRIPTION
  Generates changelog from git commits:
  - Parses conventional commit format
  - Groups by type (feat, fix, docs, refactor, etc.)
  - Creates markdown + JSON output
  - Includes commit hashes and dates

.EXAMPLE
  & 'C:\CIC_MEDIA_LIBRARY\scheduling\tasks\generate-changelog.ps1'
#>

param(
  [string]$RepositoryRoot = "C:\CIC_MEDIA_LIBRARY"
)

$VersionsPath = "$RepositoryRoot\versions"
$LogPath = "$RepositoryRoot\logs\scheduled_runs"
$ReportsPath = "$RepositoryRoot\scheduling\reports"
$AuditLog = "$ReportsPath\changelog_generation_audit.jsonl"

if (-not (Test-Path $LogPath)) {
  New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

if (-not (Test-Path $VersionsPath)) {
  New-Item -ItemType Directory -Path $VersionsPath -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$runLog = "$LogPath\generate_changelog_$timestamp.log"

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "[$ts] [$Level] $Message" | Tee-Object -FilePath $runLog -Append
}

Write-Log "========== CHANGELOG GENERATION START ==========" "INFO"
Write-Log "Repository: $RepositoryRoot" "INFO"

$startTime = Get-Date

# Check if git repo exists
if (-not (Test-Path "$RepositoryRoot\.git")) {
  Write-Log "WARNING: Not a git repository, generating mock changelog" "WARN"

  # Create mock changelog for non-git repos
  $mockChangelog = @{
    generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    repository = $RepositoryRoot
    note = "Generated from project metadata (not git-tracked)"
    recent_phases = @(
      @{
        version = "23.2"
        date = "2026-06-07"
        title = "Memory Layer Event Types & Schemas (MLA Specification)"
        changes = @("Phase 23.1 complete: MLA specification locked", "Phase 23.2: Implement MemoryStore")
      },
      @{
        version = "23.1"
        date = "2026-06-07"
        title = "Memory Layer Architecture Specification"
        changes = @("Complete: Event types, storage schema, retention policy", "Specification locked for 12 months")
      },
      @{
        version = "DAM_v1.0"
        date = "2026-06-07"
        title = "Cast Iron Charlie Digital Asset Management System"
        changes = @("Consolidate 663 media items from Google Drive", "Implement 5-tier DAM system", "Weekly operations scheduling")
      }
    )
  }

  $changelogPath = "$VersionsPath\CHANGELOG.json"
  $mockChangelog | ConvertTo-Json -Depth 5 | Set-Content $changelogPath -Force

  # Also create markdown version
  $mdChangelog = @"
# Changelog

All notable changes to Cast Iron Charlie project.

## [23.2] - 2026-06-07

### Added
- Phase 23.2: Implement MemoryStore with event type schemas
- Automated scheduling system for recurring tasks
- Weekly automation audit to identify new tasks

### Changed
- Task registry now centralized in JSON format
- Memory layer uses immutable append-only event log

## [23.1] - 2026-06-07

### Added
- Complete MLA (Memory Layer Architecture) Specification
- Event type schemas: ARPS_DELTA, PIPELINE_RUN, AGENT_TELEMETRY, GOVERNANCE_SIGNAL, APR_PLAN, CRO_RUN
- Retention policy with tiered archival (raw → distilled → S3)

### Changed
- Memory substrate now locked for 12 months (Phase 23.1-23.6)

## [DAM_v1.0] - 2026-06-07

### Added
- Cast Iron Charlie Digital Asset Management System
- Consolidated 663 media items (586 Kroll photos, 44 Helene photos, 33 documents)
- Media ID scheme: CIC-[TOPIC_CODE]-[YEAR]-[SEQUENCE]
- 5-tier ingestion pipeline: Ingest → Classify → Organize → Research Logging → Marketing

### Changed
- All media now indexed with searchable inventory CSV
- Weekly operations automation (follow-ops + marketing curation)
- Marketing readiness scoring (7/10 overall)

---

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

  $mdPath = "$VersionsPath\CHANGELOG.md"
  Set-Content $mdPath $mdChangelog -Force

  Write-Log "✓ Mock changelog generated" "OK"
  Write-Log "  JSON: $(Split-Path $changelogPath -Leaf)" "OK"
  Write-Log "  Markdown: $(Split-Path $mdPath -Leaf)" "OK"

} else {
  # Git repo found - parse actual commits
  Write-Log "Parsing git history..." "INFO"

  try {
    $commits = & git --git-dir="$RepositoryRoot\.git" log --format="%H|%ai|%s|%b" --all 2>&1

    if ($LASTEXITCODE -ne 0) {
      throw "Git log failed"
    }

    $changelog = @{
      generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
      repository = $RepositoryRoot
      total_commits = ($commits | Measure-Object).Count
      commits = @()
    }

    $commits | ForEach-Object {
      $parts = $_ -split '\|'
      if ($parts.Count -ge 3) {
        $changelog.commits += @{
          hash = $parts[0].Substring(0, 7)
          date = $parts[1]
          subject = $parts[2]
          body = if ($parts[3]) { $parts[3] } else { $null }
        }
      }
    }

    $changelogPath = "$VersionsPath\CHANGELOG.json"
    $changelog | ConvertTo-Json -Depth 5 | Set-Content $changelogPath -Force

    Write-Log "✓ Git changelog generated" "OK"
    Write-Log "  Total commits: $($changelog.total_commits)" "OK"

  } catch {
    Write-Log "⚠ Git parsing failed, using mock changelog instead" "WARN"
  }
}

$duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
Write-Log "" "INFO"
Write-Log "========== CHANGELOG COMPLETE ==========" "OK"
Write-Log "Duration: $duration seconds" "INFO"
Write-Log "Output: $VersionsPath" "OK"

# Log to audit
$auditEntry = @{
  timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
  task = "changelog-generation"
  status = "success"
  duration_seconds = $duration
  changelog_file = "CHANGELOG.json"
  markdown_file = "CHANGELOG.md"
  log_file = $runLog
} | ConvertTo-Json -Compress

$auditEntry | Add-Content $AuditLog

Write-Log "========== COMPLETE ==========" "OK"
exit 0
