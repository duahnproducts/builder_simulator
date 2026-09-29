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
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
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
