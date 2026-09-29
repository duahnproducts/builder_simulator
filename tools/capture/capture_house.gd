extends Node3D
## Chụp ảnh một căn nhà qua từng giai đoạn thi công để kiểm tra bằng mắt.
## Chạy (cần màn hình ảo trên Linux):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . res://tools/capture/capture_house.tscn
## Ảnh lưu ở test_output/ (không commit).

const OUT_DIR := "res://test_output"

var _camera := Camera3D.new()


func _ready() -> void:
	CaptureUtil.prepare_dir(OUT_DIR)
	_setup_environment()
	await _run()
	get_tree().quit()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.55, 0.3)
	ground.material_override = mat
	ground.position = Vector3(7, -0.001, 7)
	add_child(ground)
	add_child(_camera)
	_camera.current = true


func _run() -> void:
	var inv := Inventory.new()
	var bp := Catalog.blueprint("nha_cap4_nho")
	var p := ConstructionProject.new(bp, inv, "CAPTURE")
	p.required_furniture = Catalog.contract_furniture("hd01")
	var need := p.remaining_materials("paint_cream")
	for id: String in need:
		inv.add(id, need[id])
	var view := HouseView.new()
	add_child(view)
	view.setup(p)

	var outside := [Vector3(-3.5, 6.5, 20.0), Vector3(7, 1.5, 8)]
	await _shot("01_ban_ve_hologram", outside)

	for c in p.dig.cells:
		p.dig_cell(c)
	for i in floori(p.pour.cells.size() / 2.0):
		p.pour_cell(p.pour.cells[i])
	await _shot("02_dao_va_do_mong", outside)

	for c in p.pour.cells:
		p.pour_cell(c)
	for w in p.walls.size():
		var target := p.walls[w].layout.slot_count() * (1.0 if w < 2 else 0.45)
		while p.bricks[w] < int(target):
			p.lay_brick(w)
	await _shot("03_dang_xay_tuong", outside)

	for w in p.walls.size():
		while not p.is_wall_done(w):
			p.lay_brick(w)
	for k in p.openings_done.size():
		p.install_opening(k)
	for g in p.roof.gables.size():
		while not p.is_gable_done(g):
			p.lay_gable_brick(g)
	while p.roof_laid < p.roof.truss_count() + floori(p.roof.tile_count() / 2.0):
		p.lay_roof_piece()
	await _shot("04_lop_mai", outside)

	while p.roof_laid < p.roof.piece_count():
		p.lay_roof_piece()
	for w in p.walls.size():
		for side in 2:
			while p.plaster[w][side] < 1.0:
				p.apply_plaster(w, side, 5.0)
			while p.paint_progress[w][side] < 1.0:
				p.apply_paint(w, side, "paint_cream", 5.0)
	for c in p.floor_tiles.cells:
		p.tile_floor(c)
	await _shot("05_hoan_thien", outside)

	p.place_furniture("bed", Vector3(5.2, 0.3, 7.4), 0.0)
	p.place_furniture("wardrobe", Vector3(9.3, 0.3, 7.0), -PI / 2)
	p.place_furniture("table", Vector3(7.4, 0.3, 9.4), 0.0)
	p.place_furniture("chair", Vector3(7.0, 0.3, 8.8), 0.0)
	p.place_furniture("chair", Vector3(7.8, 0.3, 10.0), PI)
	view.opening_view(0).set_open(true)
	print("Hoàn thành: ", p.is_complete())
	await _shot("06_noi_that", [Vector3(9.4, 2.2, 10.5), Vector3(5.5, 0.6, 7.2)])
	await _shot("07_toan_canh", [Vector3(18, 9, 22), Vector3(7, 1.5, 8)])


func _shot(file_name: String, cam: Array) -> void:
	_camera.position = cam[0]
	_camera.look_at(cam[1])
	for i in 4:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(file_name + ".png")
	img.save_png(path)
	print("Đã lưu ", ProjectSettings.globalize_path(path))
