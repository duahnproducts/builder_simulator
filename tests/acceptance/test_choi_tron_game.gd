extends TestCase
## NGHIỆM THU: chơi trọn game trên scene chính (thế giới + nhân vật + giao diện) như người chơi thật.
## Mọi thao tác đi qua đúng đường của người chơi: nhắm camera → BuildController → bấm chuột / phím.
## (AutoBuilder chỉ thay tay và mắt người chơi, không gọi thẳng luật thi công.)

const Mode = BuildController.Mode

var main: Main
var world: World
var ui: UIRoot
var ctrl: BuildController
var cam: Camera3D
var bot: AutoBuilder
var toasts: Array[String] = []


func before_each() -> void:
	GameState.new_game()
	toasts.clear()
	GameState.toast.connect(_on_toast)


func after_each() -> void:
	GameState.toast.disconnect(_on_toast)
	runner.get_tree().paused = false
	for id in ["shop", "contracts", "blueprint", "pause"]:
		GameState.block_input(id, false)
	SaveSystem.delete_slot(SaveSystem.QUICK_SLOT)
	GameState.new_game()


func _on_toast(text: String, _kind: String) -> void:
	toasts.append(text)


func _start() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_tree(main)
	world = main.world
	ui = main.ui
	ctrl = main.build_controller
	world.day_night.running = false  # giữ nguyên giờ để so sánh trước/sau khi lưu
	cam = Camera3D.new()
	cam.name = "TestEyes"
	add_to_tree(cam)
	cam.current = true
	bot = AutoBuilder.new(fail, ctrl, cam)
	await wait_physics_frames(2)


## Đi tới vật tương tác (bảng hợp đồng, quầy hàng, bàn vẽ), nhìn vào rồi bấm E.
func _use(kind: String) -> void:
	assert_true(bot.aim_at_body(world.interactables[kind], {"kind": kind}), "nhìn thấy " + kind)
	assert_true(ctrl.hint.begins_with("[E]"), "có gợi ý bấm E: " + ctrl.hint)
	bot.press_key(KEY_E)


## Toàn bộ công trình đã hiện đúng trên màn hình (không chỉ đúng trong dữ liệu).
func _assert_house_fully_shown(house: HouseView) -> void:
	var p := house.project
	assert_eq(house.cells_view("pour").visible_count(), p.pour.total(), "móng hiện đủ")
	assert_eq(house.cells_view("floor").visible_count(), p.floor_tiles.total(), "nền hiện đủ")
	for w in p.walls.size():
		assert_eq(house.wall_view(w).visible_bricks(), p.walls[w].layout.slot_count(), "tường %d hiện đủ gạch" % w)
		assert_not_null(house.wall_view(w).finish_mesh(0), "tường %d có lớp sơn mặt 0" % w)
		assert_not_null(house.wall_view(w).finish_mesh(1), "tường %d có lớp sơn mặt 1" % w)
	for k in p.openings_done.size():
		assert_true(house.opening_view(k).installed, "cửa %d đã lắp" % k)
	if p.roof != null:
		for g in p.roof.gables.size():
			assert_eq(house.gable_view(g).visible_bricks(), p.roof.gables[g].layout.slot_count())
		assert_eq(house.roof_view().visible_counts(),
				Vector3i(p.roof.truss_count(), p.roof.tile_count(), p.roof.ridge_count()), "mái hiện đủ")
	else:
		assert_eq(house.cells_view("roof").visible_count(), p.roof_cells.total(), "mái bằng hiện đủ")
	for f in p.furniture:
		assert_not_null(house.furniture_view(int(f["uid"])), "nội thất %s hiện trong nhà" % f["id"])


