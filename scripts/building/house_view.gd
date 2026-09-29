class_name HouseView
extends Node3D
## Hiển thị một công trình và giữ đồng bộ với ConstructionProject qua signal.
## HouseView đặt ở gốc lô đất, nên toạ độ của mọi node con là toạ độ lô đất.
## Xem docs/04-thi-cong.md.

var project: ConstructionProject

var _dig: CellsView
var _pour: CellsView
var _floor: CellsView
var _roof_slab: CellsView
var _walls: Array[WallView] = []
var _gables: Array[WallView] = []
var _openings: Array[OpeningView] = []
var _roof: RoofView
var _furniture: Dictionary = {}
var _foundation_target: StaticBody3D
var _slab_body: StaticBody3D
## Số ô móng đã có hộp va chạm trong _slab_body (ô đổ rồi thì không bao giờ mất đi).
var _slab_shapes := 0
var _roof_slab_target: StaticBody3D


func setup(p: ConstructionProject) -> void:
	project = p
	name = "House"
	_build_cells()
	for w in p.walls.size():
		var view := WallView.new()
		add_child(view)
		view.setup(p.walls[w], w, self)
		_walls.append(view)
	if p.roof != null:
		for g in p.roof.gables.size():
			var gable := WallView.new()
			add_child(gable)
			gable.setup(p.roof.gables[g], g, self, true)
			_gables.append(gable)
		_roof = RoofView.new()
		add_child(_roof)
		_roof.setup(p.roof, self)
	for k in p.blueprint.openings.size():
		_openings.append(_build_opening(k))
	p.changed.connect(_on_changed)
	p.stage_completed.connect(_on_stage_completed)
	refresh_all()


## Đồng bộ toàn bộ (dùng khi tải game hoặc khi một giai đoạn vừa xong).
func refresh_all() -> void:
	var p := project
	_dig.refresh()
	_pour.refresh()
	_floor.set_hologram_visible(p.are_walls_done() and not p.floor_tiles.is_complete())
	_floor.refresh()
	_foundation_target.collision_layer = 0 if p.pour.is_complete() else Colliders.BLUEPRINT
	_sync_slab_body()
	for w in _walls.size():
		_walls[w].set_laid(p.bricks[w], p.pour.is_complete())
		for side in 2:
			_update_finish(w, side)
	for g in _gables.size():
		_gables[g].set_laid(p.gable_bricks[g], p.are_walls_done())
	for k in _openings.size():
		_openings[k].set_state(p.is_wall_done(int(p.blueprint.openings[k]["wall"])), p.openings_done[k])
	if _roof != null:
		_roof.set_laid(p.roof_laid, p.are_walls_done() and p.are_gables_done())
	if _roof_slab != null:
		var waiting := p.are_walls_done() and not p.roof_cells.is_complete()
		_roof_slab.set_hologram_visible(waiting)
		_roof_slab.refresh()
		_roof_slab_target.collision_layer = Colliders.BLUEPRINT if not p.roof_cells.is_complete() else 0
	_sync_furniture()


## Thông tin mục tiêu khi raycast trúng một collider của nhà này; {} nếu không phải của nhà này.
## Kết quả: {"kind", "pos" (toạ độ lô đất), "normal", "house", và tuỳ loại: "index", "uid", "cell", "side"}.
func describe_hit(collider: Object, world_pos: Vector3, world_normal: Vector3) -> Dictionary:
	if collider == null or not collider.has_meta("house") or collider.get_meta("house") != self:
		return {}
	var pos := to_local(world_pos)
	var normal := (global_transform.basis.inverse() * world_normal).normalized()
	var info := {"kind": str(collider.get_meta("kind", "")), "pos": pos, "normal": normal, "house": self}
	if collider.has_meta("index"):
		info["index"] = int(collider.get_meta("index"))
	if collider.has_meta("uid"):
		info["uid"] = int(collider.get_meta("uid"))
	match info["kind"]:
		"foundation", "slab", "roof_slab":
			info["cell"] = BlueprintAnalysis.cell_at(pos - normal * 0.02)
		"wall_built":
			info["side"] = project.walls[info["index"]].side_from_normal(normal)
	return info


