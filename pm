#!/usr/bin/env python3
"""Project Master: a small file-based project memory CLI."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path


PROJECT_DIR = ".project-master"
SESSION_RE = re.compile(r"^S-(\d{3,})$")
PRD_RE = re.compile(r"^P-(\d{3,})$")
PRD_FILE_RE = re.compile(r"^(P-\d{3,})(?:-[^/]+)?\.md$")
ID_RE_TEMPLATE = r"\b{prefix}-(\d{{3,}})\b"
PRD_STATUSES = ("backlog", "active", "done", "cancelled")
PRD_FIELD_ORDER = (
    "PRD ID",
    "Title",
    "Status",
    "Owner",
    "Created",
    "Updated",
    "Source Sessions",
    "Source Turns",
    "Related Decisions",
    "Related Actions",
)
PRD_RELATIONS = {
    "session": ("Source Sessions", "S", "session"),
    "turn": ("Source Turns", "T", "turn"),
    "decision": ("Related Decisions", "D", "decision"),
    "action": ("Related Actions", "A", "action"),
}

DIRECTORIES = (
    "index",
    "prd-spec/active",
    "prd-spec/backlog",
    "prd-spec/cancelled",
    "prd-spec/done",
    "sessions",
)

INITIAL_FILES = {
    "main.md": """# Project Master

## Project Overview

TBD. 프로젝트의 목적과 범위를 기록합니다.

## Current Focus

TBD. 현재 가장 중요한 작업을 기록합니다.

## Active PRDs

`prd-spec/active/`를 확인합니다.

## Latest Sessions

`index/session-map.md`를 확인합니다.

## Current Next Actions

`index/next-actions.md`를 확인합니다.

## Open Questions

`index/open-questions.md`를 확인합니다.

## Important Decisions

`index/decisions.md`를 확인합니다.
""",
    "agent.md": """# Project Master Agent Instructions

## Purpose

이 프로젝트는 `.project-master/`를 대화와 구현 사이의 지속 가능한 프로젝트 메모리로 사용합니다.

## When To Use

제품 요구사항, 아키텍처 결정, 구현 계획, 미해결 질문, blocker, session summary, next action, 프로젝트 방향 변경이 대화에 포함되면 이 시스템을 사용합니다.

## Core Rules

1. 프로젝트 수준의 제안 전에 `main.md`와 관련 `index/*.md`를 확인합니다.
2. 가능한 경우 수동 편집보다 `pm` CLI를 사용합니다.
3. 중요한 사용자 의도는 session의 `turns.md`에 기록합니다.
4. 결정은 session에 기록하고 `index/decisions.md`로 반영합니다.
5. next action은 session에 기록하고 `index/next-actions.md`로 반영합니다.
6. session 종료 시 summary를 작성하고 indexes를 갱신합니다.
7. raw conversation과 해석된 summary를 분리합니다.
8. 큰 raw log를 global index에 복제하지 않습니다.
9. 간결하고 신호가 높은 기록을 선호합니다.
10. 대체된 결정은 삭제하지 않고 `superseded` 상태로 남깁니다.
11. 요구사항 대화가 발생하면 관련 PRD를 찾거나 `./pm prd new`로 생성합니다.
12. 중요한 요구사항 변화에는 source session/turn 및 관련 decision/action 링크를 남깁니다.

## Session Workflow

### Start Of Work

1. `.project-master/main.md`를 읽습니다.
2. 관련 index 파일(`decisions.md`, `next-actions.md`, `open-questions.md`, `prd-map.md`)을 읽습니다.
3. `./pm status`를 실행합니다.
4. 필요하면 `./pm session new`를 실행합니다.

### During Work

1. 의미 있는 raw context가 있으면 `./pm raw append`로 추가합니다.
2. 중요한 turn은 `./pm turn add`로 기록합니다.
3. 결정, action, question이 발생하면 해당 명령으로 기록합니다.
4. PRD에 영향을 주는 변화는 `./pm prd link` 및 필요 시 `./pm prd status`로 반영합니다.

### End Of Work

1. session의 `summary.md`에 의미 있는 요약을 작성합니다.
2. `./pm session close S-xxx`를 실행합니다.
3. `./pm index update --session S-xxx`를 실행합니다.
4. `./pm check`를 실행합니다.
""",
    "README.md": """# Project Master

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
""",
    "index/decisions.md": """# Decisions Index

프로젝트 전체의 결정 현재 상태입니다. `pm index update`가 관리 블록을 추가하거나 갱신합니다.
""",
    "index/open-questions.md": """# Open Questions

프로젝트 전체에서 추적 중인 질문입니다. `pm index update`가 관리 블록을 추가하거나 갱신합니다.
""",
    "index/next-actions.md": """# Next Actions

프로젝트 전체의 next action 현재 상태입니다. `pm index update`가 관리 블록을 추가하거나 갱신합니다.
""",
    "index/prd-map.md": """# PRD Map

`pm prd index`가 아래 관리 영역을 PRD metadata에서 다시 생성합니다.

<!-- PM:prd-map:start -->
| PRD | Title | Status | Owner | Updated | Sessions | Decisions | Actions | Path |
|---|---|---|---|---|---|---|---|---|
<!-- PM:prd-map:end -->
""",
    "index/session-map.md": """# Session Map

| Session | Date | One-line Summary | Status | Path |
|---|---|---|---|---|
""",
    "index/changelog.md": """# Changelog

