class_name DecorFactory
extends RefCounted
## Mesh trang trí low-poly cho thế giới: nhà dân, cây, đèn đường, quầy hàng, bảng hợp đồng, bàn vẽ.
## Mọi mesh dùng màu đỉnh (MeshBuilder) nên mỗi vật là một lần vẽ.

const WALL_COLORS := [
	Color(0.93, 0.88, 0.74), Color(0.85, 0.9, 0.93), Color(0.95, 0.82, 0.74),
	Color(0.86, 0.92, 0.8), Color(0.96, 0.93, 0.86), Color(0.9, 0.84, 0.92),
]
const ROOF_COLORS := [Color(0.7, 0.3, 0.2), Color(0.45, 0.26, 0.2), Color(0.36, 0.42, 0.52), Color(0.58, 0.36, 0.24)]
const DARK_WOOD := Color(0.36, 0.23, 0.14)
const GLASS := Color(0.45, 0.6, 0.72)
const PLINTH := Color(0.55, 0.55, 0.53)
const TRUNK := Color(0.4, 0.28, 0.18)
const LEAF := Color(0.27, 0.5, 0.22)
const LEAF_LIGHT := Color(0.36, 0.6, 0.27)
const PINE := Color(0.18, 0.38, 0.2)
const METAL := Color(0.22, 0.23, 0.25)


static func _box(b: MeshBuilder, size: Vector3, at: Vector3, color: Color) -> void:
	b.add_box(Transform3D(Basis.from_scale(size), at), color)


## Nhà dân ngẫu nhiên (theo rng). Mặt trước hướng +z, gốc ở giữa đáy.
## Trả về {"mesh": ArrayMesh, "size": Vector3 (khối thân nhà để làm va chạm)}.
static func house(rng: RandomNumberGenerator) -> Dictionary:
	var w := rng.randf_range(6.0, 9.0)
	var d := rng.randf_range(6.0, 8.0)
	var h := rng.randf_range(3.0, 3.6)
	var wall: Color = WALL_COLORS[rng.randi() % WALL_COLORS.size()]
	var roof: Color = ROOF_COLORS[rng.randi() % ROOF_COLORS.size()]
	var b := MeshBuilder.new()
	_box(b, Vector3(w + 0.3, 0.3, d + 0.3), Vector3(0, 0.15, 0), PLINTH)
	_box(b, Vector3(w, h, d), Vector3(0, 0.3 + h / 2.0, 0), wall)
	var rise := (d / 2.0 + 0.4) * tan(deg_to_rad(30.0))
	# Lăng trụ có mặt cắt tam giác trong mặt phẳng XY; xoay 90° để nóc chạy dọc trục x.
	b.add_prism(Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(d + 0.8, rise, w + 0.8)),
			Vector3(0, 0.3 + h + rise / 2.0, 0)), roof)
	var front := d / 2.0 + 0.03
	_box(b, Vector3(1.0, 2.1, 0.06), Vector3(0, 0.3 + 1.05, front), DARK_WOOD)
	for side: float in [-1.0, 1.0]:
		_box(b, Vector3(1.2, 1.1, 0.06), Vector3(side * w / 4.0 + side * 0.4, 0.3 + 1.6, front), GLASS)
		_box(b, Vector3(1.3, 0.08, 0.1), Vector3(side * w / 4.0 + side * 0.4, 0.3 + 1.02, front), PLINTH)
		_box(b, Vector3(0.06, 1.1, 1.3), Vector3(side * (w / 2.0 + 0.03), 0.3 + 1.6, 0), GLASS)
	return {"mesh": b.commit(), "size": Vector3(w, h + 0.3, d)}


## Cây tán tròn. Gốc ở chân cây.
static func round_tree() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.add_cylinder(Transform3D(Basis.from_scale(Vector3(0.36, 2.4, 0.36)), Vector3(0, 1.2, 0)), TRUNK)
	b.add_sphere(Transform3D(Basis.from_scale(Vector3(2.8, 2.4, 2.8)), Vector3(0, 3.2, 0)), LEAF)
	b.add_sphere(Transform3D(Basis.from_scale(Vector3(1.8, 1.6, 1.8)), Vector3(0.6, 3.9, 0.3)), LEAF_LIGHT)
	return b.commit()


## Cây thông ba tầng lá.
static func pine_tree() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.add_cylinder(Transform3D(Basis.from_scale(Vector3(0.3, 1.6, 0.3)), Vector3(0, 0.8, 0)), TRUNK)
	for i in 3:
		var s := 2.6 - i * 0.6
		b.add_cone(Transform3D(Basis.from_scale(Vector3(s, 1.8, s)), Vector3(0, 2.0 + i * 1.0, 0)), PINE)
	return b.commit()


static func lamp_pole() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.add_cylinder(Transform3D(Basis.from_scale(Vector3(0.14, 4.4, 0.14)), Vector3(0, 2.2, 0)), METAL)
	_box(b, Vector3(0.08, 0.08, 1.0), Vector3(0, 4.35, 0.45), METAL)
	return b.commit()


