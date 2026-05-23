from concurrent.futures import ThreadPoolExecutor
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PM = Path(__file__).resolve().parents[1] / "pm"


class ProjectMasterCliTest(unittest.TestCase):
    def run_pm(self, cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [sys.executable, str(PM), *args],
            cwd=cwd,
            text=True,
            capture_output=True,
        )
        if result.returncode:
            self.fail(
                f"pm {' '.join(args)} failed ({result.returncode})\n"
                f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
            )
        return result

    def run_pm_failure(self, cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [sys.executable, str(PM), *args],
            cwd=cwd,
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        return result

    def test_session_lifecycle_and_idempotent_index_update(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "init")
            agent_instructions = (root / ".project-master" / "agent.md").read_text(encoding="utf-8")
            template = (root / ".project-master" / "prd-spec" / "template.md").read_text(encoding="utf-8")
            self.assertIn("./pm context brief", agent_instructions)
            self.assertIn("./pm session finish", agent_instructions)
            self.assertIn("R-xxx", template)
            result = self.run_pm(root, "session", "new")
            self.assertIn("S-001", result.stdout)

            self.run_pm(
                root,
                "raw",
                "append",
                "--session",
                "S-001",
                "--role",
                "user",
                "--content",
                "목표: 예시 ID D-999는 할당에 영향을 주지 않음",
            )
            self.run_pm(
                root,
                "turn",
                "add",
                "--session",
                "S-001",
                "--prompt",
                "구현",
                "--content",
                "MVP",
                "--intent",
                "기억 시스템 추가",
                "--response",
                "CLI 생성",
                "--result",
                "files changed",
            )
            self.run_pm(
                root,
                "decision",
                "add",
                "--session",
                "S-001",
                "--title",
                "Markdown source of truth",
                "--status",
                "active",
                "--rationale",
                "검토 가능",
                "--source",
                "goal",
            )
            self.run_pm(
                root,
                "action",
                "add",
                "--session",
                "S-001",
                "--text",
                "검증",
                "--status",
                "pending",
                "--owner",
                "agent",
            )
            self.run_pm(
                root,
                "question",
                "add",
                "--session",
                "S-001",
                "--text",
                "설치 방식?",
                "--status",
                "open",
            )
            self.run_pm(root, "session", "close", "S-001")
            self.run_pm(root, "index", "update", "--session", "S-001")
            self.run_pm(root, "index", "update", "--session", "S-001")
            self.run_pm(root, "check")

            project = root / ".project-master"
            decisions = (project / "index" / "decisions.md").read_text(encoding="utf-8")
            actions = (project / "index" / "next-actions.md").read_text(encoding="utf-8")
            questions = (project / "index" / "open-questions.md").read_text(encoding="utf-8")
            changelog = (project / "index" / "changelog.md").read_text(encoding="utf-8")
            session_map = (project / "index" / "session-map.md").read_text(encoding="utf-8")
            self.assertEqual(decisions.count("<!-- PM:decision:D-001:start -->"), 1)
            self.assertEqual(actions.count("<!-- PM:action:A-001:start -->"), 1)
            self.assertEqual(questions.count("<!-- PM:question:Q-001:start -->"), 1)
            self.assertEqual(changelog.count("<!-- PM:index-update:S-001 -->"), 1)
            self.assertEqual(session_map.count("| S-001 |"), 1)
            self.assertIn("| closed |", session_map)

    def test_init_preserves_existing_content_and_check_reports_missing_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            main = root / ".project-master" / "main.md"
            main.write_text("# custom content\n", encoding="utf-8")
            self.run_pm(root, "init")
            self.assertEqual(main.read_text(encoding="utf-8"), "# custom content\n")

            (root / ".project-master" / "index" / "decisions.md").unlink()
            result = subprocess.run(
                [sys.executable, str(PM), "check"],
                cwd=root,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing file: index/decisions.md", result.stderr)

    def test_checkout_retains_required_empty_prd_status_directories(self) -> None:
        repository_root = PM.parent
        for status in ("active", "backlog", "cancelled"):
            keep = repository_root / ".project-master" / "prd-spec" / status / ".gitkeep"
            self.assertTrue(keep.is_file(), f"missing tracked status placeholder: {keep}")
        self.run_pm(repository_root, "check")

    def test_prd_lifecycle_links_and_idempotent_map(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            first = self.run_pm(
                root, "prd", "new", "--title", "Project Master links", "--owner", "agent"
            )
            second = self.run_pm(
                root, "prd", "new", "--title", "Later work", "--status", "backlog"
            )
            self.assertIn("P-001", first.stdout)
            self.assertIn("P-002", second.stdout)
            self.assertIn("P-001 | backlog | Project Master links", self.run_pm(root, "prd", "list").stdout)
            self.assertIn("# PRD: Project Master links", self.run_pm(root, "prd", "show", "P-001").stdout)

            backlog = (
                root / ".project-master" / "prd-spec" / "backlog" / "P-001-project-master-links.md"
            )
            backlog.write_text(
                backlog.read_text(encoding="utf-8") + "\n## Authored Notes\n\nDo not erase this text.\n",
                encoding="utf-8",
            )

            self.run_pm(root, "session", "new")
            self.run_pm(
                root,
                "turn",
                "add",
                "--session",
                "S-001",
                "--prompt",
                "PRD",
                "--content",
                "links",
                "--intent",
                "traceability",
                "--response",
                "implemented",
                "--result",
                "PRD metadata",
            )
            self.run_pm(
                root,
                "decision",
                "add",
                "--session",
                "S-001",
                "--title",
                "Track PRD links",
                "--rationale",
                "trace changes",
                "--source",
                "test",
            )
            self.run_pm(
                root,
                "action",
                "add",
                "--session",
                "S-001",
                "--text",
                "Ship PRD support",
                "--owner",
                "agent",
            )
            for option, item_id in (
                ("--session", "S-001"),
                ("--turn", "T-001"),
                ("--decision", "D-001"),
                ("--action", "A-001"),
            ):
                self.run_pm(root, "prd", "link", "P-001", option, item_id)
                self.run_pm(root, "prd", "link", "P-001", option, item_id)

            self.run_pm(root, "prd", "status", "P-001", "--status", "active")
            self.run_pm(root, "prd", "index")
            self.run_pm(root, "prd", "index")
            self.run_pm(root, "check")

            active = (
                root / ".project-master" / "prd-spec" / "active" / "P-001-project-master-links.md"
            )
            text = active.read_text(encoding="utf-8")
            self.assertFalse(backlog.exists())
            self.assertIn("Do not erase this text.", text)
            self.assertIn("- Status: active", text)
            self.assertEqual(text.count("S-001"), 1)
            self.assertEqual(text.count("T-001"), 1)
            self.assertEqual(text.count("D-001"), 1)
            self.assertEqual(text.count("A-001"), 1)
            prd_map = (root / ".project-master" / "index" / "prd-map.md").read_text(
                encoding="utf-8"
            )
            self.assertEqual(prd_map.count("| P-001 |"), 1)
            self.assertEqual(prd_map.count("| P-002 |"), 1)
            self.assertIn("| P-001 | Project Master links | active | agent |", prd_map)

    def test_prd_invalid_links_and_corrupt_metadata_fail_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "prd", "new", "--title", "Validation")
            rejected = self.run_pm_failure(root, "prd", "link", "P-001", "--decision", "D-999")
            self.assertIn("D-999", rejected.stderr)

            path = root / ".project-master" / "prd-spec" / "backlog" / "P-001-validation.md"
            text = path.read_text(encoding="utf-8")
            text = text.replace("- Status: backlog", "- Status: active")
            text = text.replace("- Related Decisions:", "- Related Decisions: D-999")
            path.write_text(text, encoding="utf-8")
            (path.parent / "not-a-prd.md").write_text("# stray\n", encoding="utf-8")
            result = self.run_pm_failure(root, "check")
            self.assertIn("PRD status/path mismatch: P-001", result.stderr)
            self.assertIn("Related Decisions D-999", result.stderr)
            self.assertIn("invalid PRD filename", result.stderr)

    def test_prd_index_handles_backslashes_and_pipes_in_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(
                root,
                "prd",
                "new",
                "--title",
                r"API\query | index",
                "--owner",
                r"team\core",
            )
            self.run_pm(root, "check")
            prd_map = (root / ".project-master" / "index" / "prd-map.md").read_text(
                encoding="utf-8"
            )
            self.assertIn(r"API\query \| index", prd_map)
            self.assertIn(r"team\core", prd_map)

    def test_check_rejects_stale_map_and_prd_outside_status_folder(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "prd", "new", "--title", "Stale", "--owner", "original")
            path = root / ".project-master" / "prd-spec" / "backlog" / "P-001-stale.md"
            path.write_text(
                path.read_text(encoding="utf-8").replace("- Owner: original", "- Owner: changed"),
                encoding="utf-8",
            )
            result = self.run_pm_failure(root, "check")
            self.assertIn("stale PRD map managed block", result.stderr)

            self.run_pm(root, "prd", "index")
            archived = root / ".project-master" / "prd-spec" / "archived"
            archived.mkdir()
            path.rename(archived / path.name)
            result = self.run_pm_failure(root, "check")
            self.assertIn("invalid PRD location", result.stderr)
            self.assertIn("stale PRD map managed block", result.stderr)

    def test_concurrent_session_and_record_creation_assigns_unique_ids(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            attempts = 12

            def run(command: tuple[str, ...]) -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [sys.executable, str(PM), *command],
                    cwd=root,
                    text=True,
                    capture_output=True,
                )

            def run_parallel(commands: list[tuple[str, ...]]) -> set[str]:
                with ThreadPoolExecutor(max_workers=attempts) as executor:
                    results = list(executor.map(run, commands))
                for result in results:
                    self.assertEqual(result.returncode, 0, result.stderr)
                return {result.stdout.strip() for result in results}

            session_ids = run_parallel([("session", "new")] * attempts)
            self.assertEqual({f"S-{number:03d}" for number in range(1, attempts + 1)}, session_ids)

            commands = {
                "T": (
                    "turn",
                    "add",
                    "--session",
                    "S-001",
                    "--prompt",
                    "parallel",
                    "--content",
                    "records",
                    "--intent",
                    "locking",
                    "--response",
                    "stored",
                    "--result",
                    "unique",
                ),
                "D": (
                    "decision",
                    "add",
                    "--session",
                    "S-001",
                    "--title",
                    "Parallel decision",
                    "--rationale",
                    "locking",
                    "--source",
                    "test",
                ),
                "A": (
                    "action",
                    "add",
                    "--session",
                    "S-001",
                    "--text",
                    "Parallel action",
                    "--owner",
                    "agent",
                ),
                "Q": (
                    "question",
                    "add",
                    "--session",
                    "S-001",
                    "--text",
                    "Parallel question?",
                ),
            }
            for prefix, command in commands.items():
                item_ids = run_parallel([command] * attempts)
                expected = {f"{prefix}-{number:03d}" for number in range(1, attempts + 1)}
                self.assertEqual(expected, item_ids)

            self.run_pm(root, "check")

    def test_concurrent_prd_links_preserve_all_relations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "prd", "new", "--title", "Concurrent links")
            self.run_pm(root, "session", "new")
            self.run_pm(
                root,
                "turn",
                "add",
                "--session",
                "S-001",
                "--prompt",
                "trace",
                "--content",
                "links",
                "--intent",
                "preserve all",
                "--response",
                "link",
                "--result",
                "recorded",
            )
            self.run_pm(
                root,
                "decision",
                "add",
                "--session",
                "S-001",
                "--title",
                "Concurrency",
                "--rationale",
                "test",
                "--source",
                "test",
            )
            self.run_pm(
                root,
                "action",
                "add",
                "--session",
                "S-001",
                "--text",
                "Verify locking",
                "--owner",
                "agent",
            )
            links = (
                ("--session", "S-001"),
                ("--turn", "T-001"),
                ("--decision", "D-001"),
                ("--action", "A-001"),
            )

            def link(command: tuple[str, str]) -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [sys.executable, str(PM), "prd", "link", "P-001", *command],
                    cwd=root,
                    text=True,
                    capture_output=True,
                )

            with ThreadPoolExecutor(max_workers=4) as executor:
                results = list(executor.map(link, links))
            for result in results:
                self.assertEqual(result.returncode, 0, result.stderr)

            self.run_pm(root, "check")
            text = (
                root / ".project-master" / "prd-spec" / "backlog" / "P-001-concurrent-links.md"
            ).read_text(encoding="utf-8")
            for _, item_id in links:
                self.assertEqual(text.count(item_id), 1)

    def test_context_brief_includes_open_session_source_records(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            main = root / ".project-master" / "main.md"
            main.write_text(
                main.read_text(encoding="utf-8")
                .replace("TBD. 프로젝트의 목적과 범위를 기록합니다.", "Memory contract.")
                .replace("TBD. 현재 가장 중요한 작업을 기록합니다.", "Stabilize brief."),
                encoding="utf-8",
            )
            self.run_pm(root, "prd", "new", "--title", "Brief", "--status", "active")
            self.run_pm(root, "session", "new")
            self.run_pm(
                root,
                "decision",
                "add",
                "--session",
                "S-001",
                "--title",
                "Read source records",
                "--rationale",
                "open work matters",
                "--source",
                "test",
            )
            self.run_pm(root, "action", "add", "--session", "S-001", "--text", "Finish", "--owner", "agent")
            self.run_pm(root, "question", "add", "--session", "S-001", "--text", "Ready?")
            self.run_pm(
                root,
                "requirement",
                "add",
                "--prd",
                "P-001",
                "--text",
                "Load active requirement",
                "--status",
                "accepted",
            )

            brief = self.run_pm(root, "context", "brief").stdout
            self.assertIn("Memory contract.", brief)
            self.assertIn("- P-001: Brief", brief)
            self.assertIn("- R-001 (accepted, P-001): Load active requirement", brief)
            self.assertIn("- A-001: Finish", brief)
            self.assertIn("- D-001: Read source records", brief)
            self.assertIn("- Q-001: Ready?", brief)
            self.assertIn("- structural check: passed", brief)
            status = self.run_pm(root, "status").stdout
            self.assertIn("active decisions: 1", status)
            self.assertIn("pending actions: 1", status)

    def test_session_finish_writes_summary_indexes_and_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "session", "new")
            self.run_pm(
                root,
                "decision",
                "add",
                "--session",
                "S-001",
                "--title",
                "Finish atomically",
                "--rationale",
                "agent reliability",
                "--source",
                "test",
            )
            summary_path = root / ".project-master" / "sessions" / "S-001" / "summary.md"
            summary_path.write_text(
                summary_path.read_text(encoding="utf-8").replace(
                    "## Key Discussion Points\n\nTBD.",
                    "## Key Discussion Points\n\nPreserve authored discussion.",
                ),
                encoding="utf-8",
            )
            result = self.run_pm(
                root,
                "session",
                "finish",
                "S-001",
                "--one-line",
                "Finished work.",
                "--flow",
                "Recorded and validated.",
                "--intent",
                "Avoid missing closure.",
                "--next",
                "Ship.",
            )
            self.assertIn("check passed", result.stdout)
            summary = summary_path.read_text(encoding="utf-8")
            self.assertIn("- Status: closed", summary)
            self.assertIn("Finished work.", summary)
            self.assertIn("- D-001: Finish atomically", summary)
            self.assertIn("Preserve authored discussion.", summary)
            self.assertIn("열린 질문 없음.", summary)
            self.assertIn("| S-001 |", (root / ".project-master" / "index" / "session-map.md").read_text(encoding="utf-8"))
            self.run_pm(root, "check")

            repeated = self.run_pm(
                root,
                "session",
                "finish",
                "S-001",
                "--one-line",
                "Finished work.",
                "--flow",
                "Recorded and validated.",
                "--intent",
                "Avoid missing closure.",
                "--next",
                "Ship.",
            )
            self.assertIn("changelog unchanged", repeated.stdout)
            changelog = (root / ".project-master" / "index" / "changelog.md").read_text(encoding="utf-8")
            self.assertEqual(changelog.count("<!-- PM:index-update:S-001 -->"), 1)
            self.assertIn("Preserve authored discussion.", summary_path.read_text(encoding="utf-8"))
            closed_source_commands = (
                ("raw", "append", "--session", "S-001", "--role", "user", "--content", "late"),
                (
                    "turn",
                    "add",
                    "--session",
                    "S-001",
                    "--prompt",
                    "late",
                    "--content",
                    "late",
                    "--intent",
                    "late",
                    "--response",
                    "late",
                    "--result",
                    "late",
                ),
                (
                    "decision",
                    "add",
                    "--session",
                    "S-001",
                    "--title",
                    "late",
                    "--rationale",
                    "late",
                    "--source",
                    "late",
                ),
                ("action", "add", "--session", "S-001", "--text", "late", "--owner", "agent"),
                ("question", "add", "--session", "S-001", "--text", "late"),
            )
            for command in closed_source_commands:
                rejected_source = self.run_pm_failure(root, *command)
                self.assertIn("closed session", rejected_source.stderr)

            rejected = self.run_pm_failure(
                root,
                "session",
                "finish",
                "S-001",
                "--one-line",
                "",
                "--flow",
                "flow",
                "--intent",
                "intent",
                "--next",
                "next",
            )
            self.assertIn("비어 있을 수 없습니다", rejected.stderr)

    def test_session_finish_refuses_invalid_project_before_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "session", "new")
            (root / ".project-master" / "index" / "decisions.md").unlink()
            rejected = self.run_pm_failure(
                root,
                "session",
                "finish",
                "S-001",
                "--one-line",
                "Should not write.",
                "--flow",
                "invalid",
                "--intent",
                "guard",
                "--next",
                "repair",
            )
            self.assertIn("failed before session finish", rejected.stderr)
            summary = (root / ".project-master" / "sessions" / "S-001" / "summary.md").read_text(
                encoding="utf-8"
            )
            self.assertIn("- Status: open", summary)
            self.assertIn("TBD. session", summary)

    def test_requirement_lifecycle_preserves_authored_text_and_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "prd", "new", "--title", "Requirement trace", "--status", "active")
            path = root / ".project-master" / "prd-spec" / "active" / "P-001-requirement-trace.md"
            path.write_text(path.read_text(encoding="utf-8") + "\nAuthored note remains.\n", encoding="utf-8")
            self.run_pm(root, "session", "new")
            self.run_pm(
                root,
                "turn",
                "add",
                "--session",
                "S-001",
                "--prompt",
                "requirement",
                "--content",
                "trace",
                "--intent",
                "preserve provenance",
                "--response",
                "add",
                "--result",
                "R-001",
            )
            self.run_pm(
                root,
                "requirement",
                "add",
                "--prd",
                "P-001",
                "--text",
                "Provide traceability",
                "--status",
                "proposed",
                "--session",
                "S-001",
                "--turn",
                "T-001",
            )
            self.run_pm(
                root,
                "requirement",
                "status",
                "R-001",
                "--status",
                "accepted",
                "--session",
                "S-001",
                "--turn",
                "T-001",
            )
            listing = self.run_pm(root, "requirement", "list", "--prd", "P-001").stdout
            text = path.read_text(encoding="utf-8")
            self.assertIn("R-001 | accepted | Provide traceability", listing)
            self.assertIn("Authored note remains.", text)
            self.assertIn("- Status: accepted", text)
            self.assertIn("status=proposed", text)
            self.assertIn("status=accepted", text)
            self.assertIn("- Source Sessions: S-001", text)
            self.assertIn("- Source Turns: T-001", text)
            self.run_pm(root, "check")

            text = path.read_text(encoding="utf-8").replace("- Last Source Turn: T-001", "- Last Source Turn: T-999")
            path.write_text(text, encoding="utf-8")
            invalid = self.run_pm_failure(root, "check")
            self.assertIn("invalid requirement source in R-001", invalid.stderr)

    def test_requirement_allocator_reserves_authored_requirement_ids(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "prd", "new", "--title", "Legacy IDs")
            path = root / ".project-master" / "prd-spec" / "backlog" / "P-001-legacy-ids.md"
            path.write_text(
                path.read_text(encoding="utf-8") + "\n- R-004 (accepted): authored before CLI support.\n",
                encoding="utf-8",
            )
            created = self.run_pm(
                root,
                "requirement",
                "add",
                "--prd",
                "P-001",
                "--text",
                "Managed later",
            ).stdout
            self.assertIn("R-005", created)
            self.run_pm(root, "check")

    def test_record_status_commands_update_source_and_index(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "session", "new")
            for title in ("Original", "Replacement"):
                self.run_pm(
                    root,
                    "decision",
                    "add",
                    "--session",
                    "S-001",
                    "--title",
                    title,
                    "--rationale",
                    "test",
                    "--source",
                    "test",
                )
            self.run_pm(root, "action", "add", "--session", "S-001", "--text", "Work", "--owner", "agent")
            self.run_pm(root, "question", "add", "--session", "S-001", "--text", "Question")
            self.run_pm(root, "decision", "status", "D-001", "--status", "superseded", "--by", "D-002")
            self.run_pm(root, "action", "status", "A-001", "--status", "done")
            self.run_pm(root, "question", "status", "Q-001", "--status", "resolved")

            decision = (root / ".project-master" / "index" / "decisions.md").read_text(encoding="utf-8")
            action = (root / ".project-master" / "index" / "next-actions.md").read_text(encoding="utf-8")
            question = (root / ".project-master" / "index" / "open-questions.md").read_text(encoding="utf-8")
            self.assertIn("- Status: superseded", decision)
            self.assertIn("- Superseded by: D-002", decision)
            self.assertIn("- Status: done", action)
            self.assertIn("- Status: resolved", question)
            brief = self.run_pm(root, "context", "brief").stdout
            self.assertNotIn("- A-001: Work", brief)
            self.assertNotIn("- Q-001: Question", brief)
            self.assertNotIn("- D-001: Original", brief)
            self.assertIn("- D-002: Replacement", brief)
            self.run_pm(root, "check")

    def test_concurrent_requirement_adds_assign_unique_ids(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.run_pm(root, "init")
            self.run_pm(root, "prd", "new", "--title", "Concurrent requirements")
            attempts = 8

            def add(number: int) -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [
                        sys.executable,
                        str(PM),
                        "requirement",
                        "add",
                        "--prd",
                        "P-001",
                        "--text",
                        f"Requirement {number}",
                    ],
                    cwd=root,
                    text=True,
                    capture_output=True,
                )

            with ThreadPoolExecutor(max_workers=attempts) as executor:
                results = list(executor.map(add, range(attempts)))
            for result in results:
                self.assertEqual(result.returncode, 0, result.stderr)
            listing = self.run_pm(root, "requirement", "list", "--prd", "P-001").stdout
            for number in range(1, attempts + 1):
                self.assertIn(f"R-{number:03d}", listing)
            self.run_pm(root, "check")


if __name__ == "__main__":
    unittest.main()
