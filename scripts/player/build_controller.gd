class_name BuildController
extends Node
## Điều khiển xây dựng: bắn tia từ camera đang dùng, xác định mục tiêu và thao tác phù hợp.
##
## KHÔNG phụ thuộc vào nhân vật: chỉ cần có một Camera3D đang active (xem docs/08-nhan-vat.md).
## Chế độ Xây dựng tự chọn việc theo thứ nhắm vào: đào → đổ móng → xây gạch → lắp cửa →
## xây tường hồi → lợp mái → trát → lát nền.

signal mode_changed(mode: int)
signal selection_changed(item_id: String)
signal hint_changed(text: String)
signal action_done(result: int, action: String)

enum Mode { BUILD, PAINT, FURNITURE, REMOVE }

const MODE_NAMES := ["Xây dựng", "Sơn tường", "Nội thất", "Nhặt đồ"]
const REACH := 7.0
const INTERACT_REACH := 3.5
const PLASTER_PER_STEP := 0.6
const PAINT_PER_STEP := 0.9
## Thời gian lặp khi giữ chuột (giây) cho từng loại thao tác.
const REPEAT := {
	"dig": 0.22, "pour": 0.28, "brick": 0.1, "gable": 0.1, "opening": 0.6, "roof": 0.14,
	"roof_cell": 0.28, "plaster": 0.1, "paint": 0.1, "floor": 0.2, "furniture": 0.4, "remove": 0.4,
}
const R = ConstructionProject.Result

var mode: Mode = Mode.BUILD
var paint_item := "paint_white"
var furniture_item := ""
## Mục tiêu đang nhắm (kết quả HouseView.describe_hit, hoặc vật tương tác), {} nếu không có.
var current: Dictionary = {}
var hint := ""
var placement: PlacementController

var _cooldown := 0.0
var _last_toast := ""
var _last_toast_ms := -100000


func _ready() -> void:
	placement = PlacementController.new()
	placement.name = "Placement"
	add_child(placement)
	GameState.inventory_changed.connect(_on_inventory_changed)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if GameState.is_input_blocked():
		placement.hide_ghost()
		_set_hint("")
		return
	scan()
	if Input.is_action_pressed("primary") and _cooldown <= 0.0 and not current_action().is_empty():
		var action := current_action()
		var result := perform_primary()
		_cooldown = REPEAT.get(action, 0.25) if result == R.OK else 0.4


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_input_blocked():
		return
	if event.is_action_pressed("tool_1"):
		set_mode(Mode.BUILD)
	elif event.is_action_pressed("tool_2"):
		set_mode(Mode.PAINT)
	elif event.is_action_pressed("tool_3"):
		set_mode(Mode.FURNITURE)
	elif event.is_action_pressed("tool_4"):
		set_mode(Mode.REMOVE)
	elif event.is_action_pressed("cycle_next"):
		cycle_selection(1)
	elif event.is_action_pressed("cycle_prev"):
		cycle_selection(-1)
	elif event.is_action_pressed("rotate"):
		placement.rotate_step()
	elif event.is_action_pressed("interact"):
		interact()


# ─── Chế độ và lựa chọn ─────────────────────────────────────────────────────

func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if mode == Mode.FURNITURE and not GameState.inventory.has(furniture_item):
		furniture_item = _owned_furniture().front() if not _owned_furniture().is_empty() else ""
	mode_changed.emit(mode)
	selection_changed.emit(selected_item())


## Mã vật phẩm đang chọn trong chế độ hiện tại ("" nếu chế độ không cần chọn).
func selected_item() -> String:
	match mode:
		Mode.PAINT:
			return paint_item
		Mode.FURNITURE:
			return furniture_item
	return ""


## Đổi màu sơn / món nội thất đang chọn (step = +1 hoặc −1).
func cycle_selection(step: int) -> void:
	var options: Array[String] = []
	if mode == Mode.PAINT:
		options = Catalog.paint_ids()
	elif mode == Mode.FURNITURE:
		options = _owned_furniture()
	if options.is_empty():
		return
	var index := options.find(selected_item())
	var next := options[posmod(index + step, options.size())]
	if mode == Mode.PAINT:
		paint_item = next
	else:
		furniture_item = next
	selection_changed.emit(next)


func _owned_furniture() -> Array[String]:
	var out: Array[String] = []
	for id in Catalog.furniture_ids():
		if GameState.inventory.has(id):
			out.append(id)
	return out


func _on_inventory_changed(_item_id: String, _count: int) -> void:
	if mode == Mode.FURNITURE and not GameState.inventory.has(furniture_item):
		var owned := _owned_furniture()
		furniture_item = owned.front() if not owned.is_empty() else ""
		selection_changed.emit(furniture_item)


# ─── Nhắm và thao tác ───────────────────────────────────────────────────────

