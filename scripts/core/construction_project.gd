class_name ConstructionProject
extends RefCounted
## Một công trình đang thi công trên lô đất: bản vẽ + tiến độ từng hạng mục.
## Toàn bộ luật thi công nằm ở đây, không phụ thuộc scene, nên test được hết.
## Xem docs/04-thi-cong.md.

## Có thay đổi tiến độ. kind: "dig", "pour", "brick", "gable", "opening", "roof",
## "roof_cell", "plaster", "paint", "floor", "furniture".
signal changed(kind: String, index: int)
## Một giai đoạn vừa chuyển sang DONE.
signal stage_completed(stage_id: String)

enum Result { OK, LOCKED, DONE, NO_MATERIAL, INVALID }
enum Status { LOCKED, AVAILABLE, DONE }

const STAGES := [
	{"id": "excavation", "name": "Đào móng", "requires": []},
	{"id": "foundation", "name": "Đổ móng", "requires": ["excavation"]},
	{"id": "walls", "name": "Xây tường", "requires": ["foundation"]},
	{"id": "openings", "name": "Lắp cửa", "requires": ["walls"]},
	{"id": "roof", "name": "Lợp mái", "requires": ["walls"]},
	{"id": "plaster", "name": "Trát tường", "requires": ["walls"]},
	{"id": "paint", "name": "Sơn tường", "requires": ["plaster"]},
	{"id": "floor", "name": "Lát nền", "requires": ["walls"]},
	{"id": "furnish", "name": "Nội thất", "requires": ["openings", "roof", "paint", "floor"]},
]

var plot_id := ""
var blueprint: Blueprint
var analysis: BlueprintAnalysis
var walls: Array[WallGeometry] = []
## Mái ngói; null nếu là mái bằng.
var roof: RoofLayout
var inventory: Inventory
## Nội thất bắt buộc theo hợp đồng: mã → số lượng.
var required_furniture: Dictionary = {}

var dig: CellProgress
var pour: CellProgress
var floor_tiles: CellProgress
## Chỉ có ô khi là mái bằng.
var roof_cells: CellProgress
var bricks := PackedInt32Array()
var gable_bricks := PackedInt32Array()
var openings_done: Array[bool] = []
var roof_laid := 0
## [tường] → [tiến độ mặt 0, tiến độ mặt 1], mỗi giá trị 0..1.
var plaster: Array = []
## [tường] → [mã sơn mặt 0, mặt 1]; "" là chưa sơn.
var paint_color: Array = []
var paint_progress: Array = []
## Mỗi món: {"uid": int, "id": String, "pos": Vector3 (toạ độ lô đất), "yaw": float (radian)}.
var furniture: Array[Dictionary] = []
var last_furniture_uid := 0

var _next_uid := 1
var _graph := StageGraph.new()
var _done_cache: Dictionary = {}


func _init(p_blueprint: Blueprint = null, p_inventory: Inventory = null, p_plot_id := "") -> void:
	blueprint = p_blueprint if p_blueprint != null else Blueprint.new()
	inventory = p_inventory if p_inventory != null else Inventory.new()
	plot_id = p_plot_id
	analysis = BlueprintAnalysis.new(blueprint)
	walls = WallGeometry.build_for_blueprint(blueprint)
	var cells := analysis.interior_cells
	dig = CellProgress.new(cells)
	pour = CellProgress.new(cells)
	floor_tiles = CellProgress.new(cells)
	if blueprint.roof == "gable" and analysis.is_rectangular():
		roof = RoofLayout.new(analysis.bounds, wall_top())
		gable_bricks.resize(roof.gables.size())
		roof_cells = CellProgress.new()
	else:
		roof_cells = CellProgress.new(cells)
	bricks.resize(walls.size())
	openings_done.resize(blueprint.openings.size())
	for w in walls.size():
		plaster.append([0.0, 0.0])
		paint_color.append(["", ""])
		paint_progress.append([0.0, 0.0])
	for s: Dictionary in STAGES:
		_graph.add_stage(s["id"], s["requires"])
	_refresh_done_cache()


