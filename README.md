# Project Master

Project Master는 agent 작업 과정에서 생기는 session, 결정, next action, 질문,
PRD 상태를 Markdown으로 보존하는 파일 기반 프로젝트 메모리 CLI입니다.
`.project-master/`가 기록의 source of truth이고, `./pm`이 구조 생성과 안전한
갱신, 검증을 담당합니다.

## Quick Start

이 저장소를 clone한 직후에는 초기화 없이 현재 기록을 검증할 수 있습니다.

```bash
./pm check
./pm status
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
추적합니다. `./pm check`는 필수 구조, ID 중복, PRD relation 및 map 정합성을
확인합니다.

## Session Workflow

```bash
./pm session new
./pm turn add --session S-001 --prompt "요청" --content "범위" --intent "의도" --response "응답" --result "결과"
./pm decision add --session S-001 --title "결정" --rationale "이유" --source "근거"
./pm action add --session S-001 --text "다음 작업" --owner "agent"
./pm question add --session S-001 --text "미해결 질문"
./pm session close S-001
./pm index update --session S-001
./pm check
```

의미 있는 종료 요약은 `.project-master/sessions/S-xxx/summary.md`에 작성합니다.
자세한 운영 절차는 `.project-master/README.md`와 `.project-master/agent.md`를
참조합니다.

## PRD Workflow

```bash
./pm prd new --title "요구사항 이름" --status backlog --owner "owner"
./pm prd link P-001 --session S-001
./pm prd link P-001 --decision D-001
./pm prd status P-001 --status active
./pm prd index
./pm check
```

PRD는 제품 요구사항의 상태와 관계를, session은 시간 순 작업 기록을
담당합니다.

## Concurrency

`session new`, `turn/decision/action/question add`, PRD 변경 명령은 프로젝트
lock을 사용합니다. 여러 agent/process가 같은 프로젝트에 이 기록을 추가할
때 ID 발급과 관련 파일 갱신이 충돌하지 않도록 직렬화합니다.

## Test

```bash
python3 -m unittest discover -s tests -v
```
