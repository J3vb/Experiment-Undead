"""Tests for the feature plan checker; stdlib only."""

import tempfile
import unittest
from pathlib import Path

from tools.ci import check_plans

TEMPLATE = (Path(__file__).resolve().parents[2] / "docs" / "plans" / "TEMPLATE.md").read_text(encoding="utf-8")


def plan(status: str = "Draft", approved_by: str = "", decisions: str = "- none") -> str:
    text = TEMPLATE.replace("# Plan: <feature name>", "# Plan: Test feature")
    text = text.replace("Status: Draft", f"Status: {status}")
    text = text.replace("Approved by: <who approved and when, empty until Approved>", f"Approved by: {approved_by}")
    return text.replace("## Open decisions", "## Open decisions\n\n" + decisions + "\n\n## Old decisions")


class CheckPlanTests(unittest.TestCase):
    def test_template_shaped_draft_passes(self):
        self.assertEqual(check_plans.check_plan("a.md", plan()), [])

    def test_bad_status_fails(self):
        problems = check_plans.check_plan("a.md", plan(status="Started"))
        self.assertTrue(any("Status must be one of" in p for p in problems))

    def test_missing_section_fails(self):
        text = plan().replace("## Co-op behaviour", "## Network")
        self.assertIn("a.md: missing section '## Co-op behaviour'", check_plans.check_plan("a.md", text))

    def test_missing_first_step_fails(self):
        text = plan().replace("### Step 1:", "### First:")
        self.assertTrue(any("Step 1" in p for p in check_plans.check_plan("a.md", text)))

    def test_approved_without_approver_fails(self):
        problems = check_plans.check_plan("a.md", plan(status="Approved"))
        self.assertTrue(any("Approved by" in p for p in problems))

    def test_approved_with_open_decision_fails(self):
        text = plan(status="Approved", approved_by="review PR #1", decisions="- Which colour for the beam?")
        problems = check_plans.check_plan("a.md", text)
        self.assertEqual(problems, ["a.md: open decision left on an approved plan: Which colour for the beam?"])

    def test_approved_with_answered_decision_passes(self):
        text = plan(status="Done", approved_by="review PR #1", decisions="- [x] Beam colour: rarity colour")
        self.assertEqual(check_plans.check_plan("a.md", text), [])

    def test_draft_may_have_open_decisions(self):
        self.assertEqual(check_plans.check_plan("a.md", plan(decisions="- Which colour?")), [])


class CheckAllTests(unittest.TestCase):
    def test_roadmap_link_to_missing_plan_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            docs = Path(directory)
            (docs / "plans").mkdir()
            (docs / "plans" / "TEMPLATE.md").write_text("not a plan", encoding="utf-8")
            (docs / "plans" / "real.md").write_text(plan(), encoding="utf-8")
            (docs / "ROADMAP.md").write_text("[a](plans/real.md) [b](plans/gone.md)", encoding="utf-8")
            self.assertEqual(
                check_plans.check_all(docs), ["ROADMAP.md: plan link points to a missing file: plans/gone.md"]
            )

    def test_repo_plans_pass(self):
        self.assertEqual(check_plans.check_all(check_plans.ROOT / "docs"), [])


if __name__ == "__main__":
    unittest.main()
