class_name WallView
extends Node3D
## Hiển thị một mảng tường (tường thường hoặc tường hồi). Xem docs/02-xay-tuong.md.
##
## - Gạch và vữa: hai MultiMesh cùng thứ tự slot; số viên hiện = số viên đã xây.
## - Viên gạch mờ (ghost) ở vị trí sẽ xây tiếp theo.
## - Hình mờ + vùng nhắm (lớp blueprint) khi chưa xây xong; va chạm thật (lớp world) cho phần đã xây.
## - Mảng trát và sơn cho hai mặt (chỉ tường thường).

const MORTAR_GAP := 0.012
const FINISH_THICKNESS := 0.012

var geometry: WallGeometry
var ref_index := -1
var is_gable := false
var laid := 0

var _bricks: MultiMeshInstance3D
var _mortar: MultiMeshInstance3D
var _ghost: MeshInstance3D
var _holo: MeshInstance3D
var _target: StaticBody3D
var _solid: StaticBody3D
var _finish: Array[MeshInstance3D] = []
var _solid_laid := -1


func setup(g: WallGeometry, index: int, house: Node, gable := false) -> void:
	geometry = g
	ref_index = index
	is_gable = gable
	name = ("Gable%d" if gable else "Wall%d") % index
	var count := g.layout.slot_count()
	_bricks = _multimesh("Bricks", count)
	_mortar = _multimesh("Mortar", count)
	var seed_base := index * 977 + (500 if gable else 0)
	for i in count:
		var r := g.layout.slots[i]
		var w := maxf(r.size.x - MORTAR_GAP, 0.005)
		var h := maxf(r.size.y - MORTAR_GAP, 0.005)
		var brick := Rect2(r.get_center() - Vector2(w, h) / 2.0, Vector2(w, h))
		_bricks.multimesh.set_instance_transform(i, g.rect_transform(brick, BuildConst.WALL_THICKNESS, 0.0))
		_bricks.multimesh.set_instance_color(i, Materials.jitter(Materials.BRICK, seed_base + i * 31))
		_mortar.multimesh.set_instance_transform(i, g.rect_transform(r, BuildConst.WALL_THICKNESS - 0.03, 0.0))
		_mortar.multimesh.set_instance_color(i, Materials.MORTAR)
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.mesh = MeshBuilder.unit_box()
	_ghost.material_override = Materials.ghost()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	var holo := MeshBuilder.new()
	for r in g.layout.face_rects():
		holo.add_box(g.rect_transform(r, BuildConst.WALL_THICKNESS + 0.01, 0.0), Materials.HOLOGRAM_COLOR)
	_holo = MeshInstance3D.new()
	_holo.name = "Hologram"
	_holo.mesh = holo.commit(Materials.hologram())
	_holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_holo)
	_target = Colliders.make_body(Colliders.BLUEPRINT,
			{"kind": "gable" if gable else "wall", "index": index, "house": house}, "Target")
	for r in g.layout.face_rects():
		Colliders.add_box_xform(_target, g.rect_transform(r, BuildConst.WALL_THICKNESS + 0.02, 0.0))
	add_child(_target)
	_solid = Colliders.make_body(Colliders.WORLD,
			{"kind": "gable_built" if gable else "wall_built", "index": index, "house": house}, "Solid")
	add_child(_solid)
	if not gable:
		for side in 2:
			var mi := MeshInstance3D.new()
			mi.name = "Finish%d" % side
			add_child(mi)
			_finish.append(mi)


## Cập nhật theo số viên đã xây. can_build = đã được phép xây (để hiện viên gạch mờ).
func set_laid(n: int, can_build: bool) -> void:
	var total := geometry.layout.slot_count()
	laid = clampi(n, 0, total)
	_bricks.multimesh.visible_instance_count = laid
	_mortar.multimesh.visible_instance_count = laid
	var done := laid >= total
	_holo.visible = not done
	_target.collision_layer = 0 if done else Colliders.BLUEPRINT
	_ghost.visible = can_build and not done
	if _ghost.visible:
		_ghost.transform = geometry.slot_transform(laid).scaled_local(Vector3.ONE * 1.04)
	if _solid_laid != laid:
		_solid_laid = laid
		Colliders.clear(_solid)
		for r in geometry.layout.built_rects(laid):
			Colliders.add_box_xform(_solid, geometry.rect_transform(r, BuildConst.WALL_THICKNESS, 0.0))


## Dựng lại mảng trát/sơn của một mặt. Tiến độ 0..1 hiển thị bằng cách phủ dần từ dưới lên.
func set_finish(side: int, plaster_progress: float, paint_color: Color, paint_progress: float) -> void:
	if is_gable:
		return
	var b := MeshBuilder.new()
	var outward := -1.0 if side == 0 else 1.0
	var limit_plaster := plaster_progress * geometry.layout.height
	var limit_paint := paint_progress * geometry.layout.height
	for r in geometry.plaster_rects():
		_add_clipped(b, r, limit_plaster, Materials.PLASTER,
				outward * (BuildConst.HALF_WALL + FINISH_THICKNESS / 2.0))
		if paint_progress > 0.0:
			_add_clipped(b, r, limit_paint, paint_color,
					outward * (BuildConst.HALF_WALL + FINISH_THICKNESS * 1.5))
	_finish[side].mesh = null if b.is_empty() else b.commit()


func visible_bricks() -> int:
	return _bricks.multimesh.visible_instance_count


func ghost_visible() -> bool:
	return _ghost.visible


func target_body() -> StaticBody3D:
	return _target


func solid_body() -> StaticBody3D:
	return _solid


func finish_mesh(side: int) -> Mesh:
	return _finish[side].mesh if side < _finish.size() else null


func _add_clipped(b: MeshBuilder, r: Rect2, limit: float, color: Color, offset: float) -> void:
	var top := minf(r.end.y, limit)
	if top <= r.position.y + 0.001:
		return
	var clipped := Rect2(r.position, Vector2(r.size.x, top - r.position.y))
	b.add_box(geometry.rect_transform(clipped, FINISH_THICKNESS, offset), color)


func _multimesh(node_name: String, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshBuilder.unit_box()
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = Materials.vertex_color()
	add_child(inst)
	return inst
