# Handoff: PRD-Centered Project Master Improvement

- Status: ready_for_implementation
- Created: 2026-05-23
- Intended Reader: 후속 구현 session의 agent 또는 maintainer
- Scope: Project Master MVP의 PRD 추적 능력 개선
- Priority: high

## Purpose

현재 Project Master는 session 기록, decision/action/question 승격, 구조 검증이 가능한 작동하는 MVP이다. 다음 단계의 핵심은 이 기반을 유지하면서 PRD를 단순 문서 목록이 아닌 **요구사항의 형성, 변경, 실행 상태를 연결하는 1급 객체**로 승격하는 것이다.

이 문서는 외부 비판을 그대로 옮긴 것이 아니라, 현재 코드와 문서를 검토한 결과에 기반한 구현 인수인계다.

## Current Assessment

### What Already Works

- `./pm init`은 `.project-master/`의 필수 구조와 template을 누락분만 생성한다.
- `./pm session new|list|show|close`로 session lifecycle을 관리할 수 있다.
- `raw`, `turn`, `decision`, `action`, `question` 기록 명령이 존재한다.
- `./pm index update --session S-xxx`는 decision/action/question을 global index에 멱등적으로 반영한다.
- 관리 블록 marker를 사용해 수동 Markdown과 CLI 관리 내용을 공존시킨다.
- ID 할당은 관리 블록을 기준으로 하므로 raw 본문이나 문서 예시의 우연한 ID 문자열에 영향을 받지 않는다.
- `./pm check`와 `tests/test_pm.py`가 핵심 구조와 index update 멱등성을 검증한다.

### Where The System Is Weak

현재 PRD 지원은 문서 scaffold 수준이다.

- `.project-master/prd-spec/template.md`에는 `Related Sessions`, `Related Decisions`만 있으며 action, source turn, requirement-level 상태 변화가 없다.
- `.project-master/index/prd-map.md`는 수동으로 유지해야 하는 단순 표다.
- CLI에는 `prd` command가 없다.
- `index update`는 PRD와 관련된 관계나 상태를 반영하지 않는다.
- `check`는 PRD 파일, PRD ID, PRD가 참조하는 session/decision/action/turn의 무결성을 확인하지 않는다.
- `README.md`는 PRD lifecycle을 안내하지만 실행 가능한 workflow로 만들지 못한다.

이 때문에 지금 시스템은 “session에서 무슨 일이 있었는가”에는 강하지만, “요구사항이 어디서 발생했고 어떤 결정과 실행 결과를 거쳐 현재 상태가 되었는가”에는 약하다.

## Guiding Judgment

### Primary Direction

다음 iteration에서는 PRD를 Project Master의 중심 연결점으로 만든다.

PRD는 아래 관계를 표현할 수 있어야 한다.

- 요구사항이 처음 발견되거나 승인된 `session`
- 의미 있는 변경을 일으킨 `turn`
- 요구사항을 확정, 제한, 대체한 `decision`
- 구현 또는 후속 작업을 나타내는 `action`
- 요구사항 자체의 현재 상태와 변경 이력

### Keep The Existing Session Model

기존 session 모델을 없애거나 PRD 아래로 억지로 종속시키지 않는다.

- `sessions/S-xxx/*`는 대화와 작업의 source record로 유지한다.
- `prd-spec/*`는 제품 요구사항과 변경 상태의 source of truth가 된다.
- `index/*`는 두 종류의 기록에서 추출한 프로젝트 현재 상태를 보여 준다.

즉 session은 시간 순 기록이고, PRD는 제품 의미의 축이다. 둘은 경쟁 관계가 아니라 링크 관계다.

### Raw Data Decision

`raw.md`가 Markdown이라는 이유만으로 즉시 교체하지 않는다.

현재 CLI는 raw를 자동 parsing하거나 자동 요약하지 않으며, 구조적으로 처리되는 ID와 index entry는 관리 블록으로 보호된다. 사람이 읽고 검토하기 쉬운 `raw.md`는 MVP 목적에 맞는다.

향후 tool trace import, conversation replay, 자동 summary draft가 실제 요구가 될 때 선택적으로 `raw.jsonl` 또는 event log sidecar를 추가한다. 이 작업은 PRD 중심화와 분리된 후속 범위로 유지한다.

## Target Data Model

### PRD Identity

모든 CLI 관리 PRD에 안정적인 global ID를 부여한다.

```text
P-001
P-002
P-003
```

파일명에는 사람이 읽기 좋은 slug를 포함할 수 있다.

```text
prd-spec/backlog/P-001-project-master-prd-links.md
```

### PRD Status

