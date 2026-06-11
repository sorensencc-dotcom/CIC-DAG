# Cast Iron Charlie — Digital Asset Management System

**Status:** ✅ LIVE | 663 media items | 8 automated tasks | Production-ready

---

## Quick Start

View automation schedule:
```powershell
& 'C:\CIC_MEDIA_LIBRARY\scheduling\show-schedule.ps1'
```

Run all tasks now:
```powershell
& 'C:\CIC_MEDIA_LIBRARY\scheduling\task-scheduler-agent.ps1' -Mode execute -Force
```

---

## Documentation Index

### Core Architecture
- **[CIC_DAM_SYSTEM.md](./CIC/CIC_DAM_SYSTEM.md)** — 5-tier ingestion pipeline, media ID scheme, metadata schemas
- **[AUTOMATION_SUMMARY.md](./AUTOMATION_SUMMARY.md)** — Complete automation infrastructure (8 tasks, schedules, execution model)

### Operations
- **[BULK_INGESTION_GUIDE.md](./CIC/BULK_INGESTION_GUIDE.md)** — Consolidate media from Google Drive (Phase 1-3 workflow)
- **[CIC/README.md](./CIC/README.md)** — Project overview, design principles, technical notes

### Skills & Agents
- **[automation-audit.md](C:\Users\soren\.claude\skills\automation-audit.md)** — Weekly scanning for new automation opportunities
- **[skill-contribution-pipeline.md](C:\Users\soren\.claude\skills\skill-contribution-pipeline.md)** — Auto-submit skill improvements upstream

### Research Logs (By Topic)
Generated & maintained by `maintain-research-log.ps1`:
- Research logs: `./CIC/research_logs/`
- Format: Narrative .md + structured .json index per topic

---

## File Structure

```
C:\CIC_MEDIA_LIBRARY\
├── CIC/
│   ├── media/
│   │   ├── By_Topic/        (9 research categories)
│   │   ├── By_Type/         (Photographs, Documents)
│   │   └── By_Source/       (Archive origin)
│   ├── metadata/
│   │   ├── master_media_inventory.csv      (single source of truth)
│   │   ├── search_index.json
│   │   ├── treatment_crossref_index.json
│   │   └── folder_to_topic_mapping.json
│   ├── research_logs/       (topic narratives + indexes)
│   ├── operations/          (follow-ops, marketing reports)
│   ├── versions/            (Treatment v13, CHANGELOG)
│   ├── scripts/             (ingest, classify, organize, maintain-research-log, curate, follow-ops)
│   └── logs/                (execution logs, scheduled_runs/)
├── scheduling/
│   ├── task-registry.json                   (central task definitions)
│   ├── task-scheduler-agent.ps1             (orchestrator)
│   ├── scan-automation-opportunities.ps1    (weekly discovery)
│   ├── show-schedule.ps1                    (dashboard)
│   ├── tasks/               (individual automation scripts)
│   └── reports/             (audit trails, JSONL logs)
├── AUTOMATION_SUMMARY.md    (this project)
└── README.md                (this file)
```

---

## Automated Tasks (8 Total)

### Daily (3:00 - 6:15 AM)
1. **Interview Ingest** (3:00 AM) — Run ingestion pipeline on new interview data
2. **Drive Sync** (4:00 AM) — Keep Google Drive backup current (checksum-based)
3. **Report Generation** (5:00 AM) — Create operational reports (inventory, quality, rights)
4. **Config Validation** (6:00 AM) — Health check: JSON, CSV, directory structure

### Weekly
5. **CIC Operations** (Monday 8:00 AM) — Follow-ops assessment + Dad questions
6. **Marketing Curation** (Monday 8:30 AM) — Social calendar, pitch deck, grants (depends on #5)
7. **Automation Audit** (Sunday 10:00 PM) — Scan for new automation opportunities
8. **Changelog** (Sunday 11:00 PM) — Auto-generate CHANGELOG.json + CHANGELOG.md

See [AUTOMATION_SUMMARY.md](./AUTOMATION_SUMMARY.md) for full details.

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Media indexed | 663 items |
| Rights pre-cleared | 630 (95%) |
| Quality score (avg) | 7/10 |
| Automated tasks | 8 |
| Manual work eliminated | ~17-20 hrs/week |
| Audit coverage | 100% (JSONL logs) |

---

## Common Commands

```powershell
# View schedule
& 'C:\CIC_MEDIA_LIBRARY\scheduling\show-schedule.ps1'

# Check task status
& 'C:\CIC_MEDIA_LIBRARY\scheduling\task-scheduler-agent.ps1' -Mode status

# Validate all scripts exist
& 'C:\CIC_MEDIA_LIBRARY\scheduling\task-scheduler-agent.ps1' -Mode validate

# View execution history
Get-Content 'C:\CIC_MEDIA_LIBRARY\scheduling\reports\*_audit.jsonl' | ConvertFrom-Json | Format-Table timestamp, task, status

# View recent logs
Get-ChildItem 'C:\CIC_MEDIA_LIBRARY\logs\scheduled_runs\' | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | Get-Content
```

---

## Git

Repository initialized: `C:\CIC_MEDIA_LIBRARY\.git`

Latest commit:
```
00eb53d Initial commit: Cast Iron Charlie DAM + Automation Infrastructure
```

---

## Support

- Architecture questions → [CIC_DAM_SYSTEM.md](./CIC/CIC_DAM_SYSTEM.md)
- Automation details → [AUTOMATION_SUMMARY.md](./AUTOMATION_SUMMARY.md)
- Bulk operations → [BULK_INGESTION_GUIDE.md](./CIC/BULK_INGESTION_GUIDE.md)
- Troubleshooting → See section in AUTOMATION_SUMMARY.md

---

**Last updated:** 2026-06-07 | **Status:** Production | **Ready for:** Phase 24+ extensions