func wall_view(i: int) -> WallView:
	return _walls[i]


func gable_view(i: int) -> WallView:
	return _gables[i]


func opening_view(k: int) -> OpeningView:
	return _openings[k]


func roof_view() -> RoofView:
	return _roof


func furniture_view(uid: int) -> FurnitureView:
	return _furniture.get(uid)


func cells_view(kind: String) -> CellsView:
	match kind:
		"dig":
			return _dig
		"pour":
			return _pour
		"floor":
			return _floor
	return _roof_slab


func foundation_target() -> StaticBody3D:
	return _foundation_target


func slab_body() -> StaticBody3D:
	return _slab_body


func roof_slab_target() -> StaticBody3D:
	return _roof_slab_target


func _on_changed(kind: String, index: int) -> void:
	var p := project
	match kind:
		"dig":
			_dig.refresh()
		"pour":
			_pour.refresh()
			_sync_slab_body()
		"brick":
			_walls[index].set_laid(p.bricks[index], true)
		"gable":
			_gables[index].set_laid(p.gable_bricks[index], true)
		"opening":
			_openings[index].set_state(true, true)
		"roof":
			_roof.set_laid(p.roof_laid, true)
		"roof_cell":
			_roof_slab.refresh()
		"plaster", "paint":
			@warning_ignore("integer_division")
			var w := index / 2
			_update_finish(w, index % 2)
		"floor":
			_floor.refresh()
		"furniture":
			_sync_furniture()
	# Một phần tử vừa xong có thể mở khoá việc khác mà không có giai đoạn nào hoàn thành:
	# tường xong → lắp cửa trên tường đó; tường hồi xong → bắt đầu lợp mái.
	if (kind == "brick" and p.is_wall_done(index)) or (kind == "gable" and p.is_gable_done(index)):
		refresh_all()


func _on_stage_completed(_stage: String) -> void:
	refresh_all()


func _build_cells() -> void:
	var p := project
	var top := BuildConst.FOUNDATION_TOP
	_dig = _cells_view("Dig", p.dig, _dig_transform, _dig_color, false)
	_pour = _cells_view("Foundation", p.pour, _pour_transform, _concrete_color, true)
	_floor = _cells_view("Floor", p.floor_tiles, _floor_transform, _floor_color, true)
	_foundation_target = Colliders.make_body(Colliders.BLUEPRINT, {"kind": "foundation", "house": self},
			"FoundationTarget")
	for r in RectMerge.cells_to_rects(p.dig.cells):
		Colliders.add_box_xform(_foundation_target, _slab_transform(r, 0.0, top))
	add_child(_foundation_target)
	_slab_body = Colliders.make_body(Colliders.WORLD, {"kind": "slab", "house": self}, "Slab")
	add_child(_slab_body)
	if p.is_flat_roof():
		var y0 := p.wall_top()
		_roof_slab = _cells_view("RoofSlab", p.roof_cells, _roof_slab_transform, _concrete_color, true)
		_roof_slab_target = Colliders.make_body(Colliders.BLUEPRINT, {"kind": "roof_slab", "house": self},
				"RoofSlabTarget")
		for r in RectMerge.cells_to_rects(p.roof_cells.cells):
			Colliders.add_box_xform(_roof_slab_target, _slab_transform(r, y0, y0 + 0.4))
		add_child(_roof_slab_target)


func _dig_transform(c: Vector2i) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(0.98, 0.03, 0.98)), Vector3(c.x + 0.5, 0.015, c.y + 0.5))


func _dig_color(c: Vector2i) -> Color:
	return Materials.jitter(Materials.DIRT, c.x * 17 + c.y * 31)


