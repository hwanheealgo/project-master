# PRD: PRD-centered Project Master improvement

<!-- PM:prd:P-001:start -->
- PRD ID: P-001
- Title: PRD-centered Project Master improvement
- Status: done
- Owner: agent
- Created: 2026-05-23
- Updated: 2026-05-23
- Source Sessions: S-001, S-002
- Source Turns: T-001, T-002
- Related Decisions: D-001, D-002
- Related Actions: A-001, A-002
<!-- PM:prd:P-001:end -->

## Problem

기존 MVP는 session과 decision/action/question을 추적하지만, PRD는 수동 scaffold여서 요구사항이 어떤 기록과 구현 결과에 연결되는지 검증할 수 없었다.

## Goals

- PRD에 안정적인 `P-xxx` identity와 lifecycle command를 제공한다.
- PRD를 source session/turn 및 관련 decision/action과 연결한다.
- PRD map과 무결성 검사를 CLI가 관리한다.

## Non-goals

- raw conversation 저장 형식 변경
- 자동 summary 생성 또는 semantic retrieval
- requirement-level mutation command 구현

## Users / Personas

대상 사용자와 상황을 설명합니다.

## Requirements

- R-001 (accepted): `pm prd new/list/show`가 안정적인 PRD identity를 관리한다.
- R-002 (accepted): `pm prd status/link/index`가 상태, 관계, map을 멱등적으로 관리한다.
- R-003 (accepted): `pm check`가 PRD metadata, status/path, relation target 무결성을 검증한다.
- R-004 (accepted): PRD mutation은 동시 실행에서도 링크를 보존하고, map drift 및 잘못된 저장 위치를 검출한다.

## Functional Requirements

- `backlog`, `active`, `done`, `cancelled` 상태 폴더를 지원한다.
- metadata만 managed block으로 갱신하여 수동 작성 본문을 보존한다.
- map은 PRD metadata에서 deterministic rebuild한다.

## Non-functional Requirements

성능, 보안, 운영성 등 품질 요구사항을 기록합니다.

## UX / Workflow

사용 흐름을 기록합니다.

## Data Model

PRD managed metadata는 ID, title, status, owner, 날짜와 `Source Sessions`, `Source Turns`, `Related Decisions`, `Related Actions`를 포함한다. 상세 요구사항과 change history는 Markdown 본문에서 append-friendly하게 유지한다.

## Edge Cases

예외와 경계 상황을 기록합니다.

## Success Criteria

PRD lifecycle/link/index/check 테스트와 기존 session index lifecycle 테스트가 모두 통과하고, 현재 프로젝트에 대한 `./pm check`도 통과한다.

## Open Questions

아직 결정하지 않은 질문을 기록합니다.

## Rollout Plan

출시 또는 적용 단계를 기록합니다.

## Requirement Changes

- 2026-05-23: R-001, R-002, R-003 accepted and implemented from S-001 / T-001 / D-001.
- 2026-05-23: R-004 accepted and implemented from S-002 / T-002 / D-002 after integrity review.

## Changelog

- 2026-05-23: PRD-centered Project Master improvement implemented and verified.
- 2026-05-23: Added atomic/serialized mutation and stricter derived-index integrity validation.