## Bắn tia từ camera đang active, cập nhật `current`, bóng mờ nội thất và dòng gợi ý.
func scan() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		current = {}
		return
	var from := cam.global_position
	var hit := _raycast(from, from - cam.global_transform.basis.z * REACH, _mask_for_mode())
	current = _describe(hit)
	if mode == Mode.FURNITURE:
		placement.update(hit, current, furniture_item)
	else:
		placement.hide_ghost()
	_set_hint(_hint_for(current))


## Tên thao tác sẽ làm khi bấm chuột trái vào mục tiêu hiện tại ("" nếu không có).
func current_action() -> String:
	var info := current
	var kind: String = info.get("kind", "")
	match mode:
		Mode.BUILD:
			var house: HouseView = info.get("house")
			if house == null:
				return ""
			var p := house.project
			match kind:
				"foundation":
					return "pour" if p.dig.is_done(info["cell"]) else "dig"
				"slab":
					var cell: Vector2i = info["cell"]
					return "floor" if p.floor_tiles.has_cell(cell) and not p.floor_tiles.is_done(cell) else ""
				"wall":
					return "brick"
				"gable":
					return "gable"
				"wall_built":
					return "plaster" if p.plaster[info["index"]][info["side"]] < 1.0 else ""
				"opening":
					return "opening"
				"roof":
					return "roof"
				"roof_slab":
					return "roof_cell"
		Mode.PAINT:
			return "paint" if kind == "wall_built" else ""
		Mode.FURNITURE:
			return "furniture" if placement.house != null else ""
		Mode.REMOVE:
			return "remove" if kind == "furniture" else ""
	return ""


## Thực hiện thao tác chính lên mục tiêu hiện tại. Trả về ConstructionProject.Result (−1 nếu không có gì để làm).
func perform_primary() -> int:
	var action := current_action()
	if action.is_empty():
		return -1
	var info := current
	var p: ConstructionProject = (info["house"] as HouseView).project if info.has("house") else null
	var result := -1
	match action:
		"dig":
			result = p.dig_cell(info["cell"])
		"pour":
			result = p.pour_cell(info["cell"])
		"floor":
			result = p.tile_floor(info["cell"])
		"brick":
			result = p.lay_brick(info["index"])
		"gable":
			result = p.lay_gable_brick(info["index"])
		"plaster":
			result = p.apply_plaster(info["index"], info["side"], PLASTER_PER_STEP)
		"opening":
			result = p.install_opening(info["index"])
		"roof":
			result = p.lay_roof_piece()
		"roof_cell":
			result = p.pour_roof_cell(info["cell"])
		"paint":
			result = p.apply_paint(info["index"], info["side"], paint_item, PAINT_PER_STEP)
		"furniture":
			result = placement.place()
			if result == R.INVALID and not placement.reason.is_empty():
				_toast(placement.reason, "warn")
		"remove":
			result = p.remove_furniture(info["uid"])
	if result != R.OK and result != R.DONE:
		_explain(result, action, info)
	_set_hint(_hint_for(current))  # cập nhật ngay số liệu vừa đổi (vd. số viên đã xây)
	action_done.emit(result, action)
	return result


## Tương tác (phím E): mở/đóng cửa, bảng hợp đồng, cửa hàng, bàn vẽ.
func interact() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var from := cam.global_position
	var hit := _raycast(from, from - cam.global_transform.basis.z * INTERACT_REACH,
			Colliders.WORLD | Colliders.INTERACTABLE | Colliders.FURNITURE)
	if hit.is_empty():
		return false
	var collider: Object = hit["collider"]
	match str(collider.get_meta("kind", "")):
		"door":
			var house: HouseView = collider.get_meta("house")
			house.opening_view(int(collider.get_meta("index"))).toggle_door()
			return true
		"job_board":
			GameState.panel_requested.emit("contracts")
			return true
		"shop":
			GameState.panel_requested.emit("shop")
			return true
		"drawing_table":
			GameState.panel_requested.emit("blueprint")
			return true
	return false


# ─── Gợi ý và thông báo ─────────────────────────────────────────────────────

