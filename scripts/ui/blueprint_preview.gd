class_name BlueprintPreview
extends Control
## Vẽ bản vẽ mặt bằng 2D kiểu "giấy xanh": lưới, ô trong nhà (tô theo phòng), tường, cửa đi, cửa sổ.
## Mặt trước lô đất (phía đường) nằm ở cạnh dưới.

const PAPER := Color(0.1, 0.22, 0.37)
const GRID := Color(1, 1, 1, 0.12)
const WALL := Color(0.95, 0.97, 1.0)
const DOOR := Color(1.0, 0.78, 0.35)
const WINDOW := Color(0.55, 0.85, 1.0)
const ROOM_COLORS := [Color(0.4, 0.8, 0.6, 0.22), Color(0.9, 0.7, 0.4, 0.22), Color(0.6, 0.6, 0.95, 0.22),
		Color(0.95, 0.5, 0.6, 0.22), Color(0.6, 0.9, 0.9, 0.22)]

var blueprint: Blueprint:
	set(value):
		blueprint = value
		_analysis = BlueprintAnalysis.new(value) if value != null else null
		queue_redraw()

## Tường đang kéo (bàn vẽ): [điểm đầu, điểm cuối] dạng Vector2i, hoặc rỗng.
var preview_wall: Array = []

var _analysis: BlueprintAnalysis


func _init() -> void:
	custom_minimum_size = Vector2(300, 300)
	clip_contents = true


## Gọi khi bản vẽ bị sửa tại chỗ (không gán lại biến blueprint).
func blueprint_changed() -> void:
	_analysis = BlueprintAnalysis.new(blueprint) if blueprint != null else null
	queue_redraw()


func cell_px() -> float:
	if blueprint == null:
		return 20.0
	return minf(size.x / (blueprint.size.x + 1.0), size.y / (blueprint.size.y + 2.0))


func grid_origin() -> Vector2:
	var c := cell_px()
	var extent := Vector2(blueprint.size.x, blueprint.size.y) * c
	return Vector2((size.x - extent.x) / 2.0, (size.y - extent.y - c) / 2.0)


func grid_to_px(p: Vector2) -> Vector2:
	return grid_origin() + p * cell_px()


func px_to_grid(p: Vector2) -> Vector2:
	return (p - grid_origin()) / cell_px()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if blueprint == null:
		return
	var c := cell_px()
	for x in blueprint.size.x + 1:
		draw_line(grid_to_px(Vector2(x, 0)), grid_to_px(Vector2(x, blueprint.size.y)), GRID, 1.0)
	for z in blueprint.size.y + 1:
		draw_line(grid_to_px(Vector2(0, z)), grid_to_px(Vector2(blueprint.size.x, z)), GRID, 1.0)
	if _analysis != null:
		for r in _analysis.rooms.size():
			var color: Color = ROOM_COLORS[r % ROOM_COLORS.size()]
			for cell: Vector2i in _analysis.rooms[r]:
				draw_rect(Rect2(grid_to_px(Vector2(cell)), Vector2(c, c)), color)
	var width := maxf(3.0, c * BuildConst.WALL_THICKNESS)
	for i in blueprint.wall_count():
		draw_line(grid_to_px(Vector2(blueprint.wall_a[i])), grid_to_px(Vector2(blueprint.wall_b[i])), WALL, width)
	for k in blueprint.openings.size():
		_draw_opening(k, width)
	if preview_wall.size() == 2:
		draw_line(grid_to_px(Vector2(preview_wall[0])), grid_to_px(Vector2(preview_wall[1])),
				UITheme.ACCENT, width)
	var font := get_theme_default_font()
	var street := grid_to_px(Vector2(blueprint.size.x / 2.0, blueprint.size.y)) + Vector2(0, c * 0.9)
	draw_string(font, street - Vector2(90, 0), "MẶT ĐƯỜNG (phía trước)", HORIZONTAL_ALIGNMENT_CENTER,
			180, 14, Color(1, 1, 1, 0.7))


func _draw_opening(k: int, width: float) -> void:
	var o: Dictionary = blueprint.openings[k]
	var w: int = o["wall"]
	if w < 0 or w >= blueprint.wall_count():
		return
	var a := Vector2(blueprint.wall_a[w])
	var dir := (Vector2(blueprint.wall_b[w]) - a).normalized()
	var u0: float = o["offset"]
	var u1 := u0 + blueprint.opening_width(k)
	var p0 := grid_to_px(a + dir * u0)
	var p1 := grid_to_px(a + dir * u1)
	draw_line(p0, p1, PAPER, width + 2.0)
	if o["type"] == "door":
		var normal := Vector2(-dir.y, dir.x)
		var leaf := p0 + normal * (p1 - p0).length()
		draw_line(p0, leaf, DOOR, 2.0)
		draw_arc(p0, (p1 - p0).length(), (p1 - p0).angle(), normal.angle(), 12, DOOR, 1.5)
	else:
		var n := Vector2(-dir.y, dir.x) * width * 0.35
		draw_line(p0 + n, p1 + n, WINDOW, 2.0)
		draw_line(p0 - n, p1 - n, WINDOW, 2.0)