func wall_top() -> float:
	return BuildConst.FOUNDATION_TOP + blueprint.wall_height


func is_flat_roof() -> bool:
	return roof == null


static func stage_name(stage: String) -> String:
	for s: Dictionary in STAGES:
		if s["id"] == stage:
			return s["name"]
	return stage


static func result_text(r: Result) -> String:
	match r:
		Result.OK:
			return "Xong"
		Result.LOCKED:
			return "Chưa làm được bước này"
		Result.DONE:
			return "Phần này đã làm xong"
		Result.NO_MATERIAL:
			return "Thiếu vật tư"
	return "Không hợp lệ"


static func roof_item_for(kind: RoofLayout.Piece) -> String:
	match kind:
		RoofLayout.Piece.TRUSS:
			return "roof_truss"
		RoofLayout.Piece.TILE:
			return "roof_tile"
	return "ridge_tile"


# ─── Trạng thái giai đoạn ────────────────────────────────────────────────────

## Thứ tự các giai đoạn (sắp xếp topo) để hiển thị checklist.
func stage_order() -> Array[String]:
	return _graph.topological_order()


func stage_status(stage: String) -> Status:
	for req in _graph.requires(stage):
		if stage_status(req) != Status.DONE:
			return Status.LOCKED
	return Status.DONE if stage_predicate(stage) else Status.AVAILABLE


## Điều kiện "đã làm xong phần việc" của giai đoạn (chưa xét phụ thuộc).
func stage_predicate(stage: String) -> bool:
	match stage:
		"excavation":
			return dig.is_complete()
		"foundation":
			return pour.is_complete()
		"walls":
			return are_walls_done()
		"openings":
			return not openings_done.has(false)
		"roof":
			return is_roof_done()
		"plaster":
			return _sides_done(plaster)
		"paint":
			return _sides_done(paint_progress)
		"floor":
			return floor_tiles.is_complete()
		"furnish":
			return missing_furniture().is_empty()
	return false


## Tiến độ 0..1 của giai đoạn (cho thanh tiến độ trên HUD).
func stage_progress(stage: String) -> float:
	match stage:
		"excavation":
			return dig.progress()
		"foundation":
			return pour.progress()
		"walls":
			var laid := 0
			var total := 0
			for w in walls.size():
				laid += bricks[w]
				total += walls[w].layout.slot_count()
			return _ratio(laid, total)
		"openings":
			return _ratio(openings_done.count(true), openings_done.size())
		"roof":
			if roof == null:
				return roof_cells.progress()
			var done := roof_laid
			var total := roof.piece_count()
			for g in roof.gables.size():
				done += gable_bricks[g]
				total += roof.gables[g].layout.slot_count()
			return _ratio(done, total)
		"plaster":
			return _sides_average(plaster)
		"paint":
			return _sides_average(paint_progress)
		"floor":
			return floor_tiles.progress()
		"furnish":
			var need := 0
			var have := 0
			for item_id: String in required_furniture:
				var n := int(required_furniture[item_id])
				need += n
				have += mini(n, furniture_inside(item_id))
			return _ratio(have, need)
	return 0.0


func is_complete() -> bool:
	for s: Dictionary in STAGES:
		if stage_status(s["id"]) != Status.DONE:
			return false
	return true


func is_wall_done(w: int) -> bool:
	return w >= 0 and w < walls.size() and bricks[w] >= walls[w].layout.slot_count()


func are_walls_done() -> bool:
	for w in walls.size():
		if not is_wall_done(w):
			return false
	return true


func is_gable_done(g: int) -> bool:
	return roof != null and gable_bricks[g] >= roof.gables[g].layout.slot_count()


