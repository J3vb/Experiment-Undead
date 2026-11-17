## A personal, silent interactable. Only its owner can move the item into their Pack.
class_name LootDrop
extends Interactable

const LIFETIME: float = 60.0
const HEIGHTS: Array[float] = [0.0, 1.0, 1.5, 2.0, 2.5, 3.0]

var item: Dictionary = {}
var pack: Pack
var player: Player

@onready var lifetime: Timer = $Lifetime


func _ready() -> void:
	super()
	lifetime.start(LIFETIME)
	lifetime.timeout.connect(queue_free)
	var rarity: StringName = StringName(item.get("rar", "common"))
	var data: RarityData = Content.get_item(&"loot", rarity) as RarityData
	var rank: int = maxi(ItemRoller.RARITIES.find(rarity), 0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = data.colour
	material.emission_enabled = true
	material.emission = data.colour
	material.emission_energy_multiplier = 2.0
	($Ring as MeshInstance3D).material_override = material
	var pillar: MeshInstance3D = $Pillar
	pillar.visible = rank > 0
	pillar.scale.y = maxf(HEIGHTS[rank], 0.01)
	pillar.position.y = HEIGHTS[rank] / 2.0
	pillar.material_override = material


func get_prompt(viewer: Player) -> String:
	if viewer != player or not _can_reach(viewer):
		return ""
	if pack.is_full():
		return "Pack full"
	return (
		"%s · %s · iLvl %d [F]" % [item_name(item), String(item.get("rar", "common")).capitalize(), item.get("ilvl", 1)]
	)


func interact(viewer: Player, _facts: Dictionary = {}) -> void:
	if viewer != player or is_queued_for_deletion() or not _can_reach(viewer):
		return
	if pack.add(item):
		viewer.focus = null
		queue_free()


func is_local() -> bool:
	return true


func _can_reach(viewer: Player) -> bool:
	return (
		is_instance_valid(viewer)
		and viewer.is_alive()
		and not viewer.is_downed
		and viewer.global_position.distance_to(global_position) <= viewer.interact_range
		and (viewer.session == null or not viewer.session.is_over)
	)


static func item_name(data: Dictionary) -> String:
	var base: StringName = StringName(data.get("base", ""))
	if Content.ids(&"weapons").has(base):
		return Content.weapon(base).display_name
	if Content.ids(&"loot").has(base):
		var gear: GearBaseData = Content.get_item(&"loot", base) as GearBaseData
		if gear:
			return gear.display_name
	return String(base).capitalize()
