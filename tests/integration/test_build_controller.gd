extends TestCase
## BuildController: raycast từ camera → mục tiêu → thao tác đúng, thông báo lỗi dễ hiểu.

const R = ConstructionProject.Result
const Mode = BuildController.Mode

var project: ConstructionProject
var view: HouseView
var cam: Camera3D
var ctrl: BuildController
var toasts: Array = []


func before_each() -> void:
	GameState.new_game()
	toasts = []
	GameState.toast.connect(_on_toast)


func after_each() -> void:
	GameState.toast.disconnect(_on_toast)
	GameState.block_input("test", false)
	GameState.new_game()


func _on_toast(text: String, kind: String) -> void:
	toasts.append([text, kind])


func _last_toast() -> String:
	return str(toasts[-1][0]) if not toasts.is_empty() else ""


func _setup(stock := true) -> void:
	project = ConstructionProject.new(Fixtures.rect_house(), GameState.inventory, "T")
	GameState.add_project("T", project)
	if stock:
		var need := project.remaining_materials()
		for id: String in need:
			GameState.inventory.add(id, need[id])
	view = HouseView.new()
	add_to_tree(view)
	view.setup(project)
	cam = Camera3D.new()
	add_to_tree(cam)
	cam.current = true
	ctrl = BuildController.new()
	add_to_tree(ctrl)
	await wait_physics_frames(2)


func _aim(from: Vector3, at: Vector3) -> void:
	var up := Vector3.FORWARD if absf((at - from).normalized().y) > 0.98 else Vector3.UP
	cam.look_at_from_position(from, at, up)
	ctrl.scan()


func _finish_foundation() -> void:
	for c in project.dig.cells:
		project.dig_cell(c)
	for c in project.pour.cells:
		project.pour_cell(c)


func _finish_walls() -> void:
	for w in project.walls.size():
		while not project.is_wall_done(w):
			project.lay_brick(w)


func _finish_all_but_furniture() -> void:
	_finish_foundation()
	_finish_walls()
	for k in project.openings_done.size():
		project.install_opening(k)
	for g in project.roof.gables.size():
		while not project.is_gable_done(g):
			project.lay_gable_brick(g)
	while project.roof_laid < project.roof.piece_count():
		project.lay_roof_piece()
	for w in project.walls.size():
		for side in 2:
			while project.plaster[w][side] < 1.0:
				project.apply_plaster(w, side, 10.0)
			while project.paint_progress[w][side] < 1.0:
				project.apply_paint(w, side, "paint_white", 10.0)
	for c in project.floor_tiles.cells:
		project.tile_floor(c)


func test_dao_va_do_mong_bang_tia() -> void:
	await _setup()
	_aim(Vector3(5.5, 2.0, 3.5), Vector3(5.5, 0.0, 3.5))
	assert_eq(ctrl.current.get("kind"), "foundation")
	assert_eq(ctrl.current_action(), "dig")
	assert_eq(ctrl.perform_primary(), R.OK)
	assert_true(project.dig.is_done(Vector2i(5, 3)))
	assert_eq(ctrl.current_action(), "pour", "đào xong thì chuyển sang đổ bê tông")
	assert_eq(ctrl.perform_primary(), R.OK)
	assert_true(project.pour.is_done(Vector2i(5, 3)))


func test_xay_gach_bang_tia() -> void:
	await _setup()
	_finish_foundation()
	await wait_physics_frames(2)
	_aim(Vector3(5, 1.5, -3), Vector3(5, 1.5, 2))
	assert_eq(ctrl.current.get("kind"), "wall")
	assert_eq(ctrl.current_action(), "brick")
	for i in 3:
		assert_eq(ctrl.perform_primary(), R.OK)
	assert_eq(project.bricks[0], 3)
	assert_true(ctrl.hint.contains("Xây tường 1: 3/"), ctrl.hint)


func test_thong_bao_loi_de_hieu() -> void:
	await _setup(false)
	_aim(Vector3(5, 1.5, -3), Vector3(5, 1.5, 2))
	assert_eq(ctrl.perform_primary(), R.LOCKED)
	assert_true(_last_toast().contains("đổ xong toàn bộ móng"), _last_toast())
	GameState.inventory.add("cement", 999)
	_finish_foundation()
	assert_eq(ctrl.perform_primary(), R.NO_MATERIAL)
	assert_true(_last_toast().contains("Thiếu Gạch"), _last_toast())


