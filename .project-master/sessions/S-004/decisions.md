# Decisions - S-004

이 session에서 결정된 사항을 기록합니다.

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
