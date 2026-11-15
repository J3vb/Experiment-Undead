"""Keeps docs/design/balance/roster.csv consistent with weapons.csv and the roster doc."""

import csv
import math
import unittest
from pathlib import Path

BALANCE = Path(__file__).resolve().parents[2] / "docs" / "design" / "balance"
DOC = BALANCE.parent / "gun-roster.md"
SHARED = [
    "Damage / pellet",
    "Pellets",
    "Head mult override",
    "RPM",
    "RPM factor",
    "Mag",
    "Reserve",
    "Reload s",
    "ADS s",
]
HS_RATIO = 0.3


def read_table(name: str, header_row: int) -> list[dict[str, str]]:
    with (BALANCE / name).open(encoding="utf-8") as file:
        rows = list(csv.reader(file))
    header = rows[header_row]
    return [dict(zip(header, row, strict=False)) for row in rows[header_row + 1 :] if row and row[0]]


def num(value: str) -> float:
    return float(value) if value else 0.0


class GunRosterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.roster = read_table("roster.csv", 3)
        self.weapons = {row["id"]: row for row in read_table("weapons.csv", 3) if row.get("Name")}

    def test_has_22_unique_guns(self) -> None:
        ids = [row["id"] for row in self.roster]
        self.assertEqual(len(ids), 22)
        self.assertEqual(len(set(ids)), 22)

    def test_designed_guns_match_weapons_csv(self) -> None:
        designed = [row for row in self.roster if row["Status"] == "designed"]
        self.assertEqual({row["id"] for row in designed}, set(self.weapons))
        for row in designed:
            for column in SHARED:
                self.assertEqual(num(row[column]), num(self.weapons[row["id"]][column]), f"{row['id']} {column}")

    def test_sources_and_unlock_levels(self) -> None:
        for row in self.roster:
            gun = row["id"]
            self.assertIn(row["Source"], {"Start", "Wall", "Wall (map)", "Loot", "Prototype"}, gun)
            self.assertTrue(1 <= int(row["Unlock level"]) <= 50, gun)
            is_wall = row["Source"].startswith("Wall")
            self.assertEqual(int(row["Wall cost"]) > 0, is_wall, gun)
            self.assertEqual(bool(row["Wall map"]), is_wall, gun)

    def test_one_signature_wall_gun_per_map(self) -> None:
        maps = [row["Wall map"] for row in self.roster if row["Source"] == "Wall (map)"]
        self.assertEqual(sorted(maps), ["grauwald", "halcyon_labs", "kessel_dam", "marrow_junction"])

    def test_calculated_columns(self) -> None:
        for row in self.roster:
            shot = num(row["Damage / pellet"]) * num(row["Pellets"])
            rpm = num(row["RPM"]) * num(row["RPM factor"])
            head = num(row["Head mult override"]) or 2.5
            mag = num(row["Mag"])
            sustained = mag * shot * (1 + HS_RATIO * (head - 1)) / (mag * 60 / rpm + num(row["Reload s"]))
            self.assertTrue(math.isclose(num(row["Damage / shot"]), shot), row["id"])
            self.assertAlmostEqual(num(row["Body DPS"]), shot * rpm / 60, delta=0.1, msg=row["id"])
            self.assertAlmostEqual(num(row["Sustained DPS"]), sustained, delta=0.1, msg=row["id"])

    def test_doc_names_every_gun(self) -> None:
        text = DOC.read_text(encoding="utf-8")
        for row in self.roster:
            self.assertIn(row["Name"], text, row["id"])


if __name__ == "__main__":
    unittest.main()