func test_hop_dong_dau_tien_tu_nhan_viec_den_nghiem_thu_roi_luu_tai() -> void:
	await _start()
	assert_true(ui.help.visible, "mới vào game thì hiện bảng hướng dẫn")

	# 1. Ra bảng hợp đồng, bấm E, nhận hợp đồng đầu tiên.
	_use("job_board")
	assert_eq(ui.open_panel_id(), "contracts", "bấm E vào bảng thì mở bảng hợp đồng")
	assert_true(GameState.is_input_blocked(), "đang mở bảng thì nhân vật đứng yên")
	var contracts: ContractPanel = ui.panels["contracts"]
	assert_eq(contracts.selected, "hd01", "mặc định chọn hợp đồng nhận được")
	assert_eq(contracts.accept(), "")
	bot.press_key(KEY_ESCAPE)
	assert_eq(ui.open_panel_id(), "", "Esc đóng bảng")
	assert_false(GameState.is_input_blocked())
	var house := world.house_view("A1")
	assert_not_null(house, "nhận việc thì bản vẽ hiện trên lô A1")
	if house == null:
		return
	var p := house.project

	# 2. Chọn màu sơn (phím 2 rồi Q), ra quầy hàng mua đủ vật tư.
	var paint: String = Catalog.paint_ids()[2]
	bot.set_mode(Mode.PAINT)
	bot.select_item(paint)
	bot.set_mode(Mode.BUILD)
	_use("shop")
	assert_eq(ui.open_panel_id(), "shop")
	var shop: ShopPanel = ui.panels["shop"]
	var need := p.remaining_materials(paint)
	var money := GameState.wallet.balance
	assert_true(shop.buy_all_for_current(), "đủ tiền mua hết vật tư cho hợp đồng đầu")
	assert_eq(money - GameState.wallet.balance, Catalog.cost_of(need), "trả đúng tiền vật tư")
	bot.press_key(KEY_ESCAPE)

	# 3. Tới lô A1 và thi công lần lượt từng hạng mục.
	main.player.global_position = world.plot_node("A1").to_global(Vector3(7.0, 0.1, 13.0))
	assert_eq(ui.hud.current_plot_id(), "A1")
	await bot.build_foundation(house)
	assert_eq(p.stage_status("walls"), ConstructionProject.Status.AVAILABLE, "đổ móng xong thì mở khoá xây tường")
	await bot.build_walls(house)
	assert_true(p.are_walls_done())
	await bot.install_openings(house)
	await bot.build_roof(house)
	assert_true(p.is_roof_done(), "mái lợp xong")
	await bot.plaster_and_paint(house)
	await bot.tile_floor(house)
	assert_false(p.is_complete(), "chưa có nội thất thì chưa xong")
	var placed := await bot.furnish(house, p.required_furniture)
	assert_eq(placed, 5, "đặt đủ 5 món theo hợp đồng")
	assert_true(p.is_complete(), "hoàn thành mọi hạng mục: " + str(p.missing_furniture()))
	for w in p.walls.size():
		assert_eq(p.paint_color[w], [paint, paint], "sơn đúng màu đã chọn")
	assert_eq(GameState.inventory.to_dict(), {}, "mua vừa đủ: xây xong thì kho không thừa, không thiếu")
	await wait_physics_frames(1)
	_assert_house_fully_shown(house)
	ui.hud.refresh_project()
	assert_true(ui.hud.project_text().contains("nghiệm thu"), "HUD nhắc đi nghiệm thu")

	# 4. Quay lại bảng hợp đồng để nghiệm thu, nhận tiền và uy tín.
	money = GameState.wallet.balance
	_use("job_board")
	assert_eq(ui.open_panel_id(), "contracts")
	assert_eq(contracts.complete(), "")
	assert_eq(GameState.wallet.balance, money + Catalog.contract_reward("hd01"), "nhận tiền công")
	assert_eq(GameState.reputation, 1, "uy tín tăng")
	assert_eq(GameState.contract_status("hd02"), "available", "đủ uy tín thì mở hợp đồng tiếp theo")
	assert_true(world.plot_node("A1").label_text().contains("Đã hoàn thành"))
	bot.press_key(KEY_ESCAPE)
	assert_gt(Catalog.contract_reward("hd01"), Catalog.cost_of(need), "hợp đồng có lãi")

	# 5. Lưu nhanh (F5) → ván mới → tải nhanh (F9): mọi thứ trở lại như lúc lưu.
	var saved := JSON.stringify(GameState.to_dict())
	var saved_pos := main.player.global_position
	bot.press_key(KEY_F5)
	assert_has(toasts, "Đã lưu game.")
	GameState.new_game()
	assert_eq(world.house_view("A1"), null, "ván mới thì lô A1 trống")
	assert_vec_near(main.player.global_position, world.spawn_point(), 0.01, "ván mới thì về điểm xuất phát")
	bot.press_key(KEY_F9)
	assert_has(toasts, "Đã tải bản lưu nhanh.")
	assert_eq(JSON.stringify(GameState.to_dict()), saved, "trạng thái sau khi tải giống hệt lúc lưu")
	assert_vec_near(main.player.global_position, saved_pos, 0.01, "nhân vật về đúng chỗ lúc lưu")
	var loaded := world.house_view("A1")
	assert_not_null(loaded, "tải xong thì nhà hiện lại trên lô A1")
	if loaded != null:
		_assert_house_fully_shown(loaded)
	print("    (thợ tự động đã bấm chuột %d lần)" % bot.clicks)


