"""Workflow outputs point at step outputs that are actually written; stdlib only."""

import re
import unittest
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[2] / ".github" / "workflows"


class StepOutputTests(unittest.TestCase):
    def test_every_read_step_output_is_written(self):
        for path in sorted(WORKFLOWS.glob("*.yml")):
            text = path.read_text(encoding="utf-8")
            for step, name in set(re.findall(r"steps\.([\w-]+)\.outputs\.([\w-]+)", text)):
                step_re = rf"\n(\s*)- (?:name: [^\n]*\n\s*)?id: {re.escape(step)}\n(.*?)(?=\n\1- |\Z)"
                block = re.search(step_re, text, re.S)
                with self.subTest(workflow=path.name, step=step, output=name):
                    self.assertIsNotNone(block, f"step id '{step}' not found")
                    if re.search(r"^\s*uses:", block.group(2), re.M):
                        continue
                    self.assertRegex(block.group(2), rf"echo \"{re.escape(name)}=")


class BuildWorkflowTests(unittest.TestCase):
    """Build smoke-tests exports on pull requests, but only main pushes the server image."""

    def setUp(self):
        self.text = (WORKFLOWS / "build.yml").read_text(encoding="utf-8")

    def _triggers(self):
        return re.search(r"^on:\n(.*?)^\S", self.text, re.S | re.M).group(1)

    def test_runs_on_main_pushes_and_pull_requests(self):
        triggers = self._triggers()
        self.assertRegex(triggers, r"(?m)^  push:\n    branches: \[main\]")
        self.assertRegex(triggers, r"(?m)^  pull_request:")

    def test_pull_requests_skip_the_same_paths_as_pushes(self):
        blocks = re.findall(r"(?m)^  (push|pull_request):\n(.*?)(?=^  \S)", self._triggers(), re.S)
        ignored = {event: re.findall(r'^      - "(.+)"$', body, re.M) for event, body in blocks}
        self.assertTrue(ignored["push"])
        self.assertEqual(ignored["push"], ignored["pull_request"])

    def test_export_job_runs_the_smoke_test(self):
        self.assertIn("uses: ./.github/workflows/export.yml", self.text)
        export = (WORKFLOWS / "export.yml").read_text(encoding="utf-8")
        self.assertIn("run: tools/ci/smoke_test.sh", export)

    def test_server_image_is_pushed_from_main_only(self):
        job = re.search(r"(?m)^  server-image:\n(.*?)(?=^  \S|\Z)", self.text, re.S).group(1)
        self.assertIn("if: github.ref == 'refs/heads/main'", job)


class CoopSoakWorkflowTests(unittest.TestCase):
    """Short co-op soak on pull requests, 4 bots to round 20 nightly and on demand, fails on errors."""

    def setUp(self):
        self.text = (WORKFLOWS / "coop-soak.yml").read_text(encoding="utf-8")

    def test_runs_on_pull_requests_nightly_and_by_hand(self):
        triggers = re.search(r"^on:\n(.*?)^\S", self.text, re.S | re.M).group(1)
        self.assertRegex(triggers, r"(?m)^  pull_request:")
        self.assertRegex(triggers, r"(?m)^  schedule:\n    - cron: ")
        self.assertRegex(triggers, r"(?m)^  workflow_dispatch:")
        self.assertIn('- "tools/soak/**"', triggers)

    def test_short_run_on_pull_requests_and_full_run_otherwise(self):
        self.assertIn("CLIENTS: ${{ github.event_name == 'pull_request' && '2' || inputs.clients || '4' }}", self.text)
        self.assertIn("ROUNDS: ${{ github.event_name == 'pull_request' && '5' || inputs.rounds || '20' }}", self.text)

    def test_runs_the_coop_soak_and_fails_on_errors(self):
        self.assertIn("--script res://tools/soak/coop_soak.gd", self.text)
        self.assertIn("grep -E 'SCRIPT ERROR|Parse Error' coop-soak.log", self.text)
        self.assertIn("grep -q '^| PASS | co-op soak' coop-soak.log", self.text)

    def test_inputs_reach_the_shell_through_env_only(self):
        run_blocks = re.findall(r"(?m)^        run: \|\n(.*?)(?=^      - |\Z)", self.text, re.S)
        self.assertTrue(run_blocks)
        for block in run_blocks:
            self.assertNotIn("${{", block)

    def test_failed_runs_keep_every_process_log(self):
        self.assertIn("coop-soak/*.json", self.text)
        self.assertIn("coop-soak/*/godot/app_userdata/Experiment Undead/logs/", self.text)


if __name__ == "__main__":
    unittest.main()


class LauncherWorkflowTests(unittest.TestCase):
    """The separate launcher is linted, tested on Linux and Windows, and built as a Windows exe."""

    def setUp(self):
        self.text = (WORKFLOWS / "launcher.yml").read_text(encoding="utf-8")

    def test_runs_for_launcher_changes_and_the_shared_version_table(self):
        triggers = re.search(r"^on:\n(.*?)^\S", self.text, re.S | re.M).group(1)
        for path in ("launcher/**", "tests/fixtures/version_table.json"):
            self.assertEqual(triggers.count(f'"{path}"'), 2, path)

    def test_checks_format_lint_tests_and_builds_on_windows(self):
        for command in ("cargo fmt --all --check", "-D warnings", "cargo test --workspace"):
            self.assertIn(command, self.text)
        self.assertRegex(self.text, r"(?s)windows:\n\s+runs-on: windows-latest.*--bundles nsis")
        self.assertIn('"/S"', self.text)
        self.assertIn("uninstall.exe", self.text)


class ReleaseLauncherTests(unittest.TestCase):
    """Release tags build the signed launcher setup and attach it with its update manifest."""

    def setUp(self):
        self.text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")

    def test_publish_waits_for_the_launcher_and_attaches_everything(self):
        self.assertRegex(self.text, r"publish:\n    needs: \[[^\]]*launcher")
        self.assertIn("ExperimentUndead-Setup-$version.exe", self.text)
        self.assertIn("launcher_release.py manifest", self.text)
        self.assertIn("--out dist/latest.json", self.text)
        self.assertEqual(self.text.count("dist/* "), 2)

    def test_signs_with_the_secret_and_stamps_the_version(self):
        self.assertIn("secrets.TAURI_SIGNING_PRIVATE_KEY", self.text)
        self.assertIn("launcher_release.py stamp", self.text)
