extends TestCase
## Giao diện: mở/đóng bảng, cửa hàng, hợp đồng, bàn vẽ, menu tạm dừng, HUD, phím tắt.

var ui: UIRoot
var build: BuildController
var world: World


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	runner.get_tree().paused = false
	for slot in ["test_ui"]:
		SaveSystem.delete_slot(slot)
	GameState.new_game()
	# Đóng mọi nguồn chặn điều khiển còn sót để test sau không bị ảnh hưởng.
	for id in ["shop", "contracts", "blueprint", "pause"]:
		GameState.block_input(id, false)


func _setup() -> void:
	world = World.new()
	add_to_tree(world)
	world.build()
	world.day_night.running = false
	build = BuildController.new()
	add_to_tree(build)
	ui = UIRoot.new()
	add_to_tree(ui)
	ui.setup(build, world)
	await wait_frames(1)


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	return ev


func _finish(p: ConstructionProject) -> void:
	GameState.wallet.balance = 10_000_000_000
	GameState.buy_many(GameState.missing_for_project(p.plot_id))
	for c in p.dig.cells:
		p.dig_cell(c)
	for c in p.pour.cells:
		p.pour_cell(c)
	for w in p.walls.size():
		while not p.is_wall_done(w):
			p.lay_brick(w)
	for k in p.openings_done.size():
		p.install_opening(k)
	for g in p.roof.gables.size():
		while not p.is_gable_done(g):
			p.lay_gable_brick(g)
	while p.roof_laid < p.roof.piece_count():
		p.lay_roof_piece()
	for w in p.walls.size():
		for side in 2:
			while p.plaster[w][side] < 1.0:
				p.apply_plaster(w, side, 10.0)
			while p.paint_progress[w][side] < 1.0:
				p.apply_paint(w, side, "paint_white", 10.0)
	for c in p.floor_tiles.cells:
		p.tile_floor(c)
	var cell := p.analysis.interior_cells[0]
	for id: String in p.required_furniture:
		for i in int(p.required_furniture[id]):
			p.place_furniture(id, Vector3(cell.x + 0.5, 0.3, cell.y + 0.5), 0.0)


func test_chi_mo_mot_bang_va_chan_dieu_khien() -> void:
	await _setup()
	for id in ["shop", "contracts", "blueprint", "pause"]:
		assert_true(ui.panels.has(id), "thiếu bảng " + id)
	ui.open_panel("shop")
	assert_true(GameState.is_input_blocked())
	ui.open_panel("contracts")
	assert_eq(ui.open_panel_id(), "contracts", "mở bảng mới thì bảng cũ đóng")
	assert_false(ui.panels["shop"].is_open())
	ui.close_panel("contracts")
	assert_false(GameState.is_input_blocked())


func test_phim_tat() -> void:
	await _setup()
	ui._unhandled_input(_key(KEY_B))
	assert_eq(ui.open_panel_id(), "shop")
	ui._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(ui.open_panel_id(), "", "Esc đóng bảng đang mở")
	ui._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(ui.open_panel_id(), "pause", "không có bảng nào thì Esc mở menu tạm dừng")
	assert_true(runner.get_tree().paused)
	ui._unhandled_input(_key(KEY_ESCAPE))
	assert_false(runner.get_tree().paused)


func test_cua_hang_mua_ban_va_mua_du() -> void:
	await _setup()
	var shop: ShopPanel = ui.panels["shop"]
	ui.open_panel("shop")
	var money := GameState.wallet.balance
	assert_true(shop.buy("brick", 100))
	assert_eq(GameState.wallet.balance, money - 600_000)
	assert_true(shop.sell("brick", 1))
	assert_false(shop.sell("door_wood", 1))
	assert_eq(GameState.accept_contract("hd01"), "")
	shop.refresh()
	GameState.wallet.balance = 10_000_000_000
	assert_true(shop.buy_all_for_current())
	assert_eq(GameState.missing_for_project("A1").size(), 0, "mua đủ thì không còn thiếu gì")


func test_bang_hop_dong_nhan_va_nghiem_thu() -> void:
	await _setup()
	var panel: ContractPanel = ui.panels["contracts"]
	ui.open_panel("contracts")
	assert_eq(panel.selected, "hd01", "mặc định chọn hợp đồng có thể nhận")
	assert_eq(panel.accept(), "")
	assert_eq(GameState.contract_status("hd01"), "active")
	assert_ne(panel.complete(), "", "chưa xong thì không nghiệm thu được")
	_finish(GameState.project_at("A1"))
	var money := GameState.wallet.balance
	assert_eq(panel.complete(), "")
	assert_eq(GameState.wallet.balance, money + Catalog.contract_reward("hd01"))
	panel.select_contract("hd02")
	assert_eq(panel.selected, "hd02")


