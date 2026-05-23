# Project Master

Project Master는 agent 작업 과정에서 생기는 session, 결정, next action, 질문,
PRD 및 requirement 상태를 Markdown으로 보존하는 파일 기반 프로젝트 메모리
CLI입니다.
`.project-master/`가 기록의 source of truth이고, `./pm`이 구조 생성과 안전한
갱신, 검증을 담당합니다.

## Quick Start

이 저장소를 clone한 직후에는 초기화 없이 현재 기록을 검증할 수 있습니다.

```bash
./pm check
./pm status
./pm context brief
```

다른 프로젝트에 빈 Project Master 구조를 만들 때는 해당 프로젝트 루트에
`pm`을 놓고 초기화합니다.

```bash
./pm init
./pm check
```

`init`은 누락된 디렉터리와 파일만 만들며 기존 기록을 덮어쓰지 않습니다.

## Data Layout

```text
.project-master/
├── main.md              # 프로젝트 개요와 현재 초점
├── agent.md             # agent가 따라야 할 기록 workflow
├── index/               # 프로젝트 전역 current-state index
├── sessions/S-xxx/      # 대화와 작업의 source record
└── prd-spec/            # backlog, active, done, cancelled PRD
```

PRD status 디렉터리는 비어 있을 때도 clone 후 유지되어야 하므로 `.gitkeep`을
추적합니다. `./pm check`는 필수 구조, ID 중복, PRD/requirement relation 및
map 정합성을 확인합니다. `./pm context brief`는 agent가 시작 시 읽을 간결한
현재 문맥과 진행 중 requirement를 저장된 기록에서 구성합니다.

## Session Workflow

```bash
./pm context brief
./pm session new
./pm turn add --session S-001 --prompt "요청" --content "범위" --intent "의도" --response "응답" --result "결과"
./pm decision add --session S-001 --title "결정" --rationale "이유" --source "근거"
./pm action add --session S-001 --text "다음 작업" --owner "agent"
./pm question add --session S-001 --text "미해결 질문"
./pm session finish S-001 --one-line "완료 요약" --flow "작업 흐름" --intent "사용자 의도" --next "다음 작업"
```

`session finish`는 agent가 제공한 의미 요약을
`.project-master/sessions/S-xxx/summary.md`에 기록한 뒤 session close,
index update, structural check를 완료합니다. 저수준 `session close`와
`index update` 명령도 수동 복구를 위해 유지됩니다. 닫힌 session에는 새
raw/turn/decision/action/question source event를 추가할 수 없습니다.
자세한 운영 절차는 `.project-master/README.md`와 `.project-master/agent.md`를
참조합니다.

## PRD Workflow

```bash
./pm prd new --title "요구사항 이름" --status backlog --owner "owner"
./pm prd link P-001 --session S-001
./pm prd link P-001 --decision D-001
./pm prd status P-001 --status active
./pm requirement add --prd P-001 --text "요구사항" --status proposed --session S-001 --turn T-001
./pm requirement status R-001 --status accepted --session S-001 --turn T-001
./pm requirement list --prd P-001
./pm prd index
./pm check
```

PRD는 제품 요구사항의 상태와 관계를, session은 시간 순 작업 기록을
담당합니다. managed requirement는 project-global `R-xxx` ID와 source
session/turn을 포함한 상태 이력을 PRD 안에 보존합니다. 기존 authored
`R-xxx` 표기는 새 ID 발급에서 예약되어 충돌하지 않습니다.

현재 상태를 변경할 때는 source record와 global index를 함께 갱신하는 상태
명령을 사용합니다.

```bash
./pm decision status D-001 --status superseded --by D-002
./pm action status A-001 --status done
./pm question status Q-001 --status resolved
```

## Concurrency

`session` lifecycle, raw/turn/decision/action/question 기록, PRD/requirement
변경과 index 반영 명령은 프로젝트 lock 및 atomic replacement를 사용합니다.
여러 agent/process가 같은 프로젝트에 기록할 때 ID 발급과 관리 파일 갱신이
충돌하지 않도록 직렬화합니다.

## Test

```bash
python3 -m unittest discover -s tests -v
```
