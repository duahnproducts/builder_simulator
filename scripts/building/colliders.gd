class_name Colliders
extends RefCounted
## Tiện ích tạo thân va chạm tĩnh gồm nhiều hộp.
## Hình va chạm không bị co giãn (scale): Godot khuyên đặt kích thước vào BoxShape3D.size.

## Bit của các lớp va chạm (tên trong project.godot → layer_names).
const WORLD := 1
const BLUEPRINT := 2
const FURNITURE := 4
const INTERACTABLE := 8
const PLAYER := 16
## Khoảng trống phải chừa (trước cửa đi): chỉ dùng khi kiểm tra chỗ đặt nội thất.
const CLEARANCE := 32


## StaticBody3D rỗng trên lớp `layer`, gắn metadata để controller biết đây là gì.
static func make_body(layer: int, meta: Dictionary, body_name := "Body") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	for key: String in meta:
		body.set_meta(key, meta[key])
	return body


## Thêm hộp va chạm theo biến đổi dạng "hộp đơn vị được co giãn" (như GeomUtil.box_transform).
static func add_box_xform(body: CollisionObject3D, xform: Transform3D) -> void:
	var size := Vector3(xform.basis.x.length(), xform.basis.y.length(), xform.basis.z.length())
	if size.x <= 0.0001 or size.y <= 0.0001 or size.z <= 0.0001:
		return
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(xform.basis.orthonormalized(), xform.origin)
	body.add_child(cs)


## Xoá mọi hình va chạm con (ngay lập tức, để truy vấn vật lý sau đó không thấy chúng).
static func clear(body: Node) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


static func shape_count(body: Node) -> int:
	return body.get_child_count() if body != null else 0
