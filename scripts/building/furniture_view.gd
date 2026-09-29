class_name FurnitureView
extends StaticBody3D
## Một món nội thất đã đặt: mesh dựng từ dữ liệu "parts" (cache theo mã vật phẩm) + hộp va chạm.
## Gốc toạ độ ở giữa đáy món đồ.

static var _mesh_cache: Dictionary = {}

var uid := 0
var item_id := ""


## Mesh của món nội thất; dựng một lần cho mỗi mã rồi dùng lại.
static func mesh_for(id: String) -> ArrayMesh:
	if not _mesh_cache.has(id):
		var b := MeshBuilder.new()
		b.add_parts(Catalog.furniture_parts(id))
		_mesh_cache[id] = b.commit()
	return _mesh_cache[id]


func setup(p_uid: int, id: String, pos: Vector3, yaw: float, house: Node) -> void:
	uid = p_uid
	item_id = id
	name = "Furniture%d" % p_uid
	collision_layer = Colliders.FURNITURE
	collision_mask = 0
	set_meta("kind", "furniture")
	set_meta("uid", p_uid)
	set_meta("house", house)
	transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = mesh_for(id)
	add_child(mesh)
	var size := Catalog.furniture_size(id)
	Colliders.add_box_xform(self, Transform3D(Basis.from_scale(size), Vector3(0, size.y / 2.0, 0)))
