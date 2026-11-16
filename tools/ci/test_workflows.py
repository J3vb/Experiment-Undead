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


if __name__ == "__main__":
    unittest.main()
