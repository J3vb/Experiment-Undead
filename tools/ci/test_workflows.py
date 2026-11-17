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


if __name__ == "__main__":
    unittest.main()