func test_trat_va_son_bang_tia() -> void:
	await _setup()
	_finish_foundation()
	_finish_walls()
	await wait_physics_frames(2)
	_aim(Vector3(5, 1.5, -3), Vector3(5, 1.5, 2))
	assert_eq(ctrl.current.get("kind"), "wall_built")
	assert_eq(ctrl.current.get("side"), 0)
	assert_eq(ctrl.current_action(), "plaster")
	assert_eq(ctrl.perform_primary(), R.OK)
	assert_gt(project.plaster[0][0], 0.0)
	ctrl.set_mode(Mode.PAINT)
	ctrl.scan()
	assert_eq(ctrl.current_action(), "paint")
	assert_eq(ctrl.perform_primary(), R.LOCKED, "chưa trát xong thì chưa sơn")
	while project.plaster[0][0] < 1.0:
		project.apply_plaster(0, 0, 5.0)
	GameState.inventory.add("paint_blue", 5)
	ctrl.paint_item = "paint_blue"
	assert_eq(ctrl.perform_primary(), R.OK)
	assert_eq(project.paint_color[0][0], "paint_blue")


func test_dat_va_nhat_noi_that() -> void:
	await _setup()
	_finish_all_but_furniture()
	GameState.inventory.add("table", 2)
	await wait_physics_frames(2)
	ctrl.set_mode(Mode.FURNITURE)
	assert_eq(ctrl.furniture_item, "table")
	_aim(Vector3(4.5, 2.0, 4.0), Vector3(4.5, 0.0, 4.2))
	assert_true(ctrl.placement.valid, ctrl.placement.reason)
	assert_eq(ctrl.perform_primary(), R.OK)
	assert_eq(project.furniture.size(), 1)
	await wait_physics_frames(2)
	ctrl.scan()
	assert_false(ctrl.placement.valid, "chỗ đã có bàn thì không đặt chồng lên được")
	ctrl.set_mode(Mode.REMOVE)
	_aim(Vector3(4.5, 2.0, 5.5), Vector3(4.5, 0.6, 4.2))
	assert_eq(ctrl.current.get("kind"), "furniture")
	assert_eq(ctrl.perform_primary(), R.OK)
	assert_eq(project.furniture.size(), 0)
	assert_eq(GameState.inventory.count("table"), 2, "nhặt lên thì trả về kho")


func test_noi_that_vuong_tuong_thi_khong_dat_duoc() -> void:
	await _setup()
	_finish_all_but_furniture()
	GameState.inventory.add("sofa", 1)
	await wait_physics_frames(2)
	ctrl.set_mode(Mode.FURNITURE)
	_aim(Vector3(2.6, 2.0, 4.0), Vector3(2.4, 0.0, 4.0))
	assert_false(ctrl.placement.valid, "sofa dài 2 m đặt sát tường thì bị vướng")
	assert_true(ctrl.placement.reason.contains("Vướng"), ctrl.placement.reason)


func test_tuong_tac_mo_cua() -> void:
	await _setup()
	_finish_foundation()
	_finish_walls()
	assert_eq(project.install_opening(0), R.OK)
	await wait_physics_frames(2)
	_aim(Vector3(4.9, 1.5, 8.0), Vector3(4.9, 1.2, 6.0))
	assert_true(ctrl.interact())
	assert_true(view.opening_view(0).is_open)


func test_doi_che_do_va_lua_chon() -> void:
	await _setup()
	ctrl.set_mode(Mode.PAINT)
	var first := ctrl.paint_item
	ctrl.cycle_selection(1)
	assert_ne(ctrl.paint_item, first)
	ctrl.cycle_selection(-1)
	assert_eq(ctrl.paint_item, first)
	ctrl.set_mode(Mode.FURNITURE)
	assert_eq(ctrl.furniture_item, "", "kho chưa có nội thất")
	GameState.inventory.add("sofa", 1)
	assert_eq(ctrl.furniture_item, "sofa", "mua về thì tự chọn món đó")


func test_mo_giao_dien_thi_ngung_nham() -> void:
	await _setup()
	_aim(Vector3(5.5, 2.0, 3.5), Vector3(5.5, 0.0, 3.5))
	assert_ne(ctrl.hint, "")
	GameState.block_input("test", true)
	await wait_physics_frames(2)
	assert_eq(ctrl.hint, "")


func test_nhin_vao_vat_khong_phai_nha_khong_bao_loi() -> void:
	await _setup()
	var ground := Colliders.make_body(Colliders.WORLD, {}, "Ground")
	Colliders.add_box_xform(ground, Transform3D(Basis.from_scale(Vector3(4, 0.2, 4)), Vector3(20, -0.1, 20)))
	add_to_tree(ground)
	await wait_physics_frames(1)
	# Runner bắt mọi lỗi runtime: get_meta("house", null) từng báo lỗi mỗi frame khi nhìn xuống đất.
	_aim(Vector3(20, 2, 20), Vector3(20, 0, 20))
	assert_eq(ctrl.current.get("kind"), "world", "vật không có metadata thì coi là 'world'")
	assert_eq(ctrl.current_action(), "")
	assert_eq(ctrl.perform_primary(), -1, "không có gì để làm")
