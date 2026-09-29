extends TestCase
## SaveSystem: lưu/tải khứ hồi, chặn tên ô nguy hiểm, file hỏng, file quá lớn.

const SLOT := "test_save"


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	SaveSystem.delete_slot(SLOT)
	SaveSystem.max_file_bytes = SaveSystem.MAX_FILE_BYTES
	GameState.new_game()


func _write_raw(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var f := FileAccess.open(SaveSystem.slot_path(SLOT), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_luu_tai_khu_hoi() -> void:
	GameState.buy("brick", 12)
	GameState.accept_contract("hd01")
	GameState.project_at("A1").dig_cell(GameState.project_at("A1").dig.cells[0])
	var before := JSON.stringify(GameState.to_dict())
	assert_eq(SaveSystem.save_slot(SLOT), "")
	assert_false(FileAccess.file_exists(SaveSystem.slot_path(SLOT) + ".tmp"), "không để lại file tạm")
	GameState.new_game()
	assert_eq(SaveSystem.load_slot(SLOT), "")
	assert_eq(JSON.stringify(GameState.to_dict()), before)
	var info := SaveSystem.slot_info(SLOT)
	assert_true(info["exists"])
	assert_eq(info["money"], GameState.wallet.balance)


func test_chan_ten_o_luu_nguy_hiem() -> void:
	for bad in ["", "../hack", "a/b", "SLOT", "x".repeat(40), "slot 1", "..", "c:\\x"]:
		assert_false(SaveSystem.is_valid_slot(bad), "phải chặn: " + bad)
		assert_ne(SaveSystem.save_slot(bad), "")
	assert_true(SaveSystem.is_valid_slot("slot1"))
	assert_true(SaveSystem.is_valid_slot("quick"))


func test_file_hong_khong_lam_doi_trang_thai() -> void:
	GameState.buy("brick", 7)
	_write_raw("{ đây không phải JSON")
	assert_true(SaveSystem.load_slot(SLOT).contains("bị hỏng"))
	_write_raw(JSON.stringify({"format": "game_khac", "game": {}}))
	assert_true(SaveSystem.load_slot(SLOT).contains("Không phải file lưu"))
	_write_raw(JSON.stringify({"format": SaveSystem.FORMAT, "game": {"version": 999}}))
	assert_ne(SaveSystem.load_slot(SLOT), "")
	assert_eq(GameState.inventory.count("brick"), 7, "tải lỗi thì trạng thái giữ nguyên")


func test_file_qua_lon() -> void:
	assert_eq(SaveSystem.save_slot(SLOT), "")
	SaveSystem.max_file_bytes = 100
	assert_true(SaveSystem.load_slot(SLOT).contains("quá lớn"))


func test_o_trong() -> void:
	SaveSystem.delete_slot(SLOT)
	assert_true(SaveSystem.load_slot(SLOT).contains("Chưa có bản lưu"))
	assert_false(SaveSystem.slot_info(SLOT)["exists"])


func test_bo_test_khong_dung_file_luu_that() -> void:
	assert_ne(SaveSystem.save_dir, SaveSystem.DIR, "runner chuyển file lưu sang thư mục riêng cho test")
	assert_false(SaveSystem.autosave_enabled, "không tự lưu khi đang chạy test")
	assert_true(SaveSystem.slot_path(SLOT).begins_with(SaveSystem.save_dir))


func test_khoi_phuc_khi_tat_game_giua_luc_luu() -> void:
	GameState.buy("brick", 9)
	assert_eq(SaveSystem.save_slot(SLOT), "")
	# Giả lập tắt game đúng lúc thay file: file cũ đã xoá, file mới vẫn mang tên .tmp.
	var path := SaveSystem.slot_path(SLOT)
	assert_eq(DirAccess.rename_absolute(path, path + ".tmp"), OK)
	GameState.new_game()
	assert_true(SaveSystem.slot_info(SLOT)["exists"])
	assert_eq(SaveSystem.load_slot(SLOT), "", "đọc được từ file .tmp")
	assert_eq(GameState.inventory.count("brick"), 9)
	SaveSystem.delete_slot(SLOT)
	assert_false(FileAccess.file_exists(path + ".tmp"), "xoá ô lưu thì xoá cả file tạm")


func test_file_luu_bi_sua_tay_khong_lam_hong_game() -> void:
	var world := World.new()
	add_to_tree(world)
	world.build()
	assert_eq(GameState.accept_contract("hd01"), "")
	var data := GameState.to_dict()
	data["inventory"]["vang_thoi"] = 5
	var proj: Dictionary = data["projects"]["A1"]
	proj["furniture"] = [
		{"uid": 1, "id": "ghe_bay", "pos": [7.5, 0.33, 8.5], "yaw": 0.0},
		{"uid": 2, "id": "bed", "pos": [7.5, 0.33, 8.5], "yaw": 0.0},
		{"uid": 3, "id": "brick", "pos": [6.5, 0.33, 8.5], "yaw": 0.0},
	]
	proj["paint_color"][0] = ["son_la", "paint_blue"]
	proj["paint_progress"][0] = [1.0, 1.0]
	proj["required_furniture"]["ghe_vang"] = 3
	var broken: Dictionary = proj.duplicate(true)
	broken["blueprint"]["openings"] = [{"wall": 42, "type": "door", "offset": 1.0}]
	data["projects"]["A2"] = broken
	var huge: Dictionary = proj.duplicate(true)
	huge["blueprint"]["size"] = [40, 40]
	data["projects"]["A3"] = huge
	data["projects"]["KHONG_CO"] = proj.duplicate(true)
	assert_eq(GameState.from_dict(data), "")
	assert_eq(GameState.inventory.count("vang_thoi"), 0, "bỏ vật phẩm lạ trong kho")
	var p := GameState.project_at("A1")
	assert_eq(p.furniture.size(), 1, "chỉ giữ nội thất có trong danh mục")
	assert_eq(p.paint_color[0], ["", "paint_blue"], "bỏ màu sơn lạ")
	assert_eq(p.paint_progress[0][0], 0.0)
	assert_false(p.required_furniture.has("ghe_vang"))
	assert_eq(GameState.project_at("A2"), null, "bản vẽ hỏng thì bỏ công trình")
	assert_eq(GameState.project_at("A3"), null, "bản vẽ to hơn lô đất thì bỏ")
	assert_eq(GameState.projects.size(), 1, "lô đất không tồn tại thì bỏ")
	assert_not_null(world.house_view("A1"), "nhà hợp lệ vẫn hiện bình thường")
