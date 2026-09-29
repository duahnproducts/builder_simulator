class_name World
extends Node3D
## Thế giới mở: bầu trời, mặt đất, đường, lô đất, cửa hàng, bảng hợp đồng, nhà dân, cây, đèn đường,
## ngày đêm. Sinh bằng RNG có seed cố định nên lần nào cũng giống nhau. Xem docs/07-the-gioi.md.

const SEED := 20260929
const HALF_X := 100.0
const HALF_Z := 60.0
const ROAD_HALF := 4.0
const SIDEWALK := 2.0
const TREE_MIN_DIST := 3.5
## Quảng trường trước cửa hàng và bảng hợp đồng (lát gạch, không trồng cây).
const PLAZA_RECT := Rect2(-15.0, -22.0, 30.0, 16.0)
const GROUND_SIZE := 1000.0
const JOB_BOARD_POS := Vector3(5.0, 0.0, -8.5)

var plots: Dictionary = {}
var sun: DirectionalLight3D
var environment: Environment
var day_night: DayNight
var tree_positions: Array[Vector3] = []
## Vật tương tác theo loại: "shop", "job_board", "drawing_table".
var interactables: Dictionary = {}
var decor_lots: Array[Rect2] = []

var _keepout: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()


func build() -> void:
	name = "World"
	_rng.seed = SEED
	var lamp_material := _build_environment_and_lamps()
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, environment, environment.sky.sky_material as ProceduralSkyMaterial, lamp_material)
	_build_ground()
	_build_roads()
	_build_plots()
	_build_shop()
	_build_job_board()
	_build_decor_houses()
	_build_trees()
	_build_bounds()
	GameState.project_added.connect(_on_project_added)
	GameState.project_removed.connect(_on_project_removed)
	GameState.contracts_changed.connect(_refresh_labels)
	for plot_id: String in GameState.projects:
		_on_project_added(plot_id)


func spawn_point() -> Vector3:
	return Vector3(0.0, 0.1, 1.5)


## Hướng nhìn lúc xuất hiện: về phía bắc (cửa hàng, bảng hợp đồng).
func spawn_yaw() -> float:
	return 0.0


func plot_node(plot_id: String) -> PlotNode:
	return plots.get(plot_id)


func house_view(plot_id: String) -> HouseView:
	var node := plot_node(plot_id)
	return node.house if node != null else null


## Mã lô đất chứa điểm (toạ độ thế giới), "" nếu không ở lô nào.
func plot_at(world_pos: Vector3) -> String:
	for plot_id: String in plots:
		if (plots[plot_id] as PlotNode).contains_point(world_pos):
			return plot_id
	return ""


## Điểm có nằm trong vùng cấm trồng cây / đặt đồ trang trí không.
func is_keepout(x: float, z: float) -> bool:
	for r in _keepout:
		if r.has_point(Vector2(x, z)):
			return true
	return false


func _on_project_added(plot_id: String) -> void:
	var node := plot_node(plot_id)
	if node != null:
		node.attach(GameState.project_at(plot_id))


func _on_project_removed(plot_id: String) -> void:
	var node := plot_node(plot_id)
	if node != null:
		node.detach()


func _refresh_labels() -> void:
	for plot_id: String in plots:
		(plots[plot_id] as PlotNode).update_label()


# ─── Dựng thế giới ──────────────────────────────────────────────────────────

func _build_environment_and_lamps() -> StandardMaterial3D:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.ground_bottom_color = Color(0.22, 0.28, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Chỉ lấy 60% ánh sáng môi trường từ bầu trời (xanh), phần còn lại là màu trắng ấm:
	# trong nhà (chỉ được chiếu bởi ánh sáng môi trường) không bị ám xanh.
	environment.ambient_light_sky_contribution = 0.6
	environment.ambient_light_color = Color(1.0, 0.93, 0.84)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0015
	environment.fog_sky_affect = 0.1
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	# Đèn đường dọc hai bên vỉa hè.
	var positions: Array[Transform3D] = []
	var z_side := ROAD_HALF + SIDEWALK - 0.4
	for i in 10:
		var x := -90.0 + i * 20.0
		positions.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0, -z_side)))
		positions.append(Transform3D(Basis.IDENTITY, Vector3(x + 10.0, 0, z_side)))
	var head := DecorFactory.lamp_head()
	_multimesh("LampPoles", DecorFactory.lamp_pole(), positions)
	_multimesh("LampHeads", head, positions)
	return head.surface_get_material(0) as StandardMaterial3D


