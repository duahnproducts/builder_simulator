class_name MeshBuilder
extends RefCounted
## Gộp nhiều khối (hộp, trụ, cầu, lăng trụ) thành MỘT mesh; mỗi khối mang màu riêng
## (màu đỉnh — vertex color). Một mesh = một lần vẽ (draw call), nên đồ vật nhiều chi tiết vẫn nhẹ.

static var _templates: Dictionary = {}
static var _unit_box: ArrayMesh

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


## Hộp đơn vị màu trắng, dùng chung cho MultiMesh (màu lấy từ màu instance).
static func unit_box() -> ArrayMesh:
	if _unit_box == null:
		var b := MeshBuilder.new()
		b.add_box(Transform3D.IDENTITY, Color.WHITE)
		_unit_box = b.commit()
	return _unit_box


func is_empty() -> bool:
	return _verts.is_empty()


func add_box(xform: Transform3D, color: Color) -> void:
	_append(_template("box"), xform, color)


func add_cylinder(xform: Transform3D, color: Color) -> void:
	_append(_template("cyl"), xform, color)


func add_sphere(xform: Transform3D, color: Color) -> void:
	_append(_template("ball"), xform, color)


func add_prism(xform: Transform3D, color: Color) -> void:
	_append(_template("prism"), xform, color)


## Hình nón (đáy bán kính 0,5, cao 1, tâm ở giữa chiều cao) — dùng cho cây thông.
func add_cone(xform: Transform3D, color: Color) -> void:
	_append(_template("cone"), xform, color)


## Thanh tiết diện vuông nối hai điểm (thanh gỗ, cột...).
func add_beam(from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var axis := to - from
	if axis.length() < 0.0001:
		return
	var up := Vector3.UP if absf(axis.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	add_box(GeomUtil.box_transform((from + to) / 2.0, axis, up,
			Vector3(axis.length(), thickness, thickness)), color)


## Thêm các khối mô tả bằng dữ liệu (xem data/items.json):
## {"box": [rộng, cao, sâu]} | {"cyl": [bán kính, cao]} | {"ball": [bán kính]}, kèm "at" (tâm) và "color".
func add_parts(parts: Array, base := Transform3D.IDENTITY) -> void:
	for p: Variant in parts:
		var d := DataUtil.to_dict(p)
		var at := _vec3(d.get("at"), Vector3.ZERO)
		var color := Color.from_string(str(d.get("color", "#ffffff")), Color.WHITE)
		if d.has("box"):
			add_box(base * Transform3D(Basis.from_scale(_vec3(d["box"], Vector3(0.1, 0.1, 0.1))), at), color)
		elif d.has("cyl"):
			var c := DataUtil.to_array(d["cyl"])
			var r := DataUtil.to_float(c[0], 0.1) if c.size() > 0 else 0.1
			var h := DataUtil.to_float(c[1], 0.1) if c.size() > 1 else 0.1
			add_cylinder(base * Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), at), color)
		elif d.has("ball"):
			var b := DataUtil.to_array(d["ball"])
			var r := DataUtil.to_float(b[0], 0.1) if b.size() > 0 else 0.1
			add_sphere(base * Transform3D(Basis.from_scale(Vector3.ONE * r * 2.0), at), color)


func commit(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material if material != null else Materials.vertex_color())
	return mesh


func _append(arrays: Array, xform: Transform3D, color: Color) -> void:
	if absf(xform.basis.determinant()) < 1e-9:
		return  # khối kích thước 0: bỏ qua (tránh chia cho 0 khi tính pháp tuyến)
	var base := _verts.size()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Pháp tuyến biến đổi bằng ma trận nghịch đảo chuyển vị để vẫn vuông góc khi co giãn không đều.
	var normal_basis := xform.basis.inverse().transposed()
	for i in v.size():
		_verts.append(xform * v[i])
		_normals.append((normal_basis * n[i]).normalized())
		_colors.append(color)
		_uvs.append(uv[i])
	var flip := xform.basis.determinant() < 0.0  # hệ trục bị lật thì đảo thứ tự đỉnh tam giác
	for t in range(0, idx.size(), 3):
		_indices.append(base + idx[t])
		_indices.append(base + idx[t + 2] if flip else base + idx[t + 1])
		_indices.append(base + idx[t + 1] if flip else base + idx[t + 2])


static func _template(kind: String) -> Array:
	if not _templates.has(kind):
		var mesh: PrimitiveMesh
		match kind:
			"box":
				var box := BoxMesh.new()
				box.size = Vector3.ONE
				mesh = box
			"cyl":
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.5
				cyl.bottom_radius = 0.5
				cyl.height = 1.0
				cyl.radial_segments = 12
				cyl.rings = 0
				mesh = cyl
			"cone":
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.5
				cone.height = 1.0
				cone.radial_segments = 9
				cone.rings = 0
				mesh = cone
			"ball":
				var ball := SphereMesh.new()
				ball.radius = 0.5
				ball.height = 1.0
				ball.radial_segments = 10
				ball.rings = 6
				mesh = ball
			_:
				var prism := PrismMesh.new()
				prism.size = Vector3.ONE
				mesh = prism
		_templates[kind] = mesh.get_mesh_arrays()
	return _templates[kind]


static func _vec3(value: Variant, default: Vector3) -> Vector3:
	var a := DataUtil.to_array(value)
	if a.size() != 3:
		return default
	return Vector3(DataUtil.to_float(a[0]), DataUtil.to_float(a[1]), DataUtil.to_float(a[2]))