func are_gables_done() -> bool:
	if roof == null:
		return true
	for g in roof.gables.size():
		if not is_gable_done(g):
			return false
	return true


func is_roof_done() -> bool:
	if roof == null:
		return roof_cells.is_complete()
	return are_gables_done() and roof_laid >= roof.piece_count()


# ─── Thao tác thi công ──────────────────────────────────────────────────────

func dig_cell(c: Vector2i) -> Result:
	if not dig.has_cell(c):
		return Result.INVALID
	if dig.is_done(c):
		return Result.DONE
	dig.mark(c)
	_after_change("dig", dig.index_of(c))
	return Result.OK


func pour_cell(c: Vector2i) -> Result:
	if not pour.has_cell(c):
		return Result.INVALID
	if pour.is_done(c):
		return Result.DONE
	if not dig.is_done(c):
		return Result.LOCKED
	if not _consume("cement", BuildConst.CEMENT_PER_FOUNDATION_CELL):
		return Result.NO_MATERIAL
	pour.mark(c)
	_after_change("pour", pour.index_of(c))
	return Result.OK


func lay_brick(w: int) -> Result:
	if w < 0 or w >= walls.size():
		return Result.INVALID
	if is_wall_done(w):
		return Result.DONE
	if not pour.is_complete():
		return Result.LOCKED
	if not _consume("brick", 1):
		return Result.NO_MATERIAL
	bricks[w] += 1
	_after_change("brick", w)
	return Result.OK


func lay_gable_brick(g: int) -> Result:
	if roof == null or g < 0 or g >= roof.gables.size():
		return Result.INVALID
	if is_gable_done(g):
		return Result.DONE
	if not are_walls_done():
		return Result.LOCKED
	if not _consume("brick", 1):
		return Result.NO_MATERIAL
	gable_bricks[g] += 1
	_after_change("gable", g)
	return Result.OK


func install_opening(k: int) -> Result:
	if k < 0 or k >= openings_done.size():
		return Result.INVALID
	if openings_done[k]:
		return Result.DONE
	if not is_wall_done(int(blueprint.openings[k]["wall"])):
		return Result.LOCKED
	var item: String = blueprint.opening_type(k).get("item", "")
	if item.is_empty():
		return Result.INVALID
	if not _consume(item, 1):
		return Result.NO_MATERIAL
	openings_done[k] = true
	_after_change("opening", k)
	return Result.OK


## Vật tư cho mảnh mái kế tiếp; "" nếu đã lợp xong hoặc là mái bằng.
func next_roof_item() -> String:
	if roof == null or roof_laid >= roof.piece_count():
		return ""
	return roof_item_for(roof.piece_kind(roof_laid))


func lay_roof_piece() -> Result:
	if roof == null:
		return Result.INVALID
	if roof_laid >= roof.piece_count():
		return Result.DONE
	if not are_walls_done() or not are_gables_done():
		return Result.LOCKED
	if not _consume(next_roof_item(), 1):
		return Result.NO_MATERIAL
	roof_laid += 1
	_after_change("roof", roof_laid - 1)
	return Result.OK


func pour_roof_cell(c: Vector2i) -> Result:
	if roof != null or not roof_cells.has_cell(c):
		return Result.INVALID
	if roof_cells.is_done(c):
		return Result.DONE
	if not are_walls_done():
		return Result.LOCKED
	if not _consume("cement", BuildConst.CEMENT_PER_ROOF_CELL):
		return Result.NO_MATERIAL
	roof_cells.mark(c)
	_after_change("roof_cell", roof_cells.index_of(c))
	return Result.OK


func plaster_cement_needed(w: int) -> int:
	return maxi(1, ceili(walls[w].side_area() / BuildConst.PLASTER_M2_PER_CEMENT - 0.0001))


func paint_cans_needed(w: int) -> int:
	return maxi(1, ceili(walls[w].side_area() / BuildConst.PAINT_M2_PER_CAN - 0.0001))