## Chóa đèn (vẽ bằng vật liệu phát sáng riêng để bật/tắt theo ngày đêm).
static func lamp_head() -> ArrayMesh:
	var b := MeshBuilder.new()
	_box(b, Vector3(0.45, 0.14, 0.3), Vector3(0, 4.25, 0.9), Color.WHITE)
	return b.commit(_emissive_material())


static func _emissive_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.55)
	m.emission_energy_multiplier = 0.0
	return m


## Quầy bán hàng có mái che và hàng mẫu. Mặt trước hướng +z.
static func shop_counter() -> ArrayMesh:
	var b := MeshBuilder.new()
	_box(b, Vector3(4.0, 1.05, 0.8), Vector3(0, 0.525, 0), Color(0.62, 0.44, 0.27))
	_box(b, Vector3(4.2, 0.06, 1.0), Vector3(0, 1.08, 0), Color(0.45, 0.3, 0.18))
	for x: float in [-2.1, 2.1]:
		_box(b, Vector3(0.12, 3.0, 0.12), Vector3(x, 1.5, -0.3), METAL)
	_box(b, Vector3(4.8, 0.08, 2.2), Vector3(0, 3.0, 0.2), Color(0.8, 0.25, 0.2))
	# Hàng mẫu trên quầy: gạch, bao xi măng, thùng sơn.
	for i in 4:
		_box(b, Vector3(0.4, 0.2, 0.2), Vector3(-1.5 + i * 0.25, 1.21 + (i % 2) * 0.2, 0.1), Materials.BRICK)
	_box(b, Vector3(0.6, 0.25, 0.4), Vector3(0.2, 1.24, 0.0), Color(0.75, 0.74, 0.7))
	b.add_cylinder(Transform3D(Basis.from_scale(Vector3(0.3, 0.35, 0.3)), Vector3(1.3, 1.29, 0.1)), Color(0.3, 0.55, 0.85))
	b.add_cylinder(Transform3D(Basis.from_scale(Vector3(0.3, 0.35, 0.3)), Vector3(1.7, 1.29, 0.1)), Color(0.95, 0.85, 0.4))
	return b.commit()


## Tòa nhà cửa hàng (hộp lớn) kèm pallet vật liệu bên cạnh. Mặt trước hướng +z.
static func shop_building(size: Vector3) -> ArrayMesh:
	var b := MeshBuilder.new()
	_box(b, size, Vector3(0, size.y / 2.0, 0), Color(0.95, 0.88, 0.62))
	_box(b, Vector3(size.x + 0.4, 0.3, size.z + 0.4), Vector3(0, size.y + 0.15, 0), Color(0.55, 0.3, 0.2))
	_box(b, Vector3(size.x * 0.8, 1.0, 0.1), Vector3(0, size.y - 0.8, size.z / 2.0 + 0.06), Color(0.15, 0.35, 0.6))
	_box(b, Vector3(2.4, 2.6, 0.06), Vector3(size.x / 2.0 - 2.0, 1.3, size.z / 2.0 + 0.03), GLASS)
	for i in 3:
		var at := Vector3(-size.x / 2.0 - 1.4, 0.35 + i * 0.5, size.z / 2.0 - 1.5)
		_box(b, Vector3(1.2, 0.45, 1.2), at, Materials.BRICK if i < 2 else Color(0.75, 0.74, 0.7))
	return b.commit()


## Bảng hợp đồng: hai cột, tấm bảng gỗ, các tờ giấy. Mặt trước hướng +z.
static func job_board() -> ArrayMesh:
	var b := MeshBuilder.new()
	for x: float in [-1.3, 1.3]:
		_box(b, Vector3(0.12, 2.4, 0.12), Vector3(x, 1.2, 0), DARK_WOOD)
	_box(b, Vector3(2.6, 1.4, 0.08), Vector3(0, 1.55, 0), Color(0.6, 0.42, 0.25))
	_box(b, Vector3(2.9, 0.1, 0.5), Vector3(0, 2.4, 0), Color(0.55, 0.26, 0.18))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 5:
		var at := Vector3(-0.95 + i * 0.47, 1.55 + rng.randf_range(-0.2, 0.2), 0.05)
		_box(b, Vector3(0.36, 0.48, 0.01), at, Color(0.98, 0.96, 0.88))
	return b.commit()


## Bàn vẽ ngoài trời có tờ bản vẽ xanh.
static func drawing_table() -> ArrayMesh:
	var b := MeshBuilder.new()
	_box(b, Vector3(1.4, 0.06, 0.9), Vector3(0, 0.95, 0), Color(0.7, 0.55, 0.36))
	for x: float in [-0.62, 0.62]:
		for z: float in [-0.38, 0.38]:
			_box(b, Vector3(0.06, 0.92, 0.06), Vector3(x, 0.46, z), DARK_WOOD)
	_box(b, Vector3(1.0, 0.01, 0.7), Vector3(0, 0.985, 0), Color(0.25, 0.45, 0.8))
	for i in 4:
		_box(b, Vector3(0.7, 0.012, 0.015), Vector3(0, 0.99, -0.25 + i * 0.16), Color(0.9, 0.95, 1.0))
	return b.commit()
