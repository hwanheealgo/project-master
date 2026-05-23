# PRD: Skill-ready Project Master operational contract

<!-- PM:prd:P-002:start -->
- PRD ID: P-002
- Title: Skill-ready Project Master operational contract
- Status: done
- Owner: agent
- Created: 2026-05-23
- Updated: 2026-05-23
- Source Sessions: S-003
- Source Turns: T-003, T-004
- Related Decisions: D-003, D-004
- Related Actions: A-003
<!-- PM:prd:P-002:end -->

## Problem

현재 CLI는 PRD와 session 기록의 무결성을 보장하지만, 새 agent가 여러
index 파일을 직접 조합해 읽어야 하고 session 종료도 수동 편집과 세 개의
명령으로 나뉜다. PRD 본문에는 requirement ID가 있지만 CLI가 상태 이력을
관리하지 않으며, decision/action/question도 생성 후 상태 전환 surface가
없다. 이 상태에서 skill을 고정하면 수동 우회 절차가 public contract가 된다.

## Goals

- 새 agent가 한 명령으로 현재 프로젝트 문맥을 복구한다.
- agent가 제공한 의미 요약을 보존하면서 session 종료와 index 검증을 한
  명령으로 완료한다.
- requirement provenance와 current-state lifecycle을 CLI/검증 범위에 넣는다.
- Project Master 자체가 이번 개선을 PRD와 session으로 기록하는 예제가 된다.

## Non-goals

- Hermes profile, Slack routing, channel binding 저장
- 자동 의미 요약 또는 semantic retrieval
- 범용 `work record` 추상화로 기존 의미 있는 record type을 합치는 작업

## Users / Personas

repo-local project memory를 읽고 쓰는 Hermes profile 및 코드 작업 agent.

## Requirements

- `context brief`는 저장된 현재 상태에서 짧고 결정적인 시작 문맥을 만든다.
- `session finish`는 제공된 의미 요약을 기록하고 close/index/check를 완료한다.
- requirement는 project-global ID, parent PRD, 상태와 provenance history를 가진다.
- 결정, action, question은 CLI로 current status를 변경할 수 있어야 한다.

<!-- PM:requirement:R-005:start -->
## R-005: Provide deterministic context brief for agent startup

- Requirement ID: R-005
- PRD: P-002
- Text: Provide deterministic context brief for agent startup
- Status: implemented
- Created: 2026-05-23
- Updated: 2026-05-23
- Last Source Session: S-003
- Last Source Turn: T-004

### History

- 2026-05-23: status=proposed; session=S-003; turn=T-003
- 2026-05-23: status=accepted; session=S-003; turn=T-003
- 2026-05-23: status=implemented; session=S-003; turn=T-004
<!-- PM:requirement:R-005:end -->

<!-- PM:requirement:R-006:start -->
## R-006: Finish a session with supplied semantic summary and structural validation

- Requirement ID: R-006
- PRD: P-002
- Text: Finish a session with supplied semantic summary and structural validation
- Status: implemented
- Created: 2026-05-23
- Updated: 2026-05-23
- Last Source Session: S-003
- Last Source Turn: T-004

### History

- 2026-05-23: status=proposed; session=S-003; turn=T-003
- 2026-05-23: status=accepted; session=S-003; turn=T-003
- 2026-05-23: status=implemented; session=S-003; turn=T-004
<!-- PM:requirement:R-006:end -->

<!-- PM:requirement:R-007:start -->
## R-007: Track requirement status history with source provenance

- Requirement ID: R-007
- PRD: P-002
- Text: Track requirement status history with source provenance
- Status: implemented
- Created: 2026-05-23
- Updated: 2026-05-23
- Last Source Session: S-003
- Last Source Turn: T-004

### History

- 2026-05-23: status=proposed; session=S-003; turn=T-003
- 2026-05-23: status=accepted; session=S-003; turn=T-003
- 2026-05-23: status=implemented; session=S-003; turn=T-004
<!-- PM:requirement:R-007:end -->

<!-- PM:requirement:R-008:start -->
## R-008: Expose current-state transitions for decisions actions and questions

- Requirement ID: R-008
- PRD: P-002
- Text: Expose current-state transitions for decisions actions and questions
- Status: implemented
- Created: 2026-05-23
- Updated: 2026-05-23
- Last Source Session: S-003
- Last Source Turn: T-004

### History

- 2026-05-23: status=proposed; session=S-003; turn=T-003
- 2026-05-23: status=accepted; session=S-003; turn=T-003
- 2026-05-23: status=implemented; session=S-003; turn=T-004
<!-- PM:requirement:R-008:end -->

## Functional Requirements

- `./pm context brief`
- `./pm session finish S-xxx --one-line ... --flow ... --intent ... --next ...`
- `./pm requirement add/list/status`
- `./pm decision status`, `./pm action status`, `./pm question status`
- managed requirement 무결성 검사와 회귀 테스트

## Non-functional Requirements

- authored Markdown 본문은 managed block 갱신으로 훼손하지 않는다.
- ID 발급과 상태 mutation은 project lock 아래 직렬화한다.
- brief 출력은 저장된 사실을 집계하며 의미를 추측하지 않는다.

## UX / Workflow

agent는 `context brief`로 시작하고, 필요한 기록을 유형별 명령으로 남긴 뒤
`session finish`로 종료한다. PRD에 영향을 주는 요구사항 변화는 requirement
명령으로 provenance와 함께 남긴다.

## Data Model

Requirement는 PRD 문서 안의 managed block으로 저장하고 `R-xxx` ID는 프로젝트
전체에서 유일하다. status 변화는 같은 block의 append-only history로 보존하며
source session/turn을 검증한다.

## Edge Cases

- 존재하지 않는 PRD 또는 source record에 requirement를 연결하지 않는다.
- `session finish`는 빈 의미 필드를 거부한다.
- 동시 ID 발급과 status 갱신은 기존 lock/atomic-write 정책을 따른다.

## Success Criteria

새 CLI command의 정상/실패 경로와 기존 lifecycle 회귀 테스트가 통과하고,
현재 레포에 `./pm context brief`와 `./pm check`를 실행했을 때 P-002/S-003
기록을 포함한 일관된 상태를 제시한다.

## Open Questions

없음. profile 및 channel 통합은 Project Master 데이터 모델 밖의 후속 작업이다.

## Rollout Plan

CLI, template, 문서, 자체 기록과 테스트를 함께 갱신한 뒤 이 contract에 맞춘
`project-master` skill을 별도 작성한다.

## Requirement Changes

- 2026-05-23: S-003/T-003/D-003에서 skill-facing contract 목표를 수립했다.
- 2026-05-23: R-005부터 R-008을 managed requirement로 생성하고 accepted
  상태로 provenance와 함께 기록했다.
- 2026-05-23: 구현 및 회귀 검증 후 R-005부터 R-008을 implemented로 전환했다.

## Changelog

- 2026-05-23: Skill-ready operational contract 작업을 개시했다.
- 2026-05-23: context/finish, requirement lifecycle, record status transition,
  documentation, self-hosted records와 회귀 검증을 구현했다.