## Trát thêm `area_m2` lên mặt `side` của tường w.
## Xi măng cho cả mặt được trừ một lần khi bắt đầu trát mặt đó.
func apply_plaster(w: int, side: int, area_m2: float) -> Result:
	if w < 0 or w >= walls.size() or side < 0 or side > 1:
		return Result.INVALID
	var current: float = plaster[w][side]
	if current >= 1.0:
		return Result.DONE
	if not is_wall_done(w):
		return Result.LOCKED
	if current <= 0.0 and not _consume("cement", plaster_cement_needed(w)):
		return Result.NO_MATERIAL
	plaster[w][side] = clampf(current + area_m2 / maxf(walls[w].side_area(), 0.01), 0.001, 1.0)
	_after_change("plaster", w * 2 + side)
	return Result.OK


## Sơn thêm `area_m2` màu `color_item` lên mặt `side` của tường w (mặt đó phải trát xong).
## Đổi sang màu khác thì sơn lại từ đầu và tốn sơn mới.
func apply_paint(w: int, side: int, color_item: String, area_m2: float) -> Result:
	if w < 0 or w >= walls.size() or side < 0 or side > 1 or color_item.is_empty():
		return Result.INVALID
	if plaster[w][side] < 1.0:
		return Result.LOCKED
	var same_color: bool = paint_color[w][side] == color_item
	var current: float = paint_progress[w][side]
	if same_color and current >= 1.0:
		return Result.DONE
	if not same_color or current <= 0.0:
		if not _consume(color_item, paint_cans_needed(w)):
			return Result.NO_MATERIAL
		paint_color[w][side] = color_item
		current = 0.0
	paint_progress[w][side] = clampf(current + area_m2 / maxf(walls[w].side_area(), 0.01), 0.001, 1.0)
	_after_change("paint", w * 2 + side)
	return Result.OK


func tile_floor(c: Vector2i) -> Result:
	if not floor_tiles.has_cell(c):
		return Result.INVALID
	if floor_tiles.is_done(c):
		return Result.DONE
	if not are_walls_done():
		return Result.LOCKED
	if not _consume("floor_tile", 1):
		return Result.NO_MATERIAL
	floor_tiles.mark(c)
	_after_change("floor", floor_tiles.index_of(c))
	return Result.OK


func can_furnish() -> bool:
	return stage_status("furnish") != Status.LOCKED


## Đặt một món nội thất (vị trí đã được PlacementController kiểm tra va chạm).
## Thành công thì uid của món mới nằm ở `last_furniture_uid`.
func place_furniture(item_id: String, pos: Vector3, yaw: float) -> Result:
	if item_id.is_empty():
		return Result.INVALID
	if not can_furnish():
		return Result.LOCKED
	if not _consume(item_id, 1):
		return Result.NO_MATERIAL
	last_furniture_uid = _next_uid
	_next_uid += 1
	furniture.append({"uid": last_furniture_uid, "id": item_id, "pos": pos, "yaw": yaw})
	_after_change("furniture", last_furniture_uid)
	return Result.OK


## Nhặt nội thất lên: món đồ quay về kho.
func remove_furniture(uid: int) -> Result:
	for i in furniture.size():
		if int(furniture[i]["uid"]) == uid:
			inventory.add(str(furniture[i]["id"]), 1)
			furniture.remove_at(i)
			_after_change("furniture", uid)
			return Result.OK
	return Result.INVALID


func find_furniture(uid: int) -> Dictionary:
	for f in furniture:
		if int(f["uid"]) == uid:
			return f
	return {}


## Số món `item_id` đang đặt TRONG nhà.
func furniture_inside(item_id: String) -> int:
	var n := 0
	for f in furniture:
		if f["id"] == item_id and analysis.is_interior(BlueprintAnalysis.cell_at(f["pos"])):
			n += 1
	return n