func test_ban_ve_ve_tuong_dat_cua_hoan_tac() -> void:
	await _setup()
	var editor: BlueprintEditor = ui.panels["blueprint"]
	ui.open_panel("blueprint")
	assert_eq(editor.blueprint.wall_count(), 0)
	assert_false(editor.add_wall(Vector2i(2, 2), Vector2i(5, 6)), "không cho tường chéo")
	assert_true(editor.add_wall(Vector2i(3, 4), Vector2i(9, 4)))
	assert_true(editor.add_wall(Vector2i(9, 4), Vector2i(9, 9)))
	assert_true(editor.add_wall(Vector2i(3, 9), Vector2i(9, 9)))
	assert_true(editor.add_wall(Vector2i(3, 4), Vector2i(3, 9)))
	assert_true(editor.validation_errors().has("Có 1 phòng không có cửa đi vào."))
	assert_true(editor.add_opening_at(Vector2(6.0, 9.05), "door"), "bấm gần tường trước để đặt cửa")
	assert_eq(editor.validation_errors().size(), 0, " | ".join(editor.validation_errors()))
	assert_gt(editor.estimated_cost(), 0)
	assert_true(editor.add_opening_at(Vector2(3.0, 6.5), "window"))
	assert_true(editor.undo())
	assert_eq(editor.blueprint.openings.size(), 1, "hoàn tác bỏ cửa sổ vừa đặt")
	assert_true(editor.erase_at(Vector2(6.0, 9.0)), "tẩy trúng cửa trước")
	assert_eq(editor.blueprint.openings.size(), 0)
	editor.undo()
	assert_eq(editor.start_building(), "")
	assert_not_null(GameState.project_at(GameState.HOME_PLOT))
	assert_false(editor.is_open(), "bắt đầu xây thì đóng bàn vẽ")
	assert_not_null(world.house_view(GameState.HOME_PLOT), "công trình hiện trên đất nhà bạn")


func test_ban_ve_nap_mau_va_doi_mai() -> void:
	await _setup()
	var editor: BlueprintEditor = ui.panels["blueprint"]
	ui.open_panel("blueprint")
	assert_true(editor.load_template("nha_mai_bang_L"))
	assert_eq(editor.validation_errors().size(), 0)
	editor.set_roof("gable")
	assert_true(" ".join(editor.validation_errors()).contains("Mái ngói"))
	editor.undo()
	assert_eq(editor.blueprint.roof, "flat")


func test_menu_tam_dung_luu_tai() -> void:
	await _setup()
	var pause: PauseMenu = ui.panels["pause"]
	ui.open_panel("pause")
	assert_true(runner.get_tree().paused)
	GameState.buy("brick", 42)
	assert_eq(pause.save("test_ui"), "")
	GameState.new_game()
	assert_eq(GameState.inventory.count("brick"), 0)
	assert_eq(pause.load_game("test_ui"), "")
	assert_eq(GameState.inventory.count("brick"), 42)
	assert_false(runner.get_tree().paused, "tải xong thì đóng menu, chơi tiếp")


func test_hud_nam_trong_man_hinh() -> void:
	await _setup()
	GameState.accept_contract("hd01")
	ui.hud.refresh_project()
	GameState.notify("Kiểm tra bố cục", "info")
	await wait_frames(3)
	var screen := ui.hud.get_viewport_rect()
	var rects := ui.hud.element_rects()
	for key: String in rects:
		var r: Rect2 = rects[key]
		assert_true(screen.encloses(r), "%s tràn ra ngoài màn hình %s: %s" % [key, str(screen), str(r)])
	var cross: Rect2 = rects["crosshair"]
	assert_vec_near(cross.get_center(), screen.get_center(), 2.0, "tâm ngắm ở giữa màn hình")


func test_mo_bang_thi_hud_gon_lai_va_co_nen_mo() -> void:
	await _setup()
	GameState.accept_contract("hd01")
	ui.hud.refresh_project()
	assert_true(ui.hud.is_project_visible())
	assert_false(ui.is_backdrop_visible())
	ui.open_panel("shop")
	assert_true(ui.is_backdrop_visible(), "mở bảng thì có nền mờ phía sau")
	assert_true(ui.hud.panel_mode)
	assert_false(ui.hud.is_project_visible(), "checklist không chồng lên bảng")
	ui.open_panel("contracts")
	assert_true(ui.is_backdrop_visible(), "chuyển bảng thì nền mờ vẫn còn")
	ui.close_panel("contracts")
	assert_false(ui.is_backdrop_visible())
	assert_false(ui.hud.panel_mode)
	assert_true(ui.hud.is_project_visible())


func test_danh_sach_hop_dong_hien_ten_va_trang_thai() -> void:
	await _setup()
	var panel: ContractPanel = ui.panels["contracts"]
	ui.open_panel("contracts")
	assert_eq(panel.row_status_text("hd01"), "Có thể nhận")
	assert_eq(panel.row_status_text("hd05"), "Chưa mở — cần thêm uy tín")
	assert_eq(panel.pressed_rows(), ["hd01"])
	panel.select_contract("hd03")
	assert_eq(panel.pressed_rows(), ["hd03"], "chỉ một hàng được chọn")
	panel.select_contract("hd01")
	panel.accept()
	assert_eq(panel.row_status_text("hd01"), "ĐANG LÀM", "nhận xong thì hàng cập nhật trạng thái")
	assert_eq(panel.row_status_text("hd02"), "Chưa mở — cần thêm uy tín")


func test_hud_cap_nhat() -> void:
	await _setup()
	GameState.buy("cement", 1)
	assert_eq(ui.hud.money_text(), Money.format(GameState.wallet.balance))
	var before := ui.hud.toast_count()
	GameState.notify("Xin chào", "ok")
	assert_eq(ui.hud.toast_count(), before + 1)
	build.set_mode(BuildController.Mode.PAINT)
	assert_eq(ui.hud.highlighted_mode(), BuildController.Mode.PAINT)
	GameState.accept_contract("hd01")
	assert_eq(ui.hud.current_plot_id(), "A1", "không đứng ở lô nào thì hiện hợp đồng đang làm")