`pm index update`로 global index가 갱신된 기록입니다.
""",
    "index/blockers.md": """# Blockers

현재 진행을 방해하는 사항을 기록합니다.
""",
    "index/glossary.md": """# Glossary

프로젝트 용어와 의미를 기록합니다.
""",
    "prd-spec/template.md": """# PRD: <Title>

<!-- PM:prd:<PRD ID>:start -->
- PRD ID: <PRD ID>
- Title: <Title>
- Status: <Status>
- Owner: <Owner>
- Created: <Created>
- Updated: <Updated>
- Source Sessions:
- Source Turns:
- Related Decisions:
- Related Actions:
<!-- PM:prd:<PRD ID>:end -->

## Problem

해결해야 할 문제를 설명합니다.

## Goals

달성할 결과를 설명합니다.

## Non-goals

이번 범위에 포함하지 않을 사항을 설명합니다.

## Users / Personas

대상 사용자와 상황을 설명합니다.

## Requirements

중요한 요구사항에는 선택적으로 안정적인 ID(`R-001`)와 상태(`proposed`, `accepted`, `deferred`, `removed`, `rolled_back`)를 기록합니다.

## Functional Requirements

구현해야 할 기능을 기록합니다.

## Non-functional Requirements

성능, 보안, 운영성 등 품질 요구사항을 기록합니다.

## UX / Workflow

사용 흐름을 기록합니다.

## Data Model

관련 데이터와 관계를 기록합니다.

## Edge Cases

예외와 경계 상황을 기록합니다.

## Success Criteria

완료와 성공을 판정할 기준을 기록합니다.

## Open Questions

아직 결정하지 않은 질문을 기록합니다.

## Rollout Plan

출시 또는 적용 단계를 기록합니다.

## Requirement Changes

중요한 요구사항 상태 변화와 source session/turn/decision을 append-only로 기록합니다.

## Changelog

변경 내역을 기록합니다.
""",
}


def project_root() -> Path:
    return Path.cwd() / PROJECT_DIR


def now_timestamp() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def today() -> str:
    return datetime.now().astimezone().date().isoformat()


def fail(message: str) -> int:
    print(f"오류: {message}", file=sys.stderr)
    return 1


def require_initialized(root: Path) -> bool:
    if not root.is_dir():
        print("오류: `.project-master/`가 없습니다. 먼저 `./pm init`을 실행하세요.", file=sys.stderr)
        return False
    return True


def write_if_missing(path: Path, content: str) -> bool:
    if path.exists():
        print(f"existing {path.relative_to(Path.cwd())}")
        return False
    path.write_text(content, encoding="utf-8")
    print(f"created  {path.relative_to(Path.cwd())}")
    return True


def command_init(_: argparse.Namespace) -> int:
    root = project_root()
    if root.exists() and not root.is_dir():
        return fail(f"`{PROJECT_DIR}`가 디렉터리가 아닙니다.")
    root.mkdir(exist_ok=True)
    created_dirs = 0
    for relative in DIRECTORIES:
        directory = root / relative
        if directory.exists():
            print(f"existing {directory.relative_to(Path.cwd())}/")
        else:
            directory.mkdir(parents=True)
            created_dirs += 1
            print(f"created  {directory.relative_to(Path.cwd())}/")
    created_files = 0
    for relative, content in INITIAL_FILES.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if write_if_missing(path, content):
            created_files += 1
    print(f"완료: directories {created_dirs}개, files {created_files}개 생성됨.")
    return 0


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as handle:
        handle.write(content)
        temporary = Path(handle.name)
    temporary.chmod((path.stat().st_mode & 0o777) if path.exists() else 0o644)
    temporary.replace(path)


@contextmanager
def project_lock(root: Path):
    lock_path = root / ".pm.lock"
    with lock_path.open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def session_paths(root: Path) -> list[Path]:
    sessions_dir = root / "sessions"
    if not sessions_dir.is_dir():
        return []
    return sorted(
        (path for path in sessions_dir.iterdir() if path.is_dir() and SESSION_RE.match(path.name)),
        key=lambda path: int(SESSION_RE.match(path.name).group(1)),
    )


def find_ids(root: Path, prefix: str) -> list[int]:
    numbers: set[int] = set()
    if not root.exists():
        return []
    if prefix == "S":
        pattern = re.compile(ID_RE_TEMPLATE.format(prefix=re.escape(prefix)))
        for path in session_paths(root):
            match = SESSION_RE.match(path.name)
            if match:
                numbers.add(int(match.group(1)))
        session_map = root / "index" / "session-map.md"
        if session_map.exists():
            numbers.update(int(match) for match in pattern.findall(read_text(session_map)))
        return sorted(numbers)
    if prefix == "P":
        pattern = re.compile(r"<!-- PM:prd:P-(\d{3,}):start -->")
        prd_root = root / "prd-spec"
        if prd_root.exists():
            for path in prd_root.rglob("*.md"):
                match = PRD_FILE_RE.match(path.name)
                if match:
                    numbers.add(int(PRD_RE.match(match.group(1)).group(1)))
                numbers.update(int(match) for match in pattern.findall(read_text(path)))
        return sorted(numbers)
    kinds = {"T": "turn", "D": "decision", "A": "action", "Q": "question"}
    kind = kinds[prefix]
    pattern = re.compile(rf"<!-- PM:{kind}:{re.escape(prefix)}-(\d{{3,}}):start -->")
    for path in root.rglob("*.md"):
        try:
            text = read_text(path)
        except OSError:
            continue
        numbers.update(int(match) for match in pattern.findall(text))
    return sorted(numbers)


def next_id(root: Path, prefix: str) -> str:
    ids = find_ids(root, prefix)
    return f"{prefix}-{(ids[-1] + 1 if ids else 1):03d}"


def validate_session(root: Path, session_id: str) -> Path | None:
    if not SESSION_RE.match(session_id):
        print(f"오류: 잘못된 session ID `{session_id}`입니다.", file=sys.stderr)
        return None
    path = root / "sessions" / session_id
    if not path.is_dir():
        print(f"오류: session `{session_id}`를 찾을 수 없습니다.", file=sys.stderr)
        return None
    return path


def markdown_field(label: str, value: str) -> str:
    clean = value.strip()
    if not clean:
        return f"- {label}:\n"
    if "\n" not in clean:
        return f"- {label}: {clean}\n"
    indented = clean.replace("\n", "\n  ")
    return f"- {label}:\n  {indented}\n"


def extract_one_line_summary(summary_path: Path) -> str:
    if not summary_path.exists():
        return "TBD"
    text = read_text(summary_path)
    match = re.search(r"## One-line Summary\s*\n+(.*)", text)
    if match:
        value = match.group(1).strip()
        if value and not value.startswith("TBD"):
            return value.replace("|", "\\|")
    return "TBD"


def session_map_update(root: Path, session_id: str, status: str) -> None:
    path = root / "index" / "session-map.md"
    if not path.exists():
        path.write_text(INITIAL_FILES["index/session-map.md"], encoding="utf-8")
    text = read_text(path)
    session_dir = root / "sessions" / session_id
    summary = extract_one_line_summary(session_dir / "summary.md")
    row = f"| {session_id} | {today()} | {summary} | {status} | sessions/{session_id}/summary.md |"
    pattern = re.compile(rf"^\| {re.escape(session_id)} \|.*$", re.MULTILINE)
    if pattern.search(text):
        text = pattern.sub(lambda _: row, text, count=1)
    else:
        if not text.endswith("\n"):
            text += "\n"
        text += row + "\n"
    write_text_atomic(path, text)


def session_templates(session_id: str) -> dict[str, str]:
    return {
        "summary.md": f"""# Session {session_id} Summary