최소 상태값:

```text
backlog
active
done
cancelled
```

폴더(`backlog/`, `active/`, `done/`)와 front matter 성격의 Markdown metadata가 어긋나지 않도록 CLI가 상태 변경과 이동을 담당한다. `cancelled`를 별도 폴더로 둘지는 구현 시 결정하되, 파일 삭제로 표현하지 않는다.

### Requirement Identity And Status

PRD 내부의 중요한 요구사항에는 선택적으로 안정적인 ID를 부여한다.

```text
R-001
R-002
```

요구사항 상태값:

```text
proposed
accepted
deferred
removed
rolled_back
```

모든 문장에 requirement ID를 강제할 필요는 없다. 결정, 일정, 구현에 영향을 주는 핵심 요구사항부터 적용한다.

### Relations

PRD 수준에서 지원할 relation:

```md
- Source Sessions: S-001
- Source Turns: T-003
- Related Decisions: D-002
- Related Actions: A-004
```

requirement 변경 기록 수준에서 지원할 relation:

```md
## Requirement Changes

<!-- PM:requirement-change:RC-001:start -->
### RC-001: R-001 accepted

- Requirement: R-001
- Status: accepted
- Source Session: S-001
- Source Turn: T-003
- Related Decision: D-002
- Date: YYYY-MM-DD
- Rationale: ...
<!-- PM:requirement-change:RC-001:end -->
```

`RC-xxx` ID는 구현 부담이 크다면 첫 단계에서는 생략 가능하다. 그러나 변경 이력은 append-friendly하게 유지해야 한다.

## Recommended CLI Surface

### Required For Next Iteration

```bash
./pm prd new --title "..." --status backlog --owner "..."
./pm prd list
./pm prd show P-001
./pm prd status P-001 --status active
./pm prd link P-001 --session S-001
./pm prd link P-001 --decision D-001
./pm prd link P-001 --action A-001
./pm prd link P-001 --turn T-001
./pm prd index
./pm check
```

명령 형태는 기존 argparse 구성과 충돌하지 않는 범위에서 조정할 수 있다. 중요한 것은 사람이 문서 여러 곳을 직접 편집하지 않고 관계를 안전하게 기록할 수 있는 것이다.

### Valuable Follow-Up Commands

```bash
./pm requirement add --prd P-001 --text "..." --status proposed
./pm requirement status R-001 --status accepted --session S-001 --turn T-001 --decision D-001 --rationale "..."
```

이 명령은 PRD identity, link, status, check가 안정된 후 구현해도 된다.

## Proposed File Changes

### Update Existing Files

- `pm`
  - `P-xxx` ID 할당 로직 추가
  - PRD discovery, creation, status transition, relation link, map update 구현
  - `check`에 PRD 파일 구조 및 reference integrity 검사 추가
  - 필요 시 managed block kind로 `prd` 또는 `prd-link` 추가

- `.project-master/prd-spec/template.md`
  - `PRD ID`, `Source Sessions`, `Source Turns`, `Related Decisions`, `Related Actions` 필드 추가
  - requirements의 상태 표현 방식 추가
  - append-friendly change history 구조 추가

- `.project-master/index/prd-map.md`
  - 최소한 `PRD`, `Title`, `Status`, `Owner`, `Updated`, `Sessions`, `Decisions`, `Actions`, `Path`를 표시
  - CLI 관리 영역 또는 deterministic table rebuild 방식 중 하나를 선택

- `.project-master/README.md`
  - 사람이 직접 파일 이동/표 갱신을 하는 절차 대신 신규 CLI workflow 설명
  - PRD와 session의 역할 차이 명시

- `.project-master/agent.md`
  - 요구사항 대화가 발생하면 관련 PRD를 식별하거나 생성하도록 규칙 추가
  - 중요한 변경 시 source session/turn/decision/action 링크를 남기도록 규칙 추가

- `tests/test_pm.py`
  - PRD lifecycle, relation link, status folder transition, map idempotency, invalid reference 검증 추가

### Avoid For This Iteration

- database 도입
- vector search 또는 semantic retrieval
- 자동 summary 생성
- raw Markdown 제거
- 대화 export/import pipeline 구현
- 전체 문서를 JSON 중심 구조로 변환

## Implementation Order

### Phase 1: PRD Core

1. PRD ID와 file naming 규칙을 정한다.
2. `pm prd new`, `pm prd list`, `pm prd show`를 구현한다.
3. 생성된 PRD가 `prd-map.md`에 멱등적으로 나타나도록 한다.
4. template과 README를 CLI 동작에 맞게 갱신한다.

