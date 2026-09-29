extends TestCase
## GameState: mua bán, hợp đồng, công trình nhà mình, chặn điều khiển, thời gian, lưu/tải.


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	GameState.new_game()


## Mua đủ vật tư rồi làm xong mọi hạng mục của công trình (kể cả nội thất bắt buộc).
func _finish_project(p: ConstructionProject) -> void:
	GameState.wallet.balance = 10_000_000_000
	assert_true(GameState.buy_many(GameState.missing_for_project(p.plot_id)))
	for c in p.dig.cells:
		p.dig_cell(c)
	for c in p.pour.cells:
		p.pour_cell(c)
	for w in p.walls.size():
		while not p.is_wall_done(w):
			p.lay_brick(w)
	for k in p.openings_done.size():
		p.install_opening(k)
	if p.roof != null:
		for g in p.roof.gables.size():
			while not p.is_gable_done(g):
				p.lay_gable_brick(g)
		while p.roof_laid < p.roof.piece_count():
			p.lay_roof_piece()
	else:
		for c in p.roof_cells.cells:
			p.pour_roof_cell(c)
	for w in p.walls.size():
		for side in 2:
			while p.plaster[w][side] < 1.0:
				p.apply_plaster(w, side, 10.0)
			while p.paint_progress[w][side] < 1.0:
				p.apply_paint(w, side, "paint_white", 10.0)
	for c in p.floor_tiles.cells:
		p.tile_floor(c)
	var cell := p.analysis.interior_cells[0]
	for item_id: String in p.required_furniture:
		for i in int(p.required_furniture[item_id]):
			p.place_furniture(item_id, Vector3(cell.x + 0.5, 0.3, cell.y + 0.5), 0.0)


func test_van_moi() -> void:
	assert_eq(GameState.wallet.balance, Catalog.start_money)
	assert_eq(GameState.inventory.item_ids().size(), 0)
	assert_eq(GameState.reputation, 0)
	assert_eq(GameState.projects.size(), 0)


func test_mua_ban() -> void:
	var money := GameState.wallet.balance
	assert_true(GameState.buy("brick", 100))
	assert_eq(GameState.wallet.balance, money - 600_000)
	assert_eq(GameState.inventory.count("brick"), 100)
	assert_false(GameState.buy("brick", 1_000_000_000), "không đủ tiền")
	assert_eq(GameState.inventory.count("brick"), 100)
	assert_false(GameState.buy("khong_co", 1))
	assert_true(GameState.sell("brick", 10))
	assert_eq(GameState.wallet.balance, money - 600_000 + 42_000, "bán lại 70% giá")
	assert_false(GameState.sell("brick", 1000))


func test_mua_ca_danh_sach_tat_ca_hoac_khong() -> void:
	GameState.wallet.balance = 100_000
	assert_false(GameState.buy_many({"brick": 10, "cement": 5}))
	assert_eq(GameState.inventory.item_ids().size(), 0, "không đủ tiền thì không mua món nào")
	assert_true(GameState.buy_many({"brick": 10}))
	assert_eq(GameState.wallet.balance, 40_000)


func test_quy_trinh_hop_dong() -> void:
	assert_eq(GameState.contract_status("hd01"), "available")
	assert_eq(GameState.contract_status("hd02"), "locked")
	assert_eq(GameState.accept_contract("hd02"), "Chưa đủ uy tín để nhận hợp đồng này.")
	assert_eq(GameState.accept_contract("hd01"), "")
	assert_eq(GameState.contract_status("hd01"), "active")
	var p := GameState.project_at("A1")
	assert_not_null(p)
	assert_eq(p.required_furniture, Catalog.contract_furniture("hd01"))
	assert_ne(GameState.accept_contract("hd01"), "", "không nhận lại lần hai")
	assert_true(GameState.complete_contract("hd01").contains("chưa hoàn thành"))
	_finish_project(p)
	assert_true(p.is_complete())
	var money := GameState.wallet.balance
	assert_eq(GameState.complete_contract("hd01"), "")
	assert_eq(GameState.wallet.balance, money + Catalog.contract_reward("hd01"))
	assert_eq(GameState.reputation, 1)
	assert_eq(GameState.contract_status("hd01"), "done")
	assert_eq(GameState.contract_status("hd02"), "available", "đủ uy tín thì mở hợp đồng mới")
	assert_not_null(GameState.project_at("A1"), "nhà đã xây xong vẫn đứng trên lô đất")


func test_huy_hop_dong() -> void:
	GameState.accept_contract("hd01")
	assert_eq(GameState.contract_status("hd02"), "locked")
	assert_eq(GameState.abandon_contract("hd01"), "")
	assert_eq(GameState.project_at("A1"), null)
	assert_eq(GameState.contract_status("hd01"), "available")


func test_dang_lam_thi_khong_nhan_them() -> void:
	GameState.reputation = 10
	assert_eq(GameState.accept_contract("hd01"), "")
	assert_eq(GameState.contract_status("hd02"), "busy")


func test_xay_nha_minh() -> void:
	var bad := Blueprint.new()
	assert_ne(GameState.start_home_project(bad), "")
	assert_eq(GameState.start_home_project(Catalog.blueprint("nha_cap4_nho")), "")
	assert_not_null(GameState.project_at(GameState.HOME_PLOT))
	GameState.project_at(GameState.HOME_PLOT).dig_cell(Vector2i(4, 6))
	assert_ne(GameState.start_home_project(Catalog.blueprint("nha_ong")), "", "đang xây dở thì không thay bản vẽ")
	GameState.demolish_home_project()
	assert_eq(GameState.start_home_project(Catalog.blueprint("nha_ong")), "")


func test_chan_dieu_khien_theo_nguon() -> void:
	var events: Array = []
	GameState.input_blocked_changed.connect(func(b: bool) -> void: events.append(b))
	GameState.block_input("shop", true)
	GameState.block_input("pause", true)
	GameState.block_input("shop", false)
	assert_true(GameState.is_input_blocked(), "còn menu tạm dừng đang mở")
	GameState.block_input("pause", false)
	assert_false(GameState.is_input_blocked())
	assert_eq(events, [true, false], "chỉ báo khi trạng thái thật sự đổi")


func test_thoi_gian() -> void:
	GameState.advance_time(20.0)
	assert_eq(GameState.day, 2)
	assert_near(GameState.time_of_day, 3.0)
	assert_eq(GameState.clock_text(), "Ngày 2 — 03:00")


func test_luu_va_tai() -> void:
	GameState.buy("brick", 50)
	GameState.accept_contract("hd01")
	var p := GameState.project_at("A1")
	for c in p.dig.cells:
		p.dig_cell(c)
	GameState.advance_time(3.5)
	var text := JSON.stringify(GameState.to_dict())
	GameState.new_game()
	assert_eq(GameState.projects.size(), 0)
	assert_eq(GameState.from_dict(JSON.parse_string(text)), "")
	assert_eq(JSON.stringify(GameState.to_dict()), text)
	assert_eq(GameState.contract_status("hd01"), "active")
	assert_true(GameState.project_at("A1").dig.is_complete())


func test_tu_choi_file_luu_sai_phien_ban() -> void:
	GameState.buy("brick", 5)
	var money := GameState.wallet.balance
	assert_ne(GameState.from_dict({"version": 99}), "")
	assert_ne(GameState.from_dict({}), "")
	assert_eq(GameState.wallet.balance, money, "tải thất bại thì trạng thái giữ nguyên")
	assert_eq(GameState.inventory.count("brick"), 5)
