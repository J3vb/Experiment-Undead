"""Contact reports distinguish separation, surface crossing and fully enclosed geometry."""

import sys
from copy import deepcopy
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import check_character_contacts as contacts


def _box(center, size, name="weapon"):
    vertices = [
        [center[axis] + sign[axis] * size / 2 for axis in range(3)]
        for sign in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))
    ]
    faces = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    # Exported Godot triangles use clockwise front faces.
    triangles = [[face[0], face[2], face[1]] for face in faces]
    triangles += [[face[0], face[3], face[2]] for face in faces]
    return {"name": name, "vertices": vertices, "triangles": triangles}


def _snapshot(hand, weapons):
    hand["labels"] = ["hand_R"] * len(hand["triangles"])
    return {
        "weapon": "fixture",
        "phase": "hip",
        "arms": [hand],
        "cuffs": [],
        "weapon_meshes": weapons,
        "morph_weights": {},
    }


def _offset_cap(mesh, distance):
    indices = {}
    for triangle in (0, 6):
        for corner, original in enumerate(mesh["triangles"][triangle]):
            if original not in indices:
                indices[original] = len(mesh["vertices"])
                point = mesh["vertices"][original].copy()
                point[2] -= distance
                mesh["vertices"].append(point)
            mesh["triangles"][triangle][corner] = indices[original]
    return mesh


def test_separated_godot_meshes_have_positive_surface_clearance():
    result = contacts.inspect_contacts(_snapshot(_box((2, 0, 0), 0.4), [_box((0, 0, 0), 2)]))["groups"]["hand_R"]
    assert result["intersection_pairs"] == 0
    assert result["enclosed_samples"] == 0
    assert result["min_sampled_mm"] == pytest.approx(800, abs=0.001)
    assert result["embedded_weapon_samples"] == 0


def test_actual_triangle_crossings_fail_the_contact_report():
    result = contacts.inspect_contacts(_snapshot(_box((0.95, 0, 0), 0.4), [_box((0, 0, 0), 2)]))
    assert result["groups"]["hand_R"]["intersection_pairs"] > 0
    assert result["groups"]["hand_R"]["enclosed_samples"] > 0
    assert contacts._report(result) == ["fixture hip hand_R"]


def test_fully_enclosed_hand_is_detected_without_any_triangle_crossing():
    result = contacts.inspect_contacts(_snapshot(_box((0, 0, 0), 0.4), [_box((0, 0, 0), 2)]))["groups"]["hand_R"]
    assert result["intersection_pairs"] == 0
    assert result["enclosed_samples"] > 0
    assert result["min_sampled_mm"] < -700


def test_overlapping_closed_weapon_parts_do_not_cancel_containment():
    weapons = [_box((-0.25, 0, 0), 2), _box((0.25, 0, 0), 2)]
    result = contacts.inspect_contacts(_snapshot(_box((0, 0, 0), 0.2), weapons))["groups"]["hand_R"]
    assert result["intersection_pairs"] == 0
    assert result["enclosed_samples"] > 0
    assert result["min_sampled_mm"] < 0


def test_nearer_separate_part_does_not_hide_containment_in_a_larger_part():
    weapons = [_box((0, 0, 0), 4), _box((0.6, 0, 0), 0.4)]
    result = contacts.inspect_contacts(_snapshot(_box((0, 0, 0), 0.2), weapons))["groups"]["hand_R"]
    assert result["intersection_pairs"] == 0
    assert result["enclosed_samples"] > 0
    assert result["min_sampled_mm"] < 0


@pytest.mark.parametrize("split_labels", [False, True], ids=["hand", "hand_forearm_boundary"])
def test_fully_embedded_weapon_part_fails_without_any_triangle_crossing(split_labels):
    snapshot = _snapshot(_box((0, 0, 0), 0.08), [_box((0, 0, 0), 0.02)])
    if split_labels:
        snapshot["arms"][0]["labels"][::2] = ["forearm_R"] * 6
    result = contacts.inspect_contacts(snapshot)
    assert result["open_arm_parts"] == 0
    assert all(group["intersection_pairs"] == 0 for group in result["groups"].values())
    assert all(group["enclosed_samples"] == 0 for group in result["groups"].values())
    assert sum(group["embedded_weapon_samples"] for group in result["groups"].values()) > 0
    assert contacts._report(result)


@pytest.mark.parametrize("centers", [(0, 0), (-0.04, 0.04)], ids=["duplicate_solids", "touching_solids"])
def test_nonmanifold_welded_weapon_solids_cannot_report_clean_contacts(centers):
    weapons = [_box((center, 0, 0), 0.08) for center in centers]
    result = contacts.inspect_contacts(_snapshot(_box((centers[0], 0, 0), 0.02), weapons))
    assert result["open_weapon_parts"] == 0
    assert result["closed_weapon_parts"] == 2
    assert result["groups"]["hand_R"]["intersection_pairs"] == 0
    assert result["groups"]["hand_R"]["enclosed_samples"] > 0
    assert contacts._report(result)


def test_open_arm_surface_cannot_report_clean_contacts():
    hand = _box((0.2, 0, 0), 0.04)
    hand["triangles"].pop()
    result = contacts.inspect_contacts(_snapshot(hand, [_box((0, 0, 0), 0.08)]))
    assert result["open_arm_parts"] > 0
    assert result["groups"]["hand_R"]["intersection_pairs"] == 0
    assert contacts._report(result)


def test_missing_weapon_geometry_cannot_report_success():
    with pytest.raises(ValueError, match="no weapon triangles"):
        contacts.inspect_contacts(_snapshot(_box((0, 0, 0), 0.4), []))


def test_compressed_material_seam_is_closed_without_changing_exported_triangles():
    weapon = _offset_cap(_box((0, 0, 0), 0.08), 0.000005)
    snapshot = _snapshot(_box((0.2, 0, 0), 0.02), [weapon])
    original = deepcopy(snapshot)
    result = contacts.inspect_contacts(snapshot)
    assert result["open_weapon_parts"] == 0
    assert result["closed_weapon_parts"] == 1
    assert contacts._report(result) == []
    assert snapshot == original


def test_real_gap_is_not_closed_by_compression_seam_matching():
    weapon = _offset_cap(_box((0, 0, 0), 0.08), 0.0005)
    result = contacts.inspect_contacts(_snapshot(_box((0.2, 0, 0), 0.02), [weapon]))
    assert result["open_weapon_parts"] > 0
    assert contacts._report(result)


@pytest.mark.parametrize("side", ["L", "R"])
def test_clavicle_geometry_is_checked_for_weapon_containment(side):
    snapshot = _snapshot(_box((0, 0, 0), 0.02), [_box((0, 0, 0), 0.08)])
    snapshot["arms"][0]["labels"] = ["clavicle_" + side] * 12
    result = contacts.inspect_contacts(snapshot)
    assert result["groups"]["clavicle_" + side]["enclosed_samples"] > 0
    assert contacts._report(result)


def test_unexpected_arm_bone_cannot_silently_skip_its_geometry():
    snapshot = _snapshot(_box((0, 0, 0), 0.02), [_box((0, 0, 0), 0.08)])
    snapshot["arms"][0]["labels"] = ["pelvis"] * 12
    with pytest.raises(ValueError, match="Unexpected arm triangle labels"):
        contacts.inspect_contacts(snapshot)
