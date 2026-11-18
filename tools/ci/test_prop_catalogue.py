"""Keeps docs/design/prop-library.md in step with the prop, dressing and town models (plan F-77)."""

import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CATALOGUE = REPO / "docs" / "design" / "prop-library.md"
MODELS = REPO / "assets" / "models"
FOLDERS = ("props", "dressing", "props_large", "town", "town_large")
FAMILIES = {
    "Halcyon",
    "Town",
    "Barriers",
    "Military",
    "Industrial",
    "Rail",
    "Large",
    "Hospital",
    "Heroes",
    "Outdoor",
}


def catalogue_rows(text: str) -> list[dict[str, str]]:
    """Model rows: table lines whose first cell is a `name`."""
    rows = []
    for line in text.splitlines():
        cells = [cell.strip() for cell in line.split("|")[1:-1]]
        if len(cells) != 6 or not cells[0].startswith("`"):
            continue
        name, folder, size, families, maps, slots = cells
        rows.append(
            {
                "name": name.strip("`"),
                "folder": folder,
                "size": size,
                "families": families,
                "maps": maps,
                "slots": slots,
            }
        )
    return rows


def model_files(root: Path) -> set[tuple[str, str]]:
    return {
        (folder, glb.stem) for folder in FOLDERS if (root / folder).is_dir() for glb in (root / folder).glob("*.glb")
    }


def problems(rows: list[dict[str, str]], files: set[tuple[str, str]]) -> list[str]:
    errors = []
    listed = [(row["folder"], row["name"]) for row in rows]
    for folder, name in sorted(files - set(listed)):
        errors.append(f"{folder}/{name}.glb has no catalogue row")
    for folder, name in sorted(set(listed) - files):
        errors.append(f"row {folder}/{name} names a missing file")
    errors += [f"{key[0]}/{key[1]} is listed twice" for key in sorted(set(listed)) if listed.count(key) > 1]
    for row in rows:
        families = {family.strip() for family in row["families"].split(",")}
        if not families <= FAMILIES:
            errors.append(f"{row['name']}: unknown family {sorted(families - FAMILIES)}")
        if not all(row[key] for key in ("size", "maps", "slots")):
            errors.append(f"{row['name']}: size, maps and slots must be filled in")
    return errors


class PropCatalogueTest(unittest.TestCase):
    def test_every_model_has_one_row_and_every_row_a_model(self) -> None:
        rows = catalogue_rows(CATALOGUE.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(rows), 75)
        self.assertEqual(problems(rows, model_files(MODELS)), [])

    def test_missing_row_fails(self) -> None:
        rows = [
            {
                "name": "crate",
                "folder": "props",
                "size": "1 x 1 x 1",
                "families": "Halcyon",
                "maps": "x",
                "slots": "Wood",
            }
        ]
        self.assertEqual(
            problems(rows, {("props", "crate"), ("props_large", "train_car")}),
            ["props_large/train_car.glb has no catalogue row"],
        )

    def test_row_without_file_fails(self) -> None:
        rows = [
            {
                "name": "ghost",
                "folder": "dressing",
                "size": "1 x 1 x 1",
                "families": "Rail",
                "maps": "x",
                "slots": "Iron",
            }
        ]
        self.assertEqual(problems(rows, set()), ["row dressing/ghost names a missing file"])

    def test_unknown_family_and_empty_cells_fail(self) -> None:
        rows = [
            {
                "name": "crate",
                "folder": "props",
                "size": "",
                "families": "Halcyon, Spaceship",
                "maps": "x",
                "slots": "Wood",
            }
        ]
        self.assertEqual(
            problems(rows, {("props", "crate")}),
            [
                "crate: unknown family ['Spaceship']",
                "crate: size, maps and slots must be filled in",
            ],
        )


if __name__ == "__main__":
    unittest.main()