func test_nha_rieng_mai_bang_tu_ban_ve() -> void:
	await _start()
	# 1. Ra bàn vẽ ở đất nhà mình, bấm E, chọn mẫu nhà chữ L mái bằng rồi bắt đầu xây.
	main.player.global_position = world.plot_node(GameState.HOME_PLOT).to_global(Vector3(7.0, 0.1, 13.0))
	_use("drawing_table")
	assert_eq(ui.open_panel_id(), "blueprint", "bấm E vào bàn vẽ thì mở bàn vẽ")
	var editor: BlueprintEditor = ui.panels["blueprint"]
	assert_true(editor.load_template("nha_mai_bang_L"))
	assert_eq(editor.validation_errors().size(), 0)
	assert_eq(editor.start_building(), "")
	assert_eq(ui.open_panel_id(), "", "bắt đầu xây thì đóng bàn vẽ")
	var house := world.house_view(GameState.HOME_PLOT)
	assert_not_null(house)
	if house == null:
		return
	var p := house.project
	assert_true(p.is_flat_roof())

	# 2. Phím B mở cửa hàng: mua đủ vật tư + thêm hai món nội thất để trang trí.
	bot.press_key(KEY_B)
	assert_eq(ui.open_panel_id(), "shop", "phím B mở cửa hàng")
	var shop: ShopPanel = ui.panels["shop"]
	var cost := Catalog.cost_of(p.remaining_materials()) + Catalog.price("sofa") + Catalog.price("plant")
	if GameState.wallet.balance < cost:
		GameState.wallet.earn(cost - GameState.wallet.balance)  # nhà riêng to hơn vốn ban đầu
	assert_true(shop.buy_all_for_current())
	assert_true(shop.buy("sofa", 1))
	assert_true(shop.buy("plant", 1))
	bot.press_key(KEY_B)
	assert_eq(ui.open_panel_id(), "", "bấm B lần nữa thì đóng cửa hàng")

	# 3. Thi công: móng → 8 bức tường (có 2 tường ngăn) → cửa → mái bằng → trát, sơn → nền → nội thất.
	await bot.build_foundation(house)
	await bot.build_walls(house)
	await bot.install_openings(house)
	await bot.build_roof(house)
	assert_true(p.is_roof_done(), "đổ xong mái bằng")
	await bot.plaster_and_paint(house)
	await bot.tile_floor(house)
	assert_true(p.is_complete(), "nhà riêng không bắt buộc nội thất")
	assert_eq(await bot.furnish(house, {"sofa": 1, "plant": 1}), 2)
	assert_eq(GameState.inventory.to_dict(), {}, "dùng hết vật tư đã mua")
	await wait_physics_frames(1)
	_assert_house_fully_shown(house)
	assert_true(world.plot_node(GameState.HOME_PLOT).label_text().contains("Nhà của bạn"))
	assert_eq(GameState.active_contract, "", "nhà riêng không phải hợp đồng")