func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.02
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.27, 0.43, 0.2))
	gradient.set_color(1, Color(0.38, 0.55, 0.26))
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = gradient
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_scale = Vector3(GROUND_SIZE / 9.0, GROUND_SIZE / 9.0, 1)
	material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = material
	add_child(ground)
	var body := Colliders.make_body(Colliders.WORLD, {"kind": "ground"}, "GroundBody")
	Colliders.add_box_xform(body, Transform3D(Basis.from_scale(Vector3(HALF_X * 2.0 + 20.0, 1.0,
			HALF_Z * 2.0 + 20.0)), Vector3(0, -0.5, 0)))
	add_child(body)


func _build_roads() -> void:
	var b := MeshBuilder.new()
	var length := HALF_X * 2.0 + 120.0
	b.add_box(Transform3D(Basis.from_scale(Vector3(length, 0.02, ROAD_HALF * 2.0)), Vector3(0, 0.01, 0)),
			Color(0.2, 0.2, 0.22))
	for z_sign: float in [-1.0, 1.0]:
		b.add_box(Transform3D(Basis.from_scale(Vector3(length, 0.03, SIDEWALK)),
				Vector3(0, 0.015, z_sign * (ROAD_HALF + SIDEWALK / 2.0))), Color(0.5, 0.5, 0.49))
		b.add_box(Transform3D(Basis.from_scale(Vector3(length, 0.035, 0.12)),
				Vector3(0, 0.0175, z_sign * ROAD_HALF)), Color(0.72, 0.72, 0.7))
	# Quảng trường lát gạch trước cửa hàng.
	b.add_box(Transform3D(Basis.from_scale(Vector3(PLAZA_RECT.size.x, 0.025, PLAZA_RECT.size.y)),
			Vector3(PLAZA_RECT.get_center().x, 0.0125, PLAZA_RECT.get_center().y)), Color(0.45, 0.4, 0.36))
	var x := -HALF_X
	while x < HALF_X:
		b.add_box(Transform3D(Basis.from_scale(Vector3(3.0, 0.025, 0.18)), Vector3(x + 1.5, 0.0125, 0)),
				Color(0.95, 0.95, 0.92))
		x += 7.0
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = b.commit()
	add_child(road)
	_keepout.append(Rect2(-HALF_X - 60.0, -ROAD_HALF - SIDEWALK - 1.5, HALF_X * 2.0 + 120.0,
			(ROAD_HALF + SIDEWALK + 1.5) * 2.0))


func _build_plots() -> void:
	var root := Node3D.new()
	root.name = "Plots"
	add_child(root)
	for p in Catalog.plots():
		var node := PlotNode.new()
		root.add_child(node)
		node.setup(p)
		plots[node.plot_id] = node
		_keepout.append(node.world_rect().grow(2.0))
		if node.is_home:
			_build_drawing_table(node)


func _build_drawing_table(home: PlotNode) -> void:
	var table := _interactable("drawing_table", DecorFactory.drawing_table(), Vector3(1.4, 1.0, 0.9),
			Vector3(0, 0.5, 0))
	home.add_child(table)
	table.position = Vector3(-1.6, 0, home.size.y - 2.0)
	var label := _sign("BÀN VẼ\n[E] thiết kế nhà", 0.004)
	label.position = Vector3(0, 1.7, 0)
	table.add_child(label)
	var at := table.global_position if table.is_inside_tree() else home.transform * table.position
	_keepout.append(Rect2(at.x - 3.0, at.z - 3.0, 6.0, 6.0))


