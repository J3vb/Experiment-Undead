## Every gun with a balance-sheet row deals sheet damage x 0.57, scaled exactly once.
## Catches a sheet number that was scaled twice (x 0.325) or not at all.
extends GutTest

const SHEET: String = "res://docs/design/balance/weapons.csv"
const SCALE: float = 0.57
## Prototype ids whose sheet row has a design name.
const ALIASES: Dictionary = {&"rifle_ar": &"vanguard_ar"}
## Known prototype mismatches listed in docs/design/balance/sync.csv, not scaled yet.
const NOT_SYNCED: Array[StringName] = [&"pistol_service"]


func _sheet_damage() -> Dictionary:
	var damage: Dictionary = {}
	var file: FileAccess = FileAccess.open(SHEET, FileAccess.READ)
	assert_not_null(file, "balance sheet copy is readable")
	if file == null:
		return damage
	var header: PackedStringArray = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 0 and row[0] == "id":
			header = row
		elif not header.is_empty() and row.size() == header.size() and row[0] != "":
			damage[StringName(row[0])] = float(row[header.find("Damage / pellet")])
	return damage


func test_gun_damage_is_the_sheet_scaled_once() -> void:
	var sheet: Dictionary = _sheet_damage()
	var checked: int = 0
	for path: String in DirAccess.get_files_at("res://content/weapons"):
		if not path.ends_with(".tres") or path.contains("_reforged"):
			continue
		var gun: WeaponData = load("res://content/weapons/" + path) as WeaponData
		var row: StringName = ALIASES.get(gun.id, gun.id)
		if not sheet.has(row) or gun.id in NOT_SYNCED:
			continue
		var expected: float = float(sheet[row]) * SCALE
		assert_almost_eq(gun.damage, expected, expected * 0.02, "%s: sheet %s x 0.57" % [gun.id, sheet[row]])
		checked += 1
	assert_gte(checked, 4, "AR, Brenner, Kestrel and Talon at least are checked against the sheet")
