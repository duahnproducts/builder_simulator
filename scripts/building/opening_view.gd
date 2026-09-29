class_name OpeningView
extends Node3D
## Cửa đi hoặc cửa sổ trên tường. Xem docs/04-thi-cong.md.
##
## Chưa lắp: hình mờ khung cửa + vùng nhắm (chỉ khi bức tường chứa nó đã xây xong).
## Đã lắp: khung + cánh; cửa đi mở/đóng được bằng phím tương tác.
## Hệ toạ độ riêng: x dọc tường, y hướng lên, z xuyên qua tường; gốc ở tâm lỗ cửa.

const FRAME := 0.06
const DEPTH := 0.24

var index := -1
var type := "door"
var width := 1.0
var height := 2.2
var is_open := false
var installed := false
## Hướng mở cánh cửa theo trục z riêng: +1 hoặc −1 (luôn mở vào phía trong nhà).
var open_toward := 1.0

var _house: Node
var _holo: MeshInstance3D
var _target: StaticBody3D
var _installed: Node3D
var _pivot: Node3D
var _tween: Tween


func setup(g: WallGeometry, rect: Rect2, k: int, opening_type: String, house: Node, toward: float) -> void:
	index = k
	type = opening_type
	width = rect.size.x
	height = rect.size.y
	open_toward = toward
	_house = house
	name = "Opening%d" % k
	var center := g.origin + g.dir * rect.get_center().x + Vector3.UP * rect.get_center().y
	transform = Transform3D(Basis(g.dir, Vector3.UP, g.dir.cross(Vector3.UP)), center)
	var holo := MeshBuilder.new()
	_add_frame(holo, Materials.HOLOGRAM_COLOR)
	holo.add_box(Transform3D(Basis.from_scale(Vector3(width, height, 0.02)), Vector3.ZERO),
			Color(Materials.HOLOGRAM_COLOR, 0.12))
	_holo = MeshInstance3D.new()
	_holo.name = "Hologram"
	_holo.mesh = holo.commit(Materials.hologram())
	_holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_holo)
	_target = Colliders.make_body(Colliders.BLUEPRINT, {"kind": "opening", "index": k, "house": house}, "Target")
	Colliders.add_box_xform(_target, Transform3D(Basis.from_scale(Vector3(width, height, 0.3)), Vector3.ZERO))
	add_child(_target)


## wall_done: bức tường đã xây xong; is_installed: đã lắp cửa.
func set_state(wall_done: bool, is_installed: bool) -> void:
	var waiting := wall_done and not is_installed
	_holo.visible = waiting
	_target.collision_layer = Colliders.BLUEPRINT if waiting else 0
	installed = is_installed
	if is_installed and _installed == null:
		_build_installed()
	if _installed != null:
		_installed.visible = is_installed


## Mở/đóng cửa đi (có hoạt ảnh). Cửa sổ và cửa chưa lắp thì bỏ qua.
func toggle_door() -> void:
	if type != "door" or _pivot == null:
		return
	set_open(not is_open, true)


func set_open(value: bool, animate := false) -> void:
	if _pivot == null:
		return
	is_open = value
	var target_angle := -open_toward * deg_to_rad(95.0) if is_open else 0.0
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(_pivot, "rotation:y", target_angle, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		_pivot.rotation.y = target_angle


func hologram_visible() -> bool:
	return _holo.visible


func target_body() -> StaticBody3D:
	return _target


func _add_frame(b: MeshBuilder, color: Color) -> void:
	var hw := width / 2.0
	var hh := height / 2.0
	b.add_box(Transform3D(Basis.from_scale(Vector3(FRAME, height, DEPTH)), Vector3(-hw + FRAME / 2.0, 0, 0)), color)
	b.add_box(Transform3D(Basis.from_scale(Vector3(FRAME, height, DEPTH)), Vector3(hw - FRAME / 2.0, 0, 0)), color)
	b.add_box(Transform3D(Basis.from_scale(Vector3(width, FRAME, DEPTH)), Vector3(0, hh - FRAME / 2.0, 0)), color)
	if type == "window":
		b.add_box(Transform3D(Basis.from_scale(Vector3(width, FRAME, DEPTH)), Vector3(0, -hh + FRAME / 2.0, 0)), color)


func _build_installed() -> void:
	_installed = Node3D.new()
	_installed.name = "Installed"
	add_child(_installed)
	var frame := MeshBuilder.new()
	_add_frame(frame, Materials.FRAME)
	if type == "window":
		frame.add_box(Transform3D(Basis.from_scale(Vector3(0.04, height, 0.08)), Vector3.ZERO), Materials.FRAME)
		frame.add_box(Transform3D(Basis.from_scale(Vector3(width, 0.04, 0.08)), Vector3.ZERO), Materials.FRAME)
		frame.add_box(Transform3D(Basis.from_scale(Vector3(width + 0.1, 0.05, 0.32)),
				Vector3(0, -height / 2.0 - 0.025, 0)), Color(0.8, 0.8, 0.78))
	var frame_mesh := MeshInstance3D.new()
	frame_mesh.name = "Frame"
	frame_mesh.mesh = frame.commit()
	_installed.add_child(frame_mesh)
	if type == "window":
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		glass.mesh = MeshBuilder.unit_box()
		glass.material_override = Materials.glass()
		glass.transform = Transform3D(Basis.from_scale(Vector3(width - 2 * FRAME, height - 2 * FRAME, 0.02)), Vector3.ZERO)
		_installed.add_child(glass)
		var body := Colliders.make_body(Colliders.WORLD, {"kind": "window", "index": index, "house": _house}, "Solid")
		Colliders.add_box_xform(body, Transform3D(Basis.from_scale(Vector3(width, height, 0.12)), Vector3.ZERO))
		_installed.add_child(body)
		return
	# Cửa đi: cánh cửa quay quanh bản lề ở mép trái.
	_pivot = Node3D.new()
	_pivot.name = "Hinge"
	_pivot.position = Vector3(-width / 2.0 + FRAME, -FRAME / 2.0, 0)
	_installed.add_child(_pivot)
	var leaf_w := width - 2.0 * FRAME
	var leaf_h := height - FRAME
	var leaf_center := Vector3(leaf_w / 2.0, 0, 0)
	var leaf := MeshBuilder.new()
	leaf.add_box(Transform3D(Basis.from_scale(Vector3(leaf_w, leaf_h, 0.05)), leaf_center), Materials.DOOR_WOOD)
	for inset_y: float in [leaf_h * 0.22, -leaf_h * 0.22]:
		for face: float in [0.027, -0.027]:
			leaf.add_box(Transform3D(Basis.from_scale(Vector3(leaf_w * 0.7, leaf_h * 0.36, 0.006)),
					leaf_center + Vector3(0, inset_y, face)), Materials.DOOR_WOOD.darkened(0.2))
	for face: float in [0.045, -0.045]:
		leaf.add_box(Transform3D(Basis.from_scale(Vector3(0.12, 0.03, 0.03)),
				Vector3(leaf_w - 0.12, -0.05, face)), Color(0.85, 0.75, 0.4))
	var leaf_mesh := MeshInstance3D.new()
	leaf_mesh.name = "Leaf"
	leaf_mesh.mesh = leaf.commit()
	_pivot.add_child(leaf_mesh)
	var door_body := Colliders.make_body(Colliders.WORLD | Colliders.INTERACTABLE,
			{"kind": "door", "index": index, "house": _house}, "Solid")
	Colliders.add_box_xform(door_body, Transform3D(Basis.from_scale(Vector3(leaf_w, leaf_h, 0.06)), leaf_center))
	_pivot.add_child(door_body)
