class_name CellsView
extends Node3D
## Vẽ một tập ô lưới bằng MultiMesh: ô đã làm (theo thứ tự làm) và hình mờ của ô chưa làm.
## Dùng cho đào móng, đổ móng, lát nền, đổ mái bằng. Xem docs/03-mong-mai-nen.md.

var progress: CellProgress
## Hàm Vector2i → Transform3D (biến hộp đơn vị thành khối của ô).
var cell_transform: Callable
## Hàm Vector2i → Color.
var cell_color: Callable
var show_hologram := true

var _done: MultiMeshInstance3D
var _holo: MultiMeshInstance3D


func setup(p: CellProgress, transform_fn: Callable, color_fn: Callable, with_hologram := true) -> void:
	progress = p
	cell_transform = transform_fn
	cell_color = color_fn
	show_hologram = with_hologram
	_done = _instance("Done", Materials.vertex_color())
	_holo = _instance("Hologram", Materials.hologram())
	_holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in p.total():
		_holo.multimesh.set_instance_transform(i, cell_transform.call(p.cells[i]))
	refresh()


## Đồng bộ toàn bộ với tiến độ hiện tại.
func refresh() -> void:
	var mm := _done.multimesh
	for i in progress.order.size():
		var c := progress.order[i]
		mm.set_instance_transform(i, cell_transform.call(c))
		mm.set_instance_color(i, cell_color.call(c))
	mm.visible_instance_count = progress.done_count()
	for i in progress.total():
		var shown := show_hologram and not progress.is_done(progress.cells[i])
		_holo.multimesh.set_instance_color(i, Materials.HOLOGRAM_COLOR if shown else Color(0, 0, 0, 0))


func set_hologram_visible(value: bool) -> void:
	if show_hologram != value:
		show_hologram = value
		refresh()


func visible_count() -> int:
	return _done.multimesh.visible_instance_count


func _instance(node_name: String, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshBuilder.unit_box()
	mm.instance_count = progress.total()
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = material
	add_child(inst)
	return inst
