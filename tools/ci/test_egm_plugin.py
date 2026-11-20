"""The vendored Elephant-Goldfish Model plugin is complete and wired for Claude Code and Codex; stdlib only."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / ".agents/plugins/egm"
SKILLS = ("bootstrap", "brainstorm", "draft", "drift-report", "lite", "resolve", "review", "review-loop")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class EgmPluginTests(unittest.TestCase):
    def test_manifests_name_the_same_plugin(self):
        for manifest in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json", "plugin.json"):
            data = load(PLUGIN / manifest)
            self.assertEqual(data["name"], "egm", manifest)
            self.assertEqual(data["license"], "Apache-2.0", manifest)
        self.assertIn("Apache License", (PLUGIN / "LICENSE").read_text(encoding="utf-8").splitlines()[1])

    def test_claude_marketplace_points_at_the_plugin_root(self):
        market = load(PLUGIN / ".claude-plugin/marketplace.json")
        self.assertEqual([(p["name"], p["source"]) for p in market["plugins"]], [("egm", "./")])

    def test_every_listed_agent_file_exists(self):
        agents = load(PLUGIN / ".claude-plugin/plugin.json")["agents"]
        self.assertEqual(len(agents), 10)
        for agent in agents:
            self.assertTrue((PLUGIN / agent).is_file(), agent)
            self.assertTrue((PLUGIN / "agents" / Path(agent).name).is_file(), agent)

    def test_every_skill_has_its_skill_file(self):
        for skill in SKILLS:
            text = (PLUGIN / f"skills/egm-{skill}/SKILL.md").read_text(encoding="utf-8")
            self.assertIn(f"name: egm-{skill}", text)

    def test_files_the_skills_read_are_vendored(self):
        needed = set()
        for skill in (PLUGIN / "skills").glob("*/SKILL.md"):
            text = skill.read_text(encoding="utf-8")
            needed |= {f"docs/{name}" for name in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/docs/([\w.]+\.md)", text)}
            needed |= set(re.findall(r"\(\.\./\.\./([\w./]+\.md)\)", text))
            needed |= set(re.findall(r"`(resources/document_standards/[\w.-]+\.md)`", text))
            needed |= set(re.findall(r"`(agents/\w+\.md)`", text))
        self.assertIn("docs/claude.md", needed)
        for path in sorted(needed):
            self.assertTrue((PLUGIN / path).is_file(), path)

    def test_codex_repo_marketplace_lists_the_plugin(self):
        market = load(ROOT / ".agents/plugins/marketplace.json")
        sources = {p["name"]: p["source"] for p in market["plugins"]}
        self.assertEqual(sources, {"egm": "./.agents/plugins/egm"})
        self.assertTrue((ROOT / sources["egm"] / ".codex-plugin/plugin.json").is_file())

    def test_session_hook_enables_the_plugin_in_local_settings(self):
        hook = (ROOT / ".claude/hooks/session-start.sh").read_text(encoding="utf-8")
        self.assertIn('marketplace add "$PWD/.agents/plugins/egm" --scope local', hook)
        self.assertIn("plugin install egm@egm --scope local", hook)
        self.assertLess(hook.index("egm@egm"), hook.index('"${CLAUDE_CODE_REMOTE:-}"'))
        self.assertIn(".claude/settings.local.json", (ROOT / ".gitignore").read_text(encoding="utf-8").splitlines())


if __name__ == "__main__":
    unittest.main()
