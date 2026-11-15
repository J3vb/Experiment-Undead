"""Run with GODOT=./godot python -m unittest discover -s tools/benchmark."""

import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
import unittest


class BenchmarkTests(unittest.TestCase):
    def run_benchmark(self, *args):
        with tempfile.TemporaryDirectory() as data_dir:
            completed = subprocess.run(
                [os.environ.get("GODOT", "godot"), "--headless", "--path", ".",
                 "--script", "res://tools/benchmark/benchmark.gd", "--", *args],
                env={**os.environ, "XDG_DATA_HOME": data_dir},
                capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertNotIn("SCRIPT ERROR", completed.stderr)
            self.assertNotIn("Parse Error", completed.stderr)
            files = list(Path(data_dir).rglob("benchmark_*.json"))
            self.assertEqual(len(files), 1, completed.stdout + completed.stderr)
            self.assertIn(str(files[0]), completed.stdout)
            return json.loads(files[0].read_text()), completed.stdout

    def test_repeatable_population_and_statistics(self):
        for _ in range(2):
            result, output = self.run_benchmark(
                "--zombies", "4", "--seconds", "0.2", "--seed", "1"
            )
            self.assertEqual(result["status"], "ok")
            self.assertEqual(result["spawned_zombies"], 4)
            self.assertEqual(result["alive_zombies"], 4)
            self.assertTrue(result["player_alive"])
            self.assertEqual(result["warmup_seconds"], 2)
            samples = sorted(result["samples_ms"])
            self.assertEqual(len(samples), math.ceil(0.2 * result["physics_hz"]))
            self.assertEqual(result["sample_count"], len(samples))
            self.assertAlmostEqual(result["average_ms"], statistics.mean(samples))
            self.assertEqual(result["p95_ms"], samples[math.ceil(len(samples) * 0.95) - 1])
            self.assertEqual(result["p99_ms"], samples[math.ceil(len(samples) * 0.99) - 1])
            self.assertEqual(result["max_ms"], max(samples))
            self.assertGreater(result["average_ms"], 0)
            self.assertIn("| Zombies |", output)

    def test_invalid_arguments_still_exit_zero_with_error_result(self):
        for args in [("--seconds", "0"), ("--zombies", "0"), ("--unknown", "1")]:
            result, _ = self.run_benchmark(*args)
            self.assertEqual(result["status"], "error")
            self.assertIn("error", result)