- Status: open
- Created: {today()}

## One-line Summary

TBD. session 종료 전에 실제 한 줄 요약으로 교체합니다.

## Overall Flow

TBD.

## User Intent

TBD.

## Key Discussion Points

TBD.

## Decisions Made

TBD.

## Open Questions

TBD.

## Next Actions

TBD.

## Turn Log Context Analysis

`turns.md`를 바탕으로 session 수준의 맥락을 정리합니다.
""",
        "decisions.md": f"""# Decisions - {session_id}

이 session에서 결정된 사항을 기록합니다.
""",
        "raw.md": f"""# Raw Conversation - {session_id}

해석하지 않은 중요한 대화 내용을 append-only로 기록합니다.
""",
        "turns.md": f"""# Turn Log - {session_id}

의미 있는 turn과 상태 변화를 기록합니다.
""",
        "actions.md": f"""# Actions - {session_id}

이 session에서 생성된 next action을 기록합니다.
""",
        "open-questions.md": f"""# Open Questions - {session_id}

이 session에서 열린 질문을 기록합니다.
""",
    }


def command_session_new(_: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        session_id = next_id(root, "S")
        session_dir = root / "sessions" / session_id
        session_dir.mkdir(parents=True)
        for name, content in session_templates(session_id).items():
            (session_dir / name).write_text(content, encoding="utf-8")
        session_map_update(root, session_id, "open")
    print(session_id)
    return 0


def command_session_list(_: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    sessions = session_paths(root)
    if not sessions:
        print("session이 없습니다.")
        return 0
    session_map = read_text(root / "index" / "session-map.md") if (root / "index" / "session-map.md").exists() else ""
    for session_dir in sessions:
        row = re.search(rf"^\| {re.escape(session_dir.name)} \|(.*)$", session_map, re.MULTILINE)
        print(f"{session_dir.name}{' |' + row.group(1) if row else ''}")
    return 0


def command_session_show(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    session_dir = validate_session(root, args.session)
    if not session_dir:
        return 1
    print(read_text(session_dir / "summary.md"))
    print("Files:")
    for name in session_templates(args.session):
        print(f"- {session_dir.relative_to(Path.cwd()) / name}")
    return 0


def mark_summary_closed(summary_path: Path) -> bool:
    text = read_text(summary_path)
    text = text.replace("- Status: open", "- Status: closed", 1)
    has_tbd = bool(re.search(r"## One-line Summary\s*\n+\s*TBD", text))
    if has_tbd and "TODO: 의미 요약을 작성한 뒤" not in text:
        text += "\n> TODO: 의미 요약을 작성한 뒤 `./pm index update --session <ID>`를 다시 실행하여 session map을 갱신합니다.\n"
    summary_path.write_text(text, encoding="utf-8")
    return has_tbd


def command_session_close(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    session_dir = validate_session(root, args.session)
    if not session_dir:
        return 1
    summary_path = session_dir / "summary.md"
    if not summary_path.exists():
        summary_path.write_text(session_templates(args.session)["summary.md"], encoding="utf-8")
    has_tbd = mark_summary_closed(summary_path)
    session_map_update(root, args.session, "closed")
    print(f"{args.session} closed.")
    if has_tbd:
        print("주의: summary의 One-line Summary가 아직 TBD입니다. 의미 요약을 작성하세요.")
    print(f"다음 명령: ./pm index update --session {args.session}")
    return 0


def append_text(path: Path, content: str) -> None:
    with path.open("a", encoding="utf-8") as handle:
        if not content.startswith("\n"):
            handle.write("\n")
        handle.write(content)
        if not content.endswith("\n"):
            handle.write("\n")


def command_raw_append(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    session_dir = validate_session(root, args.session)
    if not session_dir:
        return 1
    entry = f"## {now_timestamp()} - {args.role}\n\n{args.content.strip()}\n"
    append_text(session_dir / "raw.md", entry)
    print(f"{args.session} raw entry 추가됨.")
    return 0


def managed_block(kind: str, item_id: str, body: str) -> str:
    return f"<!-- PM:{kind}:{item_id}:start -->\n{body.rstrip()}\n<!-- PM:{kind}:{item_id}:end -->\n"


def command_turn_add(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        session_dir = validate_session(root, args.session)
        if not session_dir:
            return 1
        item_id = next_id(root, "T")
        body = f"## {item_id}\n\n"
        body += markdown_field("User prompt", args.prompt)
        body += markdown_field("Content", args.content)
        body += markdown_field("User intent", args.intent)
        body += markdown_field("Assistant response summary", args.response)
        body += markdown_field("Resulting state change", args.result)
        append_text(session_dir / "turns.md", managed_block("turn", item_id, body))
    print(item_id)
    return 0


def command_decision_add(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        session_dir = validate_session(root, args.session)
        if not session_dir:
            return 1
        item_id = next_id(root, "D")
        body = f"## {item_id}: {args.title.strip()}\n\n"
        body += markdown_field("Status", args.status)
        body += markdown_field("Source Session", args.session)
        body += markdown_field("Date", today())
        body += markdown_field("Rationale", args.rationale)
        body += markdown_field("Decision", args.title)
        body += markdown_field("Source Detail", args.source)
        body += markdown_field("Supersedes", "")
        body += markdown_field("Superseded by", "")
        append_text(session_dir / "decisions.md", managed_block("decision", item_id, body))
    print(item_id)
    return 0


def command_action_add(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        session_dir = validate_session(root, args.session)
        if not session_dir:
            return 1
        item_id = next_id(root, "A")
        body = f"## {item_id}\n\n"
        body += markdown_field("Status", args.status)
        body += markdown_field("Source Session", args.session)
        body += markdown_field("Owner", args.owner)
        body += markdown_field("Action", args.text)
        body += markdown_field("Created", today())
        body += markdown_field("Updated", today())
        append_text(session_dir / "actions.md", managed_block("action", item_id, body))
    print(item_id)
    return 0


def command_question_add(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        session_dir = validate_session(root, args.session)
        if not session_dir:
            return 1
        item_id = next_id(root, "Q")
        body = f"## {item_id}\n\n"
        body += markdown_field("Status", args.status)
        body += markdown_field("Source Session", args.session)
        body += markdown_field("Question", args.text)
        body += markdown_field("Created", today())
        append_text(session_dir / "open-questions.md", managed_block("question", item_id, body))
    print(item_id)
    return 0


def blocks_from(text: str, kind: str) -> list[tuple[str, str]]:
    pattern = re.compile(
        rf"<!-- PM:{re.escape(kind)}:(?P<id>[A-Z]-\d+):start -->\n"
        rf"(?P<body>.*?)"
        rf"<!-- PM:{re.escape(kind)}:(?P=id):end -->\n?",
        re.DOTALL,
    )
    return [(match.group("id"), match.group(0).rstrip() + "\n") for match in pattern.finditer(text)]


def single_line(value: str) -> str:
    return " ".join(value.strip().split())


def prd_paths(root: Path) -> list[Path]:
    paths: list[Path] = []
    for status in PRD_STATUSES:
        directory = root / "prd-spec" / status
        if directory.is_dir():
            paths.extend(path for path in directory.glob("*.md") if PRD_FILE_RE.match(path.name))
    return sorted(paths, key=lambda path: int(PRD_RE.match(PRD_FILE_RE.match(path.name).group(1)).group(1)))


def parse_prd_fields(body: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for label in PRD_FIELD_ORDER:
        match = re.search(rf"^- {re.escape(label)}:[ \t]*(.*)$", body, re.MULTILINE)
        fields[label] = match.group(1).strip() if match else ""
    return fields


def render_prd_block(prd_id: str, fields: dict[str, str]) -> str:
    body = "".join(markdown_field(label, fields.get(label, "")) for label in PRD_FIELD_ORDER)
    return managed_block("prd", prd_id, body)


def read_prd_metadata(path: Path) -> tuple[str, dict[str, str]] | None:
    blocks = blocks_from(read_text(path), "prd")
    if len(blocks) != 1:
        print(f"오류: PRD metadata block을 하나만 포함해야 합니다: {path}", file=sys.stderr)
        return None
    prd_id, block = blocks[0]
    fields = parse_prd_fields(block)
    return prd_id, fields


def find_prd(root: Path, prd_id: str) -> tuple[Path, dict[str, str]] | None:
    if not PRD_RE.match(prd_id):
        print(f"오류: 잘못된 PRD ID `{prd_id}`입니다.", file=sys.stderr)
        return None
    matches = [path for path in prd_paths(root) if PRD_FILE_RE.match(path.name).group(1) == prd_id]
    if not matches:
        print(f"오류: PRD `{prd_id}`를 찾을 수 없습니다.", file=sys.stderr)
        return None
    if len(matches) > 1:
        print(f"오류: PRD `{prd_id}` 파일이 여러 개입니다.", file=sys.stderr)
        return None
    metadata = read_prd_metadata(matches[0])
    if not metadata or metadata[0] != prd_id:
        print(f"오류: PRD `{prd_id}` metadata ID가 파일명과 일치하지 않습니다.", file=sys.stderr)
        return None
    return matches[0], metadata[1]


def update_prd_metadata(path: Path, prd_id: str, fields: dict[str, str]) -> None:
    text = read_text(path)
    original = blocks_from(text, "prd")[0][1]
    write_text_atomic(path, text.replace(original, render_prd_block(prd_id, fields), 1))


def relation_values(fields: dict[str, str], label: str) -> list[str]:
    return [value.strip() for value in fields.get(label, "").split(",") if value.strip()]


def prd_reference_exists(root: Path, prefix: str, item_id: str) -> bool:
    if prefix == "S":
        return bool(SESSION_RE.match(item_id) and (root / "sessions" / item_id).is_dir())
    kinds = {"T": ("turn", "turns.md"), "D": ("decision", "decisions.md"), "A": ("action", "actions.md")}
    if not re.match(rf"^{prefix}-\d{{3,}}$", item_id):
        return False
    kind, filename = kinds[prefix]
    return any(item_id in marker_ids(session / filename, kind) for session in session_paths(root))


def prd_document(root: Path, prd_id: str, title: str, status: str, owner: str) -> str:
    template_path = root / "prd-spec" / "template.md"
    template = read_text(template_path) if template_path.exists() else INITIAL_FILES["prd-spec/template.md"]
    fields = {
        "PRD ID": prd_id,
        "Title": title,
        "Status": status,
        "Owner": owner,
        "Created": today(),
        "Updated": today(),
        "Source Sessions": "",
        "Source Turns": "",
        "Related Decisions": "",
        "Related Actions": "",
    }
    replacements = {
        "<PRD ID>": prd_id,
        "<Title>": title,
        "<Status>": status,
        "<Owner>": owner,
        "<Created>": today(),
        "<Updated>": today(),
    }
    text = template
    for placeholder, value in replacements.items():
        text = text.replace(placeholder, value)
    blocks = blocks_from(text, "prd")
    if blocks:
        text = text.replace(blocks[0][1], render_prd_block(prd_id, fields), 1)
    else:
        heading_end = text.find("\n")
        insertion = heading_end + 1 if heading_end >= 0 else 0
        text = text[:insertion] + "\n" + render_prd_block(prd_id, fields) + text[insertion:]
    return text


def slugify(title: str) -> str:
    slug = re.sub(r"[^\w]+", "-", title.lower(), flags=re.UNICODE).strip("-_")
    return slug or "prd"


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def render_prd_map_block(root: Path) -> str | None:
    rows: list[str] = []
    for path in prd_paths(root):
        metadata = read_prd_metadata(path)
        if not metadata:
            return None
        prd_id, fields = metadata
        cells = (
            prd_id,
            fields["Title"],
            fields["Status"],
            fields["Owner"],
            fields["Updated"],
            fields["Source Sessions"],
            fields["Related Decisions"],
            fields["Related Actions"],
            str(path.relative_to(root)),
        )
        rows.append("| " + " | ".join(markdown_cell(value) for value in cells) + " |")
    return (
        "<!-- PM:prd-map:start -->\n"
        "| PRD | Title | Status | Owner | Updated | Sessions | Decisions | Actions | Path |\n"
        "|---|---|---|---|---|---|---|---|---|\n"
        + ("\n".join(rows) + "\n" if rows else "")
        + "<!-- PM:prd-map:end -->\n"
    )


def rebuild_prd_index(root: Path) -> bool:
    table = render_prd_map_block(root)
    if table is None:
        return False
    path = root / "index" / "prd-map.md"
    if not path.exists():
        write_text_atomic(path, INITIAL_FILES["index/prd-map.md"])
    text = read_text(path)
    pattern = re.compile(r"<!-- PM:prd-map:start -->\n.*?<!-- PM:prd-map:end -->\n?", re.DOTALL)
    if pattern.search(text):
        write_text_atomic(path, pattern.sub(lambda _: table, text, count=1))
    else:
        if not text.endswith("\n"):
            text += "\n"
        write_text_atomic(path, text + "\n" + table)
    return True


def command_prd_new(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    title = single_line(args.title)
    if not title:
        return fail("PRD title은 비어 있을 수 없습니다.")
    with project_lock(root):
        prd_id = next_id(root, "P")
        filename = f"{prd_id}-{slugify(title)}.md"
        path = root / "prd-spec" / args.status / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        write_text_atomic(path, prd_document(root, prd_id, title, args.status, single_line(args.owner)))
        if not rebuild_prd_index(root):
            return 1
    print(f"{prd_id} {path.relative_to(root)}")
    return 0


def command_prd_list(_: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        if not prd_paths(root):
            print("PRD가 없습니다.")
            return 0
        for path in prd_paths(root):
            metadata = read_prd_metadata(path)
            if not metadata:
                return 1
            prd_id, fields = metadata
            print(f"{prd_id} | {fields['Status']} | {fields['Title']} | {path.relative_to(root)}")
    return 0


def command_prd_show(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        record = find_prd(root, args.prd)
        if not record:
            return 1
        print(read_text(record[0]))
    return 0


def command_prd_status(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        record = find_prd(root, args.prd)
        if not record:
            return 1
        path, fields = record
        destination = root / "prd-spec" / args.status / path.name
        if destination != path and destination.exists():
            return fail(f"대상 PRD 파일이 이미 있습니다: {destination.relative_to(root)}")
        fields["Status"] = args.status
        fields["Updated"] = today()
        update_prd_metadata(path, args.prd, fields)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination != path:
            path.rename(destination)
        if not rebuild_prd_index(root):
            return 1
    print(f"{args.prd} status={args.status} path={destination.relative_to(root)}")
    return 0


def command_prd_link(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        record = find_prd(root, args.prd)
        if not record:
            return 1
        path, fields = record
        relation = next(name for name in PRD_RELATIONS if getattr(args, name) is not None)
        label, prefix, _ = PRD_RELATIONS[relation]
        target = getattr(args, relation)
        if not prd_reference_exists(root, prefix, target):
            return fail(f"존재하지 않는 {relation} relation target `{target}`입니다.")
        values = relation_values(fields, label)
        changed = target not in values
        if changed:
            values.append(target)
            fields[label] = ", ".join(values)
            fields["Updated"] = today()
            update_prd_metadata(path, args.prd, fields)
            if not rebuild_prd_index(root):
                return 1
    print(f"{args.prd} {label}={target} {'linked' if changed else 'unchanged'}")
    return 0


def command_prd_index(_: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        if not rebuild_prd_index(root):
            return 1
    print("PRD map updated.")
    return 0


def upsert_block(index_path: Path, kind: str, item_id: str, block: str) -> str:
    text = read_text(index_path)
    pattern = re.compile(
        rf"<!-- PM:{re.escape(kind)}:{re.escape(item_id)}:start -->\n.*?"
        rf"<!-- PM:{re.escape(kind)}:{re.escape(item_id)}:end -->\n?",
        re.DOTALL,
    )
    if pattern.search(text):
        index_path.write_text(pattern.sub(block, text, count=1), encoding="utf-8")
        return "updated"
    append_text(index_path, block)
    return "added"


def changelog_update(root: Path, session_id: str) -> bool:
    path = root / "index" / "changelog.md"
    marker = f"<!-- PM:index-update:{session_id} -->"
    text = read_text(path)
    if marker in text:
        return False
    entry = f"{marker}\n## {today()} - {session_id}\n\n- global indexes updated from `sessions/{session_id}/`.\n"
    append_text(path, entry)
    return True


def command_index_update(args: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    session_dir = validate_session(root, args.session)
    if not session_dir:
        return 1
    mappings = (
        ("decision", "decisions.md", "index/decisions.md"),
        ("action", "actions.md", "index/next-actions.md"),
        ("question", "open-questions.md", "index/open-questions.md"),
    )
    counts = {"added": 0, "updated": 0}
    for kind, source_name, target_name in mappings:
        source = session_dir / source_name
        target = root / target_name
        if not target.exists():
            target.write_text(INITIAL_FILES[target_name], encoding="utf-8")
        for item_id, block in blocks_from(read_text(source), kind):
            result = upsert_block(target, kind, item_id, block)
            counts[result] += 1
    status = "closed" if "- Status: closed" in read_text(session_dir / "summary.md") else "open"
    session_map_update(root, args.session, status)
    log_added = changelog_update(root, args.session)
    print(f"{args.session}: added {counts['added']}, updated {counts['updated']}, changelog {'added' if log_added else 'unchanged'}.")
    return 0


def required_files() -> set[str]:
    return set(INITIAL_FILES)


def marker_ids(path: Path, kind: str) -> list[str]:
    if not path.exists():
        return []
    return [item_id for item_id, _ in blocks_from(read_text(path), kind)]


def duplicates(values: list[str]) -> list[str]:
    return sorted({value for value in values if values.count(value) > 1})


def collect_check_errors(root: Path) -> list[str]:
    errors: list[str] = []
    for relative in DIRECTORIES:
        if not (root / relative).is_dir():
            errors.append(f"missing directory: {relative}/")
    for relative in sorted(required_files()):
        if not (root / relative).is_file():
            errors.append(f"missing file: {relative}")
    source_ids: dict[str, list[str]] = {"turn": [], "decision": [], "action": [], "question": []}
    for path in (root / "sessions").iterdir() if (root / "sessions").is_dir() else []:
        if not path.is_dir():
            continue
        if not SESSION_RE.match(path.name):
            errors.append(f"invalid session directory: sessions/{path.name}/")
            continue
        for required in session_templates(path.name):
            if not (path / required).is_file():
                errors.append(f"missing session file: sessions/{path.name}/{required}")
        for kind, filename in (
            ("turn", "turns.md"),
            ("decision", "decisions.md"),
            ("action", "actions.md"),
            ("question", "open-questions.md"),
        ):
            source_ids[kind].extend(marker_ids(path / filename, kind))
    for kind, ids in source_ids.items():
        for item_id in duplicates(ids):
            errors.append(f"duplicate {kind} ID in sessions: {item_id}")
    for kind, target in (
        ("decision", "index/decisions.md"),
        ("action", "index/next-actions.md"),
        ("question", "index/open-questions.md"),
    ):
        for item_id in duplicates(marker_ids(root / target, kind)):
            errors.append(f"duplicate {kind} ID in index: {item_id}")
    session_map = root / "index" / "session-map.md"
    if session_map.exists():
        rows = re.findall(r"^\| (S-\d+) \|", read_text(session_map), re.MULTILINE)
        for session_id in duplicates(rows):
            errors.append(f"duplicate session map row: {session_id}")
    session_ids = {path.name for path in session_paths(root)}
    valid_targets = {
        "Source Sessions": session_ids,
        "Source Turns": set(source_ids["turn"]),
        "Related Decisions": set(source_ids["decision"]),
        "Related Actions": set(source_ids["action"]),
    }
    prd_ids: list[str] = []
    known_prd_paths: set[Path] = set()
    for status in PRD_STATUSES:
        directory = root / "prd-spec" / status
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            known_prd_paths.add(path)
            filename_match = PRD_FILE_RE.match(path.name)
            if not filename_match:
                errors.append(f"invalid PRD filename: prd-spec/{status}/{path.name}")
                continue
            filename_id = filename_match.group(1)
            blocks = blocks_from(read_text(path), "prd")
            if len(blocks) != 1:
                errors.append(f"invalid PRD metadata block: prd-spec/{status}/{path.name}")
                continue
            marker_id, block = blocks[0]
            prd_ids.append(marker_id)
            fields = parse_prd_fields(block)
            missing_fields = [
                label for label in PRD_FIELD_ORDER
                if not re.search(rf"^- {re.escape(label)}:", block, re.MULTILINE)
            ]
            if missing_fields:
                errors.append(f"missing PRD metadata field in {marker_id}: {', '.join(missing_fields)}")
            if marker_id != filename_id or fields["PRD ID"] != filename_id:
                errors.append(f"PRD ID mismatch: prd-spec/{status}/{path.name}")
            if fields["Status"] not in PRD_STATUSES:
                errors.append(f"invalid PRD status in {marker_id}: {fields['Status']}")
            elif fields["Status"] != status:
                errors.append(f"PRD status/path mismatch: {marker_id} is {fields['Status']} in {status}/")
            for label, targets in valid_targets.items():
                values = relation_values(fields, label)
                for value in duplicates(values):
                    errors.append(f"duplicate PRD relation in {marker_id}: {label} {value}")
                for value in values:
                    if value not in targets:
                        errors.append(f"invalid PRD relation in {marker_id}: {label} {value}")
    prd_root = root / "prd-spec"
    if prd_root.is_dir():
        template = prd_root / "template.md"
        for path in sorted(prd_root.rglob("*.md")):
            if path == template or path in known_prd_paths:
                continue
            text = read_text(path)
            if PRD_FILE_RE.match(path.name) or "<!-- PM:prd:" in text:
                errors.append(f"invalid PRD location: {path.relative_to(root)}")
    for prd_id in duplicates(prd_ids):
        errors.append(f"duplicate PRD ID: {prd_id}")
    prd_map = root / "index" / "prd-map.md"
    if prd_map.exists():
        map_text = read_text(prd_map)
        rows = re.findall(r"^\| (P-\d+) \|", map_text, re.MULTILINE)
        for prd_id in duplicates(rows):
            errors.append(f"duplicate PRD map row: {prd_id}")
        map_pattern = re.compile(r"<!-- PM:prd-map:start -->\n.*?<!-- PM:prd-map:end -->\n?", re.DOTALL)
        map_blocks = map_pattern.findall(map_text)
        map_is_managed = "<!-- PM:prd-map:start -->" in map_text or bool(prd_paths(root))
        if map_is_managed and len(map_blocks) != 1:
            errors.append("invalid PRD map managed block count")
        elif map_is_managed:
            expected_map = render_prd_map_block(root)
            if expected_map is not None and map_blocks[0] != expected_map:
                errors.append("stale PRD map managed block")
    return errors


def command_check(_: argparse.Namespace) -> int:
    root = project_root()
    if not require_initialized(root):
        return 1
    with project_lock(root):
        errors = collect_check_errors(root)
    if errors:
        print("Project Master check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Project Master check passed.")
    return 0


def command_status(_: argparse.Namespace) -> int:
    root = project_root()
    print(f"initialized: {'yes' if root.is_dir() else 'no'}")
    if not root.is_dir():
        return 0
    with project_lock(root):
        sessions = session_paths(root)
        latest = sessions[-1].name if sessions else "none"
        missing = collect_check_errors(root)
        decisions_path = root / "index" / "decisions.md"
        actions_path = root / "index" / "next-actions.md"
        active = len(re.findall(r"^- Status: active$", read_text(decisions_path), re.MULTILINE)) if decisions_path.exists() else 0
        pending = len(re.findall(r"^- Status: pending$", read_text(actions_path), re.MULTILINE)) if actions_path.exists() else 0
        print(f"latest session: {latest}")
        print(f"sessions: {len(sessions)}")
        print(f"active decisions: {active}")
        print(f"pending actions: {pending}")
        print(f"PRDs: {len(prd_paths(root))}")
        if missing:
            print("structural issues:")
            for message in missing:
                print(f"- {message}")
        else:
            print("structural issues: none")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="pm", description="파일 기반 Project Master CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init = subparsers.add_parser("init", help="Project Master 구조 초기화")
    init.set_defaults(func=command_init)
    status = subparsers.add_parser("status", help="구조와 현재 상태 확인")
    status.set_defaults(func=command_status)
    check = subparsers.add_parser("check", help="구조 검증")
    check.set_defaults(func=command_check)

    session = subparsers.add_parser("session", help="session 관리")
    session_sub = session.add_subparsers(dest="session_command", required=True)
    session_new = session_sub.add_parser("new", help="새 session 생성")
    session_new.set_defaults(func=command_session_new)
    session_list = session_sub.add_parser("list", help="session 목록")
    session_list.set_defaults(func=command_session_list)
    session_show = session_sub.add_parser("show", help="session summary 표시")
    session_show.add_argument("session")
    session_show.set_defaults(func=command_session_show)
    session_close = session_sub.add_parser("close", help="session 종료")
    session_close.add_argument("session")
    session_close.set_defaults(func=command_session_close)

    raw = subparsers.add_parser("raw", help="raw conversation 관리")
    raw_sub = raw.add_subparsers(dest="raw_command", required=True)
    raw_append = raw_sub.add_parser("append", help="raw 메시지 추가")
    raw_append.add_argument("--session", required=True)
    raw_append.add_argument("--role", required=True)
    raw_append.add_argument("--content", required=True)
    raw_append.set_defaults(func=command_raw_append)

    turn = subparsers.add_parser("turn", help="turn log 관리")
    turn_sub = turn.add_subparsers(dest="turn_command", required=True)
    turn_add = turn_sub.add_parser("add", help="turn 추가")
    turn_add.add_argument("--session", required=True)
    turn_add.add_argument("--prompt", required=True)
    turn_add.add_argument("--content", required=True)
    turn_add.add_argument("--intent", required=True)
    turn_add.add_argument("--response", required=True)
    turn_add.add_argument("--result", required=True)
    turn_add.set_defaults(func=command_turn_add)

    decision = subparsers.add_parser("decision", help="decision 관리")
    decision_sub = decision.add_subparsers(dest="decision_command", required=True)
    decision_add = decision_sub.add_parser("add", help="decision 추가")
    decision_add.add_argument("--session", required=True)
    decision_add.add_argument("--title", required=True)
    decision_add.add_argument("--status", default="active")
    decision_add.add_argument("--rationale", required=True)
    decision_add.add_argument("--source", required=True)
    decision_add.set_defaults(func=command_decision_add)

    action = subparsers.add_parser("action", help="next action 관리")
    action_sub = action.add_subparsers(dest="action_command", required=True)
    action_add = action_sub.add_parser("add", help="next action 추가")
    action_add.add_argument("--session", required=True)
    action_add.add_argument("--text", required=True)
    action_add.add_argument("--status", default="pending")
    action_add.add_argument("--owner", required=True)
    action_add.set_defaults(func=command_action_add)

    question = subparsers.add_parser("question", help="open question 관리")
    question_sub = question.add_subparsers(dest="question_command", required=True)
    question_add = question_sub.add_parser("add", help="open question 추가")
    question_add.add_argument("--session", required=True)
    question_add.add_argument("--text", required=True)
    question_add.add_argument("--status", default="open")
    question_add.set_defaults(func=command_question_add)

    prd = subparsers.add_parser("prd", help="PRD 관리")
    prd_sub = prd.add_subparsers(dest="prd_command", required=True)
    prd_new = prd_sub.add_parser("new", help="새 PRD 생성")
    prd_new.add_argument("--title", required=True)
    prd_new.add_argument("--status", choices=PRD_STATUSES, default="backlog")
    prd_new.add_argument("--owner", default="")
    prd_new.set_defaults(func=command_prd_new)
    prd_list = prd_sub.add_parser("list", help="PRD 목록")
    prd_list.set_defaults(func=command_prd_list)
    prd_show = prd_sub.add_parser("show", help="PRD 문서 표시")
    prd_show.add_argument("prd")
    prd_show.set_defaults(func=command_prd_show)
    prd_status = prd_sub.add_parser("status", help="PRD 상태 및 폴더 이동")
    prd_status.add_argument("prd")
    prd_status.add_argument("--status", choices=PRD_STATUSES, required=True)
    prd_status.set_defaults(func=command_prd_status)
    prd_link = prd_sub.add_parser("link", help="PRD relation 추가")
    prd_link.add_argument("prd")
    prd_link_group = prd_link.add_mutually_exclusive_group(required=True)
    prd_link_group.add_argument("--session")
    prd_link_group.add_argument("--turn")
    prd_link_group.add_argument("--decision")
    prd_link_group.add_argument("--action")
    prd_link.set_defaults(func=command_prd_link)
    prd_index = prd_sub.add_parser("index", help="PRD map 재생성")
    prd_index.set_defaults(func=command_prd_index)

    index = subparsers.add_parser("index", help="global index 관리")
    index_sub = index.add_subparsers(dest="index_command", required=True)
    index_update = index_sub.add_parser("update", help="session 기록을 index로 반영")
    index_update.add_argument("--session", required=True)
    index_update.set_defaults(func=command_index_update)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
