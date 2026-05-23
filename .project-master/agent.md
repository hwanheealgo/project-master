# Project Master Agent Instructions

## Purpose

이 프로젝트는 `.project-master/`를 대화와 구현 사이의 지속 가능한 프로젝트 메모리로 사용합니다.

## When To Use

제품 요구사항, 아키텍처 결정, 구현 계획, 미해결 질문, blocker, session summary, next action, 프로젝트 방향 변경이 대화에 포함되면 이 시스템을 사용합니다.

## Core Rules

1. 프로젝트 수준의 제안 전에 `./pm context brief`를 실행하고 필요 시 source 문서를 확인합니다.
2. 가능한 경우 수동 편집보다 `pm` CLI를 사용합니다.
3. 중요한 사용자 의도는 session의 `turns.md`에 기록합니다.
4. 결정은 session에 기록하고 `index/decisions.md`로 반영합니다.
5. next action은 session에 기록하고 `index/next-actions.md`로 반영합니다.
6. session 종료 시 `./pm session finish`로 의미 summary, indexes, validation을 함께 반영합니다.
7. raw conversation과 해석된 summary를 분리합니다.
8. 큰 raw log를 global index에 복제하지 않습니다.
9. 간결하고 신호가 높은 기록을 선호합니다.
10. 대체된 결정은 삭제하지 않고 `superseded` 상태로 남깁니다.
11. 요구사항 대화가 발생하면 관련 PRD를 찾거나 `./pm prd new`로 생성합니다.
12. 중요한 요구사항 변화는 `./pm requirement add/status`로 source session/turn과 상태 history를 남깁니다.
13. action, question, 대체된 decision의 현재 상태는 해당 `status` 명령으로 갱신합니다.
14. closed session에는 새 raw/turn/decision/action/question event를 추가하지 않습니다.

## Session Workflow

### Start Of Work

1. `./pm context brief`를 실행합니다.
2. 필요한 근거가 있으면 관련 PRD, index 또는 최근 session 원문을 읽습니다.
3. 새 작업을 추적해야 하면 `./pm session new`를 실행합니다.

### During Work

1. 의미 있는 raw context가 있으면 `./pm raw append`로 추가합니다.
2. 중요한 turn은 `./pm turn add`로 기록합니다.
3. 결정, action, question이 발생하거나 상태가 변하면 해당 명령으로 기록합니다.
4. PRD에 영향을 주는 변화는 `./pm prd link`, `./pm prd status`, `./pm requirement add/status`로 반영합니다.

### End Of Work

1. agent가 one-line summary, flow, user intent, next action을 작성합니다.
2. `./pm session finish S-xxx --one-line "..." --flow "..." --intent "..." --next "..."`를 실행합니다.
3. 필요하면 `./pm context brief`로 handoff 상태를 확인합니다.