func _pour_transform(c: Vector2i) -> Transform3D:
	return _slab_transform(project.analysis.slab_rect(c), 0.0, BuildConst.FOUNDATION_TOP)


func _concrete_color(c: Vector2i) -> Color:
	return Materials.jitter(Materials.CONCRETE, c.x * 13 + c.y * 7, 0.03)


func _floor_transform(c: Vector2i) -> Transform3D:
	var t := BuildConst.FLOOR_TILE_THICKNESS
	return Transform3D(Basis.from_scale(Vector3(0.985, t, 0.985)),
			Vector3(c.x + 0.5, BuildConst.FOUNDATION_TOP + t / 2.0, c.y + 0.5))


func _floor_color(c: Vector2i) -> Color:
	return Materials.FLOOR_A if (c.x + c.y) % 2 == 0 else Materials.FLOOR_B


func _roof_slab_transform(c: Vector2i) -> Transform3D:
	var y0 := project.wall_top()
	return _slab_transform(project.analysis.slab_rect(c), y0, y0 + BuildConst.ROOF_SLAB_THICKNESS)


func _cells_view(node_name: String, progress: CellProgress, transform_fn: Callable, color_fn: Callable,
		with_hologram: bool) -> CellsView:
	var view := CellsView.new()
	view.name = node_name
	add_child(view)
	view.setup(progress, transform_fn, color_fn, with_hologram)
	return view


## Hộp phủ hình chữ nhật r (mặt bằng x, z) từ độ cao y0 đến y1.
static func _slab_transform(r: Rect2, y0: float, y1: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(r.size.x, y1 - y0, r.size.y)),
			Vector3(r.get_center().x, (y0 + y1) / 2.0, r.get_center().y))


## Thêm hộp va chạm cho các ô móng mới đổ. Chỉ thêm, không dựng lại: hộp mới chỉ có hiệu lực
## từ frame vật lý sau, nên xoá đi dựng lại sẽ làm nền "biến mất" một frame (tia xuyên qua,
## nhân vật hụt chân) mỗi khi một giai đoạn hoàn thành.
func _sync_slab_body() -> void:
	var order := project.pour.order
	for i in range(_slab_shapes, order.size()):
		Colliders.add_box_xform(_slab_body, _slab_transform(project.analysis.slab_rect(order[i]), 0.0,
				BuildConst.FOUNDATION_TOP))
	_slab_shapes = maxi(_slab_shapes, order.size())


func _build_opening(k: int) -> OpeningView:
	var p := project
	var w: int = p.blueprint.openings[k]["wall"]
	var g := p.walls[w]
	# Cửa luôn mở vào phía trong nhà.
	var inward := g.normal if p.analysis.side_is_interior(w, 1) else -g.normal
	var toward := signf(inward.dot(g.dir.cross(Vector3.UP)))
	var view := OpeningView.new()
	add_child(view)
	view.setup(g, p.blueprint.opening_rect(k), k, str(p.blueprint.openings[k]["type"]), self, toward)
	return view


func _update_finish(w: int, side: int) -> void:
	var p := project
	var color_id: String = p.paint_color[w][side]
	var color := Catalog.item_color(color_id) if Catalog.has_item(color_id) else Color.WHITE
	_walls[w].set_finish(side, p.plaster[w][side], color, p.paint_progress[w][side])


func _sync_furniture() -> void:
	var wanted := {}
	for f in project.furniture:
		wanted[int(f["uid"])] = f
	for uid: int in _furniture.keys():
		if not wanted.has(uid):
			var old: Node = _furniture[uid]
			_furniture.erase(uid)
			old.queue_free()
	for uid: int in wanted:
		if not _furniture.has(uid):
			var f: Dictionary = wanted[uid]
			var view := FurnitureView.new()
			view.setup(uid, str(f["id"]), f["pos"], float(f["yaw"]), self)
			add_child(view)
			_furniture[uid] = view
