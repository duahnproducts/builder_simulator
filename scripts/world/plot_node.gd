class_name PlotNode
extends Node3D
## Một lô đất trong thế giới: nền đất, hàng rào (chừa lối vào phía trước), biển tên và công trình nếu có.
## Gốc toạ độ ở góc (0, 0) của lô; mặt trước (z = size.y) hướng ra đường. Xem docs/07-the-gioi.md.

const FENCE_GAP := 4.0

var plot_id := ""
var plot_name := ""
var size := Vector2i(14, 14)
var is_home := false
var house: HouseView

var _label: Label3D


func setup(plot: Dictionary) -> void:
	plot_id = str(plot["id"])
	plot_name = str(plot.get("name", plot_id))
	size = Catalog.plot_size(plot)
	is_home = DataUtil.to_bool(plot.get("own"))
	name = "Plot_" + plot_id
	transform = Catalog.plot_transform(plot)
	_build_ground()
	_build_fence()
	_label = Label3D.new()
	_label.name = "Sign"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.006
	_label.font_size = 56
	_label.outline_size = 12
	_label.modulate = Color(1.0, 0.97, 0.85)
	_label.position = Vector3(size.x / 2.0 - FENCE_GAP / 2.0 - 0.6, 2.4, size.y + 0.2)
	add_child(_label)
	update_label()


## Gắn công trình vào lô: tạo HouseView (thay cái cũ nếu có).
func attach(project: ConstructionProject) -> void:
	detach()
	house = HouseView.new()
	add_child(house)
	house.setup(project)
	project.stage_completed.connect(_on_stage_completed)
	update_label()


func detach() -> void:
	if house != null:
		remove_child(house)
		house.queue_free()
		house = null
	update_label()


## Điểm (toạ độ thế giới) có nằm trong lô không.
func contains_point(world_pos: Vector3) -> bool:
	var p := to_local(world_pos)
	return p.x >= 0.0 and p.z >= 0.0 and p.x <= size.x and p.z <= size.y


## Hình chữ nhật (x, z) mà lô chiếm trong toạ độ thế giới.
func world_rect() -> Rect2:
	var a := to_global(Vector3.ZERO)
	var b := to_global(Vector3(size.x, 0, size.y))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z)))


func label_text() -> String:
	return _label.text


func update_label() -> void:
	_label.text = "%s\n%s" % [plot_name, _status_text()]


func _status_text() -> String:
	var p := GameState.project_at(plot_id)
	if is_home:
		if p == null:
			return "Dùng bàn vẽ để thiết kế nhà của bạn"
		return "Nhà của bạn" if p.is_complete() else "Đang xây nhà của bạn"
	if p != null:
		return "Đã hoàn thành" if p.is_complete() else "Đang thi công"
	for c in Catalog.contracts():
		if str(c.get("plot", "")) != plot_id:
			continue
		match GameState.contract_status(str(c["id"])):
			"available", "busy":
				return "Có hợp đồng: %s" % str(c.get("client", ""))
			"locked":
				return "Chờ hợp đồng (cần uy tín %d)" % DataUtil.to_int(c.get("min_reputation"))
	return "Đất trống"


func _on_stage_completed(_stage: String) -> void:
	update_label()


func _build_ground() -> void:
	var patch := MeshInstance3D.new()
	patch.name = "Ground"
	var b := MeshBuilder.new()
	var color := Color(0.42, 0.52, 0.3) if is_home else Color(0.5, 0.42, 0.3)
	b.add_box(Transform3D(Basis.from_scale(Vector3(size.x, 0.02, size.y)), Vector3(size.x / 2.0, 0.01, size.y / 2.0)), color)
	patch.mesh = b.commit()
	add_child(patch)


## Hàng rào thấp (chỉ để nhìn, không chặn đường đi); phía trước chừa lối vào rộng FENCE_GAP.
func _build_fence() -> void:
	var b := MeshBuilder.new()
	var post := Color(0.92, 0.9, 0.84)
	var corners := [Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var c: Vector2 = corners[(side + 1) % 4]
		var length := a.distance_to(c)
		var steps := int(ceilf(length / 2.0))
		for i in steps + 1:
			var p := a.lerp(c, float(i) / steps)
			if side == 2 and absf(p.x - size.x / 2.0) < FENCE_GAP / 2.0:
				continue
			b.add_box(Transform3D(Basis.from_scale(Vector3(0.1, 0.9, 0.1)), Vector3(p.x, 0.45, p.y)), post)
		for i in steps:
			var p0 := a.lerp(c, float(i) / steps)
			var p1 := a.lerp(c, float(i + 1) / steps)
			var mid := (p0 + p1) / 2.0
			if side == 2 and absf(mid.x - size.x / 2.0) < FENCE_GAP / 2.0:
				continue
			for y: float in [0.35, 0.7]:
				b.add_beam(Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y), 0.05, post)
	var fence := MeshInstance3D.new()
	fence.name = "Fence"
	fence.mesh = b.commit()
	add_child(fence)
