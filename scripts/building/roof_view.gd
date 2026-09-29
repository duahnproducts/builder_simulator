class_name RoofView
extends Node3D
## Mái ngói: vì kèo, ngói, ngói nóc (3 MultiMesh) + mảnh mờ kế tiếp + hình mờ cả mái.
## Xem docs/03-mong-mai-nen.md.

var roof: RoofLayout
var laid := 0

var _trusses: MultiMeshInstance3D
var _tiles: MultiMeshInstance3D
var _ridges: MultiMeshInstance3D
var _ghost: MeshInstance3D
var _holo: MeshInstance3D
var _target: StaticBody3D


func setup(r: RoofLayout, house: Node) -> void:
	roof = r
	name = "Roof"
	var truss_mesh := MeshBuilder.new()
	for m in r.truss_members():
		truss_mesh.add_beam(m["from"], m["to"], 0.1, Materials.WOOD)
	_trusses = _multimesh("Trusses", truss_mesh.commit(), r.truss_count())
	for i in r.truss_count():
		_trusses.multimesh.set_instance_transform(i, r.truss_transform(i))
	_tiles = _multimesh("Tiles", MeshBuilder.unit_box(), r.tile_count())
	for k in r.tile_count():
		_tiles.multimesh.set_instance_transform(k, r.tile_transform(k))
		var row := r.tile_coords(k).y
		var base := Materials.ROOF_TILE.darkened(0.08) if row % 2 == 1 else Materials.ROOF_TILE
		_tiles.multimesh.set_instance_color(k, Materials.jitter(base, k * 13 + 7, 0.05))
	_ridges = _multimesh("Ridge", MeshBuilder.unit_box(), r.ridge_count())
	for j in r.ridge_count():
		_ridges.multimesh.set_instance_transform(j, r.ridge_transform(j))
		_ridges.multimesh.set_instance_color(j, Materials.RIDGE_TILE)
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.mesh = MeshBuilder.unit_box()
	_ghost.material_override = Materials.ghost()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	var holo := MeshBuilder.new()
	_target = Colliders.make_body(Colliders.BLUEPRINT, {"kind": "roof", "house": house}, "Target")
	for side in 2:
		var panel := r.side_panel_transform(side)
		holo.add_box(panel, Materials.HOLOGRAM_COLOR)
		Colliders.add_box_xform(_target, panel.scaled_local(Vector3(1.0, 6.0, 1.0)))
	_holo = MeshInstance3D.new()
	_holo.name = "Hologram"
	_holo.mesh = holo.commit(Materials.hologram())
	_holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_holo)
	add_child(_target)


## Cập nhật theo số mảnh đã lợp. can_build = đã được phép lợp (hiện mảnh mờ kế tiếp).
func set_laid(n: int, can_build: bool) -> void:
	laid = clampi(n, 0, roof.piece_count())
	var t := roof.truss_count()
	var k := roof.tile_count()
	_trusses.multimesh.visible_instance_count = mini(laid, t)
	_tiles.multimesh.visible_instance_count = clampi(laid - t, 0, k)
	_ridges.multimesh.visible_instance_count = clampi(laid - t - k, 0, roof.ridge_count())
	var done := laid >= roof.piece_count()
	_holo.visible = not done
	_target.collision_layer = 0 if done else Colliders.BLUEPRINT
	_ghost.visible = can_build and not done
	if _ghost.visible:
		_ghost.transform = piece_transform(laid)


## Khối bao của mảnh thứ i (vì kèo: khối mỏng bao cả vì kèo).
func piece_transform(i: int) -> Transform3D:
	var t := roof.truss_count()
	var k := roof.tile_count()
	if i < t:
		var height := roof.rise + BuildConst.ROOF_LIFT
		var span := roof.s_len + 2.0 * BuildConst.ROOF_OVERHANG
		return roof.truss_transform(i) * Transform3D(Basis.from_scale(Vector3(0.14, height, span)),
				Vector3(0, height / 2.0, 0))
	if i < t + k:
		return roof.tile_transform(i - t).scaled_local(Vector3(1.0, 1.6, 1.0))
	return roof.ridge_transform(i - t - k).scaled_local(Vector3.ONE * 1.1)


func visible_counts() -> Vector3i:
	return Vector3i(_trusses.multimesh.visible_instance_count, _tiles.multimesh.visible_instance_count,
			_ridges.multimesh.visible_instance_count)


func ghost_visible() -> bool:
	return _ghost.visible


func target_body() -> StaticBody3D:
	return _target


func _multimesh(node_name: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	for i in count:
		mm.set_instance_color(i, Color.WHITE)
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = Materials.vertex_color()
	add_child(inst)
	return inst