func missing_furniture() -> Dictionary:
	var out := {}
	for item_id: String in required_furniture:
		var lack := int(required_furniture[item_id]) - furniture_inside(item_id)
		if lack > 0:
			out[item_id] = lack
	return out


## Vật tư cần cho toàn bộ phần việc còn lại: mã → số lượng.
## Sơn cho các mặt chưa sơn được tính theo mã sơn `paint_item`.
func remaining_materials(paint_item := "paint_white") -> Dictionary:
	var need := {}
	_add(need, "cement", pour.remaining() * BuildConst.CEMENT_PER_FOUNDATION_CELL)
	var brick_left := 0
	for w in walls.size():
		brick_left += walls[w].layout.slot_count() - bricks[w]
	if roof != null:
		for g in roof.gables.size():
			brick_left += roof.gables[g].layout.slot_count() - gable_bricks[g]
		for i in range(roof_laid, roof.piece_count()):
			_add(need, roof_item_for(roof.piece_kind(i)), 1)
	else:
		_add(need, "cement", roof_cells.remaining() * BuildConst.CEMENT_PER_ROOF_CELL)
	_add(need, "brick", brick_left)
	for k in openings_done.size():
		if not openings_done[k]:
			_add(need, str(blueprint.opening_type(k).get("item", "")), 1)
	for w in walls.size():
		for side in 2:
			if plaster[w][side] <= 0.0:
				_add(need, "cement", plaster_cement_needed(w))
			if paint_progress[w][side] <= 0.0:
				_add(need, paint_item, paint_cans_needed(w))
	_add(need, "floor_tile", floor_tiles.remaining())
	var missing := missing_furniture()
	for item_id: String in missing:
		_add(need, item_id, missing[item_id])
	return need


# ─── Lưu / tải ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	var furn := []
	for f in furniture:
		var p: Vector3 = f["pos"]
		furn.append({"uid": f["uid"], "id": f["id"], "pos": [p.x, p.y, p.z], "yaw": f["yaw"]})
	return {
		"plot": plot_id,
		"blueprint": blueprint.to_dict(),
		"required_furniture": required_furniture.duplicate(),
		"dig": dig.to_array(),
		"pour": pour.to_array(),
		"floor": floor_tiles.to_array(),
		"roof_cells": roof_cells.to_array(),
		"bricks": Array(bricks),
		"gable_bricks": Array(gable_bricks),
		"openings": openings_done.duplicate(),
		"roof_laid": roof_laid,
		"plaster": plaster.duplicate(true),
		"paint_color": paint_color.duplicate(true),
		"paint_progress": paint_progress.duplicate(true),
		"furniture": furn,
		"next_uid": _next_uid,
	}


