# Decisions Index

프로젝트 전체의 결정 현재 상태입니다. `pm index update`가 관리 블록을 추가하거나 갱신합니다.

<!-- PM:decision:D-001:start -->
## D-001: Use managed PRD metadata and deterministic map rebuild

- Status: active
- Source Session: S-001
- Date: 2026-05-23
- Rationale: Preserves authored Markdown while keeping status and links machine-verifiable
- Decision: Use managed PRD metadata and deterministic map rebuild
- Source Detail: PRD-centered improvement handoff
- Supersedes:
- Superseded by:
<!-- PM:decision:D-001:end -->

<!-- PM:decision:D-002:start -->
## D-002: Serialize and atomically replace PRD managed state

- Status: active
- Source Session: S-002
- Date: 2026-05-23
- Rationale: Prevents concurrent link loss and partial Markdown observations while preserving file-based storage
- Decision: Serialize and atomically replace PRD managed state
- Source Detail: Post-implementation review findings
- Supersedes:
- Superseded by:
<!-- PM:decision:D-002:end -->

<!-- PM:decision:D-003:start -->
## D-003: Complete the skill-facing CLI contract before authoring the skill

- Status: active
- Source Session: S-003
- Date: 2026-05-23
- Rationale: A skill should teach durable executable commands rather than preserve avoidable manual gaps
- Decision: Complete the skill-facing CLI contract before authoring the skill
- Source Detail: User goal to optimize the repository before freezing it behind a skill
- Supersedes:
- Superseded by:
<!-- PM:decision:D-003:end -->

<!-- PM:decision:D-004:start -->
## D-004: Track managed requirements as project-global IDs inside PRDs

- Status: active
- Source Session: S-003
- Date: 2026-05-23
- Rationale: Requirements need provenance and status history while authored PRD narrative remains editable; authored legacy IDs remain reserved
- Decision: Track managed requirements as project-global IDs inside PRDs
- Source Detail: Skill-ready operational contract implementation
- Supersedes:
- Superseded by:
<!-- PM:decision:D-004:end -->

<!-- PM:decision:D-005:start -->
## D-005: Closed sessions reject new source events while finish remains idempotent

- Status: active
- Source Session: S-004
- Date: 2026-05-24
- Rationale: A closed session is a durable handoff snapshot, but deterministic re-materialization of its summary and indexes must remain safe
- Decision: Closed sessions reject new source events while finish remains idempotent
- Source Detail: Final operational contract review
- Supersedes:
- Superseded by:
<!-- PM:decision:D-005:end -->
