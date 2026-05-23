# Project Master

## Overview

Project Master는 대화, 결정, next action, PRD, session 결과를 Markdown으로 보존하는 파일 기반 프로젝트 메모리입니다. `.project-master/sessions/`는 session별 원본 기록이고, `.project-master/index/`는 프로젝트 전체의 현재 상태를 모아 보여 줍니다.

## Initialize

프로젝트 루트에서 실행합니다.

```bash
./pm init
./pm status
```

`init`은 누락된 파일만 만들며 기존 내용은 덮어쓰지 않습니다.

## Daily Agent Workflow

작업을 시작할 때 `main.md`와 필요한 `index/*.md`를 읽고 `./pm status`를 실행합니다. 새 대화를 추적해야 하면 session을 생성합니다.

```bash
./pm session new
./pm raw append --session S-001 --role user --content "요청 내용"
./pm turn add --session S-001 --prompt "요청" --content "다룬 범위" --intent "사용자 의도" --response "응답 요약" --result "변경 결과"
```

## Session Lifecycle

결정, action, question은 발생하는 즉시 기록합니다.

```bash
./pm decision add --session S-001 --title "파일 기반 기록 사용" --status active --rationale "git에서 검토 가능" --source "사용자 요구"
./pm action add --session S-001 --text "CLI 검증 실행" --status pending --owner "agent"
./pm question add --session S-001 --text "배포 시 설치 경로는 무엇인가?" --status open
```

session 종료 전 `sessions/S-xxx/summary.md`의 `TBD`를 실제 의미 요약으로 교체합니다. CLI는 의미를 추측해 작성하지 않습니다.

```bash
./pm session close S-001
./pm index update --session S-001
./pm check
```

## PRD Lifecycle

PRD는 제품 요구사항과 변경 상태의 source of truth이며, session은 시간 순 source record입니다. 새 PRD와 관계, 상태 이동은 CLI로 기록합니다.

```bash
./pm prd new --title "요구사항 이름" --status backlog --owner "owner"
./pm prd list
./pm prd show P-001
./pm prd link P-001 --session S-001
./pm prd link P-001 --turn T-001
./pm prd link P-001 --decision D-001
./pm prd link P-001 --action A-001
./pm prd status P-001 --status active
./pm prd index
```

`prd link`는 이미 기록된 관계를 다시 추가하지 않습니다. `prd status`는 metadata와 `prd-spec/<status>/` 위치를 함께 갱신하며, `cancelled`도 삭제 대신 별도 상태 폴더로 보존합니다.

## Recover Context

새 session에서 맥락을 복구할 때는 `main.md`, `index/decisions.md`, `index/next-actions.md`, `index/open-questions.md`, `index/session-map.md`를 순서대로 확인합니다. 필요한 경우 가장 최근 session의 `summary.md`와 `turns.md`를 추가로 읽습니다.

## Validate

```bash
./pm check
python3 -m unittest discover -s tests -v
```

`check`는 필수 구조, session 이름, 누락 파일, 관리 ID 중복, PRD 상태/경로와 relation 무결성, PRD map 최신성을 검사합니다.

## Known Limits

CLI는 자동 의미 요약, requirement 수준 변경 이력 명령, 결정 간 충돌 판단을 하지 않습니다. 사람 또는 agent가 의미 있는 문장을 작성하고 CLI는 구조와 기계적 반영을 담당합니다.
