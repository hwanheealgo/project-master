# Project Master

## Overview

Project Master는 대화, 결정, next action, PRD, requirement, session 결과를 Markdown으로 보존하는 파일 기반 프로젝트 메모리입니다. `.project-master/sessions/`는 session별 원본 기록이고, `.project-master/index/`는 프로젝트 전체의 현재 상태를 모아 보여 줍니다.

## Initialize

프로젝트 루트에서 실행합니다.

```bash
./pm init
./pm status
```

`init`은 누락된 파일만 만들며 기존 내용은 덮어쓰지 않습니다.

## Daily Agent Workflow

작업을 시작할 때는 저장된 현재 상태를 집계하는 brief를 먼저 읽습니다. 상세 근거가 필요하면 `main.md`, `index/*.md`, 최근 session 또는 활성 PRD를 추가로 확인합니다.

```bash
./pm context brief
./pm session new
./pm raw append --session S-001 --role user --content "요청 내용"
./pm turn add --session S-001 --prompt "요청" --content "다룬 범위" --intent "사용자 의도" --response "응답 요약" --result "변경 결과"
```

## Session Lifecycle

결정, action, question은 발생하는 즉시 기록하고, 상태가 변하면 CLI로 갱신합니다.

```bash
./pm decision add --session S-001 --title "파일 기반 기록 사용" --status active --rationale "git에서 검토 가능" --source "사용자 요구"
./pm action add --session S-001 --text "CLI 검증 실행" --status pending --owner "agent"
./pm question add --session S-001 --text "배포 시 설치 경로는 무엇인가?" --status open
./pm decision status D-001 --status superseded --by D-002
./pm action status A-001 --status done
./pm question status Q-001 --status resolved
```

session 종료 시 agent가 작성한 의미 요약을 전달합니다. CLI는 의미를 추측하지 않고 이를 저장한 뒤 close, index update, check를 수행합니다.

```bash
./pm session finish S-001 \
  --one-line "완료 요약" \
  --flow "작업 흐름" \
  --intent "사용자 의도" \
  --next "다음 작업"
```

닫힌 session에는 새 raw/turn/decision/action/question source event를 추가하지 않습니다. 이미 작성된 optional summary section은 해당 `finish` flag를 생략하면 보존됩니다.

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
./pm requirement add --prd P-001 --text "요구사항" --status proposed --session S-001 --turn T-001
./pm requirement status R-001 --status accepted --session S-001 --turn T-001
./pm requirement list --prd P-001
./pm prd index
```

`prd link`는 이미 기록된 관계를 다시 추가하지 않습니다. `prd status`는 metadata와 `prd-spec/<status>/` 위치를 함께 갱신하며, `cancelled`도 삭제 대신 별도 상태 폴더로 보존합니다. Requirement는 PRD 내부 managed block으로 보존되며 상태 변경 이력과 source session/turn을 가집니다. 기존 authored `R-xxx` 표기는 allocator가 예약합니다.

## Recover Context

새 session에서 맥락을 복구할 때는 `./pm context brief`를 실행합니다. 이 출력은 `main.md`, 활성 PRD와 진행 중 requirement, source session의 현재 records, 최근 summary와 structural health를 간결히 집계합니다. 필요한 경우 원문 파일을 추가로 읽습니다.

## Validate

```bash
./pm check
python3 -m unittest discover -s tests -v
```

`check`는 필수 구조, session 이름, 누락 파일, 관리 ID 중복, record status, PRD 상태/경로와 relation, requirement provenance, PRD map 최신성을 검사합니다.

## Known Limits

CLI는 자동 의미 요약, 결정 간 의미 충돌 판단, profile/Slack routing 저장을 하지 않습니다. 사람 또는 agent가 의미 있는 문장을 작성하고 CLI는 구조, provenance와 기계적 반영을 담당합니다.