func _hint_for(info: Dictionary) -> String:
	var kind: String = info.get("kind", "")
	match kind:
		"door":
			return "[E] Mở / đóng cửa"
		"job_board":
			return "[E] Xem bảng hợp đồng"
		"shop":
			return "[E] Mua vật liệu"
		"drawing_table":
			return "[E] Mở bàn vẽ"
	if mode == Mode.FURNITURE:
		if placement.valid:
			return "Đặt %s  —  [R] xoay, [lăn chuột] đổi món" % Catalog.item_name(furniture_item)
		return placement.reason
	var action := current_action()
	if action.is_empty():
		if mode == Mode.REMOVE:
			return "Nhắm vào món nội thất để nhặt về kho"
		if mode == Mode.PAINT:
			return "Nhắm vào tường đã trát để sơn (%s)" % Catalog.item_name(paint_item)
		return ""
	var p := (info["house"] as HouseView).project
	var inv := GameState.inventory
	match action:
		"dig":
			return "Đào móng — còn %d ô" % p.dig.remaining()
		"pour":
			return "Đổ móng (2 bao xi măng/ô) — còn %d ô, kho: %d bao" % [p.pour.remaining(), inv.count("cement")]
		"brick":
			var w: int = info["index"]
			return "Xây tường %d: %d/%d viên — kho: %d gạch" % [w + 1, p.bricks[w],
					p.walls[w].layout.slot_count(), inv.count("brick")]
		"gable":
			var g: int = info["index"]
			return "Xây tường hồi: %d/%d viên — kho: %d gạch" % [p.gable_bricks[g],
					p.roof.gables[g].layout.slot_count(), inv.count("brick")]
		"plaster":
			return "Trát tường (%s): %d%%" % [_side_name(p, info), roundi(p.plaster[info["index"]][info["side"]] * 100)]
		"opening":
			var item := str(p.blueprint.opening_type(info["index"]).get("item", ""))
			return "Lắp %s — kho: %d" % [Catalog.item_name(item), inv.count(item)]
		"roof":
			var item := p.next_roof_item()
			return "Lợp mái: %s (%d/%d) — kho: %d" % [Catalog.item_name(item), p.roof_laid,
					p.roof.piece_count(), inv.count(item)]
		"roof_cell":
			return "Đổ mái bằng — còn %d ô, kho: %d bao xi măng" % [p.roof_cells.remaining(), inv.count("cement")]
		"floor":
			return "Lát nền — còn %d ô, kho: %d" % [p.floor_tiles.remaining(), inv.count("floor_tile")]
		"paint":
			return "Sơn %s (%s): %d%% — kho: %d thùng" % [Catalog.item_name(paint_item), _side_name(p, info),
					roundi(p.paint_progress[info["index"]][info["side"]] * 100), inv.count(paint_item)]
		"remove":
			var f := p.find_furniture(info["uid"])
			return "Nhặt %s về kho" % Catalog.item_name(str(f.get("id", "")))
	return ""


func _side_name(p: ConstructionProject, info: Dictionary) -> String:
	return "mặt trong" if p.analysis.side_is_interior(info["index"], info["side"]) else "mặt ngoài"


## Giải thích vì sao thao tác không thành công.
func _explain(result: int, action: String, info: Dictionary) -> void:
	if result == R.NO_MATERIAL:
		var item := _material_for(action, info)
		_toast("Thiếu %s — mua ở cửa hàng (phím B)." % Catalog.item_name(item), "error")
		return
	if result != R.LOCKED:
		return
	var p := (info["house"] as HouseView).project
	var text := "Chưa làm được bước này."
	match action:
		"pour":
			text = "Hãy đào ô này trước khi đổ bê tông."
		"brick":
			text = "Cần đổ xong toàn bộ móng trước (còn %d ô)." % p.pour.remaining()
		"gable", "roof_cell", "floor":
			text = "Cần xây xong toàn bộ tường trước."
		"roof":
			text = "Cần xây xong tường và hai tường hồi trước."
		"opening", "plaster":
			text = "Cần xây xong bức tường này trước."
		"paint":
			text = "Cần trát xong mặt tường này trước."
	_toast(text, "warn")


func _material_for(action: String, info: Dictionary) -> String:
	var p := (info["house"] as HouseView).project
	match action:
		"pour", "roof_cell", "plaster":
			return "cement"
		"brick", "gable":
			return "brick"
		"opening":
			return str(p.blueprint.opening_type(info["index"]).get("item", ""))
		"roof":
			return p.next_roof_item()
		"floor":
			return "floor_tile"
		"paint":
			return paint_item
		"furniture":
			return furniture_item
	return ""


func _toast(text: String, kind: String) -> void:
	var now := Time.get_ticks_msec()
	if text == _last_toast and now - _last_toast_ms < 1500:
		return
	_last_toast = text
	_last_toast_ms = now
	GameState.notify(text, kind)


func _set_hint(text: String) -> void:
	if text != hint:
		hint = text
		hint_changed.emit(text)


func _mask_for_mode() -> int:
	match mode:
		Mode.BUILD:
			return Colliders.WORLD | Colliders.BLUEPRINT | Colliders.FURNITURE | Colliders.INTERACTABLE
	return Colliders.WORLD | Colliders.FURNITURE | Colliders.INTERACTABLE


func _raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)


func _describe(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {}
	var collider: Object = hit["collider"]
	var house: Variant = collider.get_meta("house", null)
	if house is HouseView:
		return (house as HouseView).describe_hit(collider, hit["position"], hit["normal"])
	if collider.has_meta("kind"):
		return {"kind": str(collider.get_meta("kind")), "pos": hit["position"]}
	return {"kind": "world", "pos": hit["position"]}