### Phase 2: Status And Links

1. `pm prd status`로 상태와 폴더 이동을 동기화한다.
2. `pm prd link`로 `S`, `T`, `D`, `A` 관계를 추가한다.
3. 중복 link 추가가 문서를 중복 오염시키지 않도록 한다.
4. agent workflow에 PRD link 기록 조건을 추가한다.

### Phase 3: Integrity And Requirements

1. `pm check`에서 존재하지 않는 referenced ID를 검출한다.
2. PRD status와 디렉터리 불일치를 검출한다.
3. 필요성이 확인되면 requirement ID와 status history 명령을 추가한다.

### Phase 4: Structured Raw Events, Only If Needed

자동 import 또는 replay 요구가 구체화된 경우에만 설계한다.

1. `raw.md`를 사람이 읽는 view로 계속 유지한다.
2. `raw.jsonl` sidecar의 event schema를 정의한다.
3. message/tool call/tool result/model metadata를 event 단위로 기록한다.
4. 기존 session과 backward compatibility를 유지한다.

## Acceptance Criteria

다음 iteration은 최소한 아래를 만족해야 한다.

- `pm prd new`가 `P-001`부터 안정적인 ID를 부여하고 PRD 문서를 생성한다.
- `pm prd new` 또는 별도 index command를 반복 실행해도 `prd-map.md`에 중복 row가 생기지 않는다.
- `pm prd status P-001 --status active`가 metadata와 폴더 위치를 일관되게 변경한다.
- `pm prd link`가 session, turn, decision, action을 PRD와 중복 없이 연결한다.
- `pm check`가 잘못된 PRD ID, 존재하지 않는 relation target, status/path 불일치를 non-zero exit code로 보고한다.
- 기존 `session`, `decision`, `action`, `question`, `index update` 동작과 기존 테스트가 회귀하지 않는다.
- README와 agent instruction이 실제 CLI workflow와 일치한다.

## Suggested Test Cases

```text
init -> prd new -> prd list/show -> check passes
prd new twice -> P-001/P-002 assigned
prd index twice -> a single map row per PRD
session new + turn/decision/action add -> prd link each relation -> no duplicate link after retry
prd status backlog -> active -> correct file relocation and map status
link unknown D-999 or S-999 -> command rejects or check fails deterministically
existing manually authored PRD prose -> CLI updates managed metadata without erasing prose
existing MVP session tests -> still pass
```

## Design Cautions

- PRD 문서 전체를 regex로 다시 쓰는 방식은 사람이 작성한 본문을 훼손하기 쉽다. 기존 managed block 접근을 확장하거나, CLI 관리 metadata block을 명확히 분리한다.
- relation을 단순 텍스트로만 남기면 무결성 검사가 약해진다. CLI가 생성한 relation은 파싱 가능한 marker 또는 제한된 metadata 형식을 사용한다.
- 요구사항별 turn linking을 모든 변화에 강제하면 기록 부담이 커진다. 의미 있는 변경에만 기록하는 규칙을 문서화한다.
- `main.md`는 상세 정보 저장소로 키우지 않는다. dashboard의 간결함은 유지하고, PRD 상세 연결은 PRD 문서와 map이 담당한다.
- PRD가 중심이 되더라도 session 원본 기록과 global current-state index의 역할을 섞지 않는다.

## Open Decisions For Implementer

- `cancelled` PRD를 `done/` 안에서 상태로만 표현할지, 별도 디렉터리를 추가할지.
- PRD metadata를 bullet list + managed block으로 유지할지, YAML front matter를 도입할지.
- `prd-map.md`를 행 단위 upsert할지, PRD 파일들에서 deterministic rebuild할지.
- requirement-level ID와 변경 이력을 이번 iteration에 포함할지, PRD link 기반을 먼저 안정화한 후 추가할지.

권장 기본값은 최소 변화다: 현재 Markdown/managed block 스타일을 유지하고, `P-xxx` 및 relation/status 지원을 먼저 구현한다.

## Starting Instructions For Next Session

1. `./pm status`와 `./pm check`를 실행해 baseline을 확인한다.
2. `pm`, `tests/test_pm.py`, `.project-master/prd-spec/template.md`, `.project-master/index/prd-map.md`, `.project-master/README.md`, `.project-master/agent.md`를 읽는다.
3. 먼저 PRD core와 test를 구현하고, raw event 구조화는 범위 밖으로 둔다.
4. 기존 session/index lifecycle 테스트를 유지하면서 PRD 테스트를 추가한다.
5. 완료 시 변경된 명령, data model, migration 또는 backward compatibility 제한을 session summary에 남긴다.
