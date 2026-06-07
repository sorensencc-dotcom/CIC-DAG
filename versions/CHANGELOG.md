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

Generated: 2026-06-07 17:52:27