func _build_shop() -> void:
	var size := Vector3(10.0, 4.5, 8.0)
	var building := StaticBody3D.new()
	building.name = "ShopBuilding"
	building.collision_layer = Colliders.WORLD
	building.position = Vector3(-6.0, 0, -15.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = DecorFactory.shop_building(size)
	building.add_child(mesh)
	Colliders.add_box_xform(building, Transform3D(Basis.from_scale(size), Vector3(0, size.y / 2.0, 0)))
	add_child(building)
	var shop_sign := _sign("CỬA HÀNG VẬT LIỆU XÂY DỰNG", 0.012, false)
	shop_sign.position = Vector3(0, size.y - 0.8, size.z / 2.0 + 0.13)
	building.add_child(shop_sign)
	var counter := _interactable("shop", DecorFactory.shop_counter(), Vector3(4.0, 1.1, 0.8),
			Vector3(0, 0.55, 0))
	counter.position = Vector3(-6.0, 0, -9.6)
	add_child(counter)
	var hint := _sign("[E] Mua vật liệu", 0.005)
	hint.position = Vector3(0, 2.2, 0.5)
	counter.add_child(hint)
	_keepout.append(PLAZA_RECT)


func _build_job_board() -> void:
	var board := _interactable("job_board", DecorFactory.job_board(), Vector3(2.6, 1.5, 0.3),
			Vector3(0, 1.55, 0))
	board.position = JOB_BOARD_POS
	add_child(board)
	var label := _sign("BẢNG HỢP ĐỒNG\n[E] xem việc", 0.006)
	label.position = Vector3(0, 3.0, 0)
	board.add_child(label)
	_keepout.append(Rect2(JOB_BOARD_POS.x - 3.0, JOB_BOARD_POS.z - 2.0, 6.0, 4.0))


## Nhà dân trang trí: hàng trước phía nam (cạnh đất nhà bạn) và hai hàng sau.
func _build_decor_houses() -> void:
	var root := Node3D.new()
	root.name = "DecorHouses"
	add_child(root)
	var lots: Array[Transform3D] = []
	for x0: float in [-70.0, -50.0, -30.0, 16.0, 36.0, 56.0]:
		lots.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x0 + 7.0, 0, 13.0)))
	var x := -84.0
	while x <= 84.0:
		lots.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, -40.0)))
		lots.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x + 9.0, 0, 40.0)))
		x += 21.0
	for lot in lots:
		var data := DecorFactory.house(_rng)
		var size: Vector3 = data["size"]
		var body := StaticBody3D.new()
		body.collision_layer = Colliders.WORLD
		body.transform = lot
		var mesh := MeshInstance3D.new()
		mesh.mesh = data["mesh"]
		body.add_child(mesh)
		Colliders.add_box_xform(body, Transform3D(Basis.from_scale(size), Vector3(0, size.y / 2.0, 0)))
		root.add_child(body)
		var rect := Rect2(lot.origin.x - 7.0, lot.origin.z - 7.0, 14.0, 14.0)
		decor_lots.append(rect)
		_keepout.append(rect)


## Rải cây bằng lấy mẫu loại bỏ: bỏ điểm trong vùng cấm hoặc quá gần cây khác.
func _build_trees() -> void:
	_keepout.append(Rect2(spawn_point().x - 4.0, spawn_point().z - 4.0, 8.0, 8.0))
	var round_trees: Array[Transform3D] = []
	var pines: Array[Transform3D] = []
	var trunks := Colliders.make_body(Colliders.WORLD, {"kind": "tree"}, "TreeTrunks")
	for _attempt in 900:
		var p := Vector3(_rng.randf_range(-HALF_X + 3.0, HALF_X - 3.0), 0.0,
				_rng.randf_range(-HALF_Z + 3.0, HALF_Z - 3.0))
		if is_keepout(p.x, p.z) or _too_close(p):
			continue
		tree_positions.append(p)
		var tree_scale := _rng.randf_range(0.8, 1.3)
		var xform := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * tree_scale), p)
		if _rng.randf() < 0.7:
			round_trees.append(xform)
		else:
			pines.append(xform)
		Colliders.add_box_xform(trunks, Transform3D(Basis.from_scale(Vector3(0.4, 2.0, 0.4)),
				p + Vector3(0, 1.0, 0)))
	add_child(trunks)
	_multimesh("RoundTrees", DecorFactory.round_tree(), round_trees)
	_multimesh("PineTrees", DecorFactory.pine_tree(), pines)


func _too_close(p: Vector3) -> bool:
	for q in tree_positions:
		if p.distance_squared_to(q) < TREE_MIN_DIST * TREE_MIN_DIST:
			return true
	return false


## Tường vô hình quanh rìa bản đồ.
func _build_bounds() -> void:
	var body := Colliders.make_body(Colliders.WORLD, {"kind": "bounds"}, "Bounds")
	var h := 12.0
	Colliders.add_box_xform(body, Transform3D(Basis.from_scale(Vector3(HALF_X * 2.0, h, 1.0)), Vector3(0, h / 2.0, -HALF_Z)))
	Colliders.add_box_xform(body, Transform3D(Basis.from_scale(Vector3(HALF_X * 2.0, h, 1.0)), Vector3(0, h / 2.0, HALF_Z)))
	Colliders.add_box_xform(body, Transform3D(Basis.from_scale(Vector3(1.0, h, HALF_Z * 2.0)), Vector3(-HALF_X, h / 2.0, 0)))
	Colliders.add_box_xform(body, Transform3D(Basis.from_scale(Vector3(1.0, h, HALF_Z * 2.0)), Vector3(HALF_X, h / 2.0, 0)))
	add_child(body)


func _interactable(kind: String, mesh: Mesh, size: Vector3, center: Vector3) -> StaticBody3D:
	var body := Colliders.make_body(Colliders.WORLD | Colliders.INTERACTABLE, {"kind": kind}, kind.to_pascal_case())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	Colliders.add_box_xform(body, Transform3D(Basis.from_scale(size), center))
	interactables[kind] = body
	return body


func _sign(text: String, pixel_size: float, billboard := true) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel_size
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color(1.0, 0.97, 0.85)
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label


func _multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	add_child(inst)
	return inst