## Dựng lại công trình từ dữ liệu lưu. Mọi giá trị bị kẹp vào khoảng hợp lệ,
## nên file lưu bị sửa tay cũng không làm hỏng game. Không trừ vật tư trong kho.
static func from_dict(data: Dictionary, p_inventory: Inventory) -> ConstructionProject:
	var bp := Blueprint.from_dict(DataUtil.to_dict(data.get("blueprint")))
	var p := ConstructionProject.new(bp, p_inventory, str(data.get("plot", "")))
	var req := DataUtil.to_dict(data.get("required_furniture"))
	for key: Variant in req:
		var n := DataUtil.to_int(req[key])
		if n > 0:
			p.required_furniture[str(key)] = n
	p.dig.load_array(data.get("dig"))
	p.pour.load_array(data.get("pour"))
	for c in p.pour.order:
		p.dig.mark(c)  # ô đã đổ thì chắc chắn đã đào
	p.floor_tiles.load_array(data.get("floor"))
	p.roof_cells.load_array(data.get("roof_cells"))
	var saved_bricks := DataUtil.to_array(data.get("bricks"))
	for w in mini(saved_bricks.size(), p.walls.size()):
		p.bricks[w] = clampi(DataUtil.to_int(saved_bricks[w]), 0, p.walls[w].layout.slot_count())
	if p.roof != null:
		var saved_gables := DataUtil.to_array(data.get("gable_bricks"))
		for g in mini(saved_gables.size(), p.roof.gables.size()):
			p.gable_bricks[g] = clampi(DataUtil.to_int(saved_gables[g]), 0,
					p.roof.gables[g].layout.slot_count())
		p.roof_laid = clampi(DataUtil.to_int(data.get("roof_laid")), 0, p.roof.piece_count())
	var saved_openings := DataUtil.to_array(data.get("openings"))
	for k in mini(saved_openings.size(), p.openings_done.size()):
		p.openings_done[k] = DataUtil.to_bool(saved_openings[k])
	_load_sides(p.plaster, data.get("plaster"))
	_load_sides(p.paint_progress, data.get("paint_progress"))
	var colors := DataUtil.to_array(data.get("paint_color"))
	for w in mini(colors.size(), p.walls.size()):
		var pair := DataUtil.to_array(colors[w])
		for side in mini(pair.size(), 2):
			p.paint_color[w][side] = pair[side] if pair[side] is String else ""
	var max_uid := 0
	for f: Variant in DataUtil.to_array(data.get("furniture")):
		var fd := DataUtil.to_dict(f)
		var pos := DataUtil.to_array(fd.get("pos"))
		var item_id := str(fd.get("id", ""))
		var uid := DataUtil.to_int(fd.get("uid"))
		if item_id.is_empty() or pos.size() != 3 or uid <= 0 or not p.find_furniture(uid).is_empty():
			continue
		p.furniture.append({
			"uid": uid,
			"id": item_id,
			"pos": Vector3(DataUtil.to_float(pos[0]), DataUtil.to_float(pos[1]), DataUtil.to_float(pos[2])),
			"yaw": DataUtil.to_float(fd.get("yaw")),
		})
		max_uid = maxi(max_uid, uid)
	p._next_uid = maxi(DataUtil.to_int(data.get("next_uid"), 1), max_uid + 1)
	p._refresh_done_cache()
	return p


# ─── Nội bộ ─────────────────────────────────────────────────────────────────

func _consume(item_id: String, amount: int) -> bool:
	return amount <= 0 or inventory.remove(item_id, amount)


func _after_change(kind: String, index: int) -> void:
	changed.emit(kind, index)
	for s: Dictionary in STAGES:
		var id: String = s["id"]
		var done := stage_status(id) == Status.DONE
		if done and not _done_cache.get(id, false):
			_done_cache[id] = true
			stage_completed.emit(id)
		elif not done:
			_done_cache[id] = false


func _refresh_done_cache() -> void:
	for s: Dictionary in STAGES:
		_done_cache[s["id"]] = stage_status(s["id"]) == Status.DONE


static func _sides_done(values: Array) -> bool:
	for pair: Array in values:
		if pair[0] < 1.0 or pair[1] < 1.0:
			return false
	return true


static func _sides_average(values: Array) -> float:
	if values.is_empty():
		return 1.0
	var total := 0.0
	for pair: Array in values:
		total += float(pair[0]) + float(pair[1])
	return total / (values.size() * 2.0)


static func _ratio(done: int, total: int) -> float:
	return 1.0 if total <= 0 else clampf(float(done) / total, 0.0, 1.0)


static func _add(need: Dictionary, item_id: String, amount: int) -> void:
	if amount > 0 and not item_id.is_empty():
		need[item_id] = int(need.get(item_id, 0)) + amount


static func _load_sides(target: Array, data: Variant) -> void:
	var saved := DataUtil.to_array(data)
	for w in mini(saved.size(), target.size()):
		var pair := DataUtil.to_array(saved[w])
		for side in mini(pair.size(), 2):
			target[w][side] = clampf(DataUtil.to_float(pair[side]), 0.0, 1.0)
