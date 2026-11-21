## Draws the circuit lines between the Research tiles: each row of a lane feeds a bus that runs
## into every tile of the next row. Green where the next tile is open, dim grey where it is locked.
class_name SkillLinks
extends Control

const GREEN: Color = Color("8dff3a")
const DIM: Color = Color("3c4a4e")
const WIDTH: float = 3.0
const ARROW: float = 9.0

## One entry per drawn link: {"from_row": Array of SkillTile, "to": SkillTile}.
var links: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## lanes: per lane, an Array of rows, each an Array of that row's SkillTiles (empty rows skipped).
func set_rows(lanes: Array) -> void:
	links.clear()
	for rows: Array in lanes:
		var previous: Array = []
		for row: Array in rows:
			if row.is_empty():
				continue
			for tile: SkillTile in row:
				if not previous.is_empty():
					links.append({"from_row": previous, "to": tile})
			previous = row
	queue_redraw()


func reachable(link: Dictionary) -> bool:
	return (link["to"] as SkillTile).state != &"locked"


func _draw() -> void:
	for link: Dictionary in links:
		var target: SkillTile = link["to"]
		var color: Color = GREEN if reachable(link) else DIM
		var end: Vector2 = _local(target.get_global_rect().position + Vector2(0, target.size.y * 0.5))
		var bus_x: float = end.x - 14.0
		for source: SkillTile in link["from_row"]:
			var start: Vector2 = _local(source.get_global_rect().end - Vector2(0, source.size.y * 0.5))
			draw_polyline(
				PackedVector2Array([start, Vector2(bus_x, start.y), Vector2(bus_x, end.y), end]), color, WIDTH
			)
		draw_colored_polygon(
			PackedVector2Array([end, end + Vector2(-ARROW, -ARROW * 0.6), end + Vector2(-ARROW, ARROW * 0.6)]), color
		)


func _local(point: Vector2) -> Vector2:
	return point - get_global_rect().position
