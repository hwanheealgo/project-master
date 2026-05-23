# PRD: Closed session and authored summary hardening

<!-- PM:prd:P-003:start -->
- PRD ID: P-003
- Title: Closed session and authored summary hardening
- Status: done
- Owner: agent
- Created: 2026-05-24
- Updated: 2026-05-24
- Source Sessions: S-004
- Source Turns: T-005, T-006
- Related Decisions: D-005
- Related Actions: A-004
<!-- PM:prd:P-003:end -->

## Problem

최종 contract 검토에서 `session finish`가 선택 인자 생략 시 이미 작성된
optional summary section을 기본 문구로 덮을 수 있고, closed session에도
새 source event를 append할 수 있음이 드러났다. 둘 다 handoff snapshot의
신뢰성을 훼손한다.

## Goals

- authored optional summary section을 보존한다.
- closed session에 raw/turn/decision/action/question source event 추가를 막는다.
- 이미 닫힌 session에 대한 idempotent `session finish` 재실행은 허용한다.

## Non-goals

- closed record의 정당한 current-state status transition 차단
- profile 또는 skill 구현

## Users / Personas

완료된 session summary를 handoff 근거로 사용하는 agent.

## Requirements

중요한 요구사항은 CLI가 안정적인 ID(`R-xxx`)와 상태 이력을 관리합니다.

<!-- PM:requirement:R-009:start -->
## R-009: Preserve authored optional session summary sections when finish flags are omitted

- Requirement ID: R-009
- PRD: P-003
- Text: Preserve authored optional session summary sections when finish flags are omitted
- Status: implemented
- Created: 2026-05-24
- Updated: 2026-05-24
- Last Source Session: S-004
- Last Source Turn: T-006

### History

- 2026-05-24: status=accepted; session=S-004; turn=T-005
- 2026-05-24: status=implemented; session=S-004; turn=T-006
<!-- PM:requirement:R-009:end -->

<!-- PM:requirement:R-010:start -->
## R-010: Reject new source records after a session has closed

- Requirement ID: R-010
- PRD: P-003
- Text: Reject new source records after a session has closed
- Status: implemented
- Created: 2026-05-24
- Updated: 2026-05-24
- Last Source Session: S-004
- Last Source Turn: T-006

### History

- 2026-05-24: status=accepted; session=S-004; turn=T-005
- 2026-05-24: status=implemented; session=S-004; turn=T-006
<!-- PM:requirement:R-010:end -->

## Functional Requirements

- `session finish`는 제공되지 않은 discussion/analysis의 authored 값을 보존한다.
- source event 추가 명령은 closed session을 명확한 오류로 거부한다.
- 재실행 가능한 `session finish`는 index/changelog 중복을 만들지 않는다.

## Non-functional Requirements

검증은 기존 lock/atomic write 및 managed record 방식을 유지한다.

## UX / Workflow

agent는 open session에서만 source event를 기록하고, 완료 뒤에는 상태 전환
명령 또는 idempotent finish 재실행만 사용한다.

## Data Model

summary의 `- Status: closed`가 source append 금지 경계다.

## Edge Cases

- finish 재실행에서 discussion/analysis flag를 생략한다.
- closed session에 turn을 추가하려 한다.

## Success Criteria

authored summary 보존, idempotent finish와 closed source rejection 테스트가
통과하고 전체 회귀 및 `./pm check`가 통과한다.

## Open Questions

없음.

## Rollout Plan

이번 CLI contract 변경에 포함해 skill 작성 전 최종 검증한다.

## Requirement Changes

- 2026-05-24: S-004/T-005/D-005에서 R-009와 R-010을 accepted로 기록했다.
- 2026-05-24: authored summary preservation과 closed source rejection을
  검증한 뒤 R-009와 R-010을 implemented로 전환했다.

## Changelog

- 2026-05-24: 최종 lifecycle hardening 검토를 시작했다.
- 2026-05-24: lifecycle invariant 구현과 회귀 검증을 완료했다.
