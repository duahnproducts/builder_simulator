extends TestCase
## Tiền (Money, Wallet) và kho (Inventory).


func test_format_nhom_hang_nghin() -> void:
	assert_eq(Money.format(0), "0 ₫")
	assert_eq(Money.format(999), "999 ₫")
	assert_eq(Money.format(1000), "1.000 ₫")
	assert_eq(Money.format(1234567), "1.234.567 ₫")
	assert_eq(Money.format(-5000), "-5.000 ₫")


func test_format_rut_gon() -> void:
	assert_eq(Money.format_short(150_000_000), "150 triệu ₫")
	assert_eq(Money.format_short(1_500_000), "1,5 triệu ₫")
	assert_eq(Money.format_short(2_000_000_000), "2 tỷ ₫")
	assert_eq(Money.format_short(1_260_000_000), "1,3 tỷ ₫")
	assert_eq(Money.format_short(999_999), "999.999 ₫")
	assert_eq(Money.format_short(-3_000_000), "-3 triệu ₫")


func test_kho_them_va_lay_ra() -> void:
	var inv := Inventory.new()
	inv.add("brick", 10)
	assert_eq(inv.count("brick"), 10)
	assert_true(inv.remove("brick", 4))
	assert_eq(inv.count("brick"), 6)
	assert_false(inv.remove("brick", 7), "không đủ thì không lấy")
	assert_eq(inv.count("brick"), 6, "lấy thất bại thì không bị trừ")
	assert_true(inv.remove("brick", 6))
	assert_false(inv.has("brick"))
	assert_eq(inv.item_ids().size(), 0, "hết hàng thì xoá khỏi kho")


func test_kho_bo_qua_so_luong_sai() -> void:
	var inv := Inventory.new()
	inv.add("brick", -5)
	inv.add("", 3)
	assert_eq(inv.item_ids().size(), 0)


func test_kho_tinh_phan_con_thieu() -> void:
	var inv := Inventory.new()
	inv.add("brick", 10)
	assert_eq(inv.missing_for({"brick": 15, "cement": 2, "sand": 0}), {"brick": 5, "cement": 2})


func test_kho_nap_du_lieu_rac() -> void:
	var inv := Inventory.new()
	inv.load_dict({"brick": 5.0, "cement": -3, "paint": "abc", "tile": "7", "x": null})
	assert_eq(inv.count("brick"), 5)
	assert_eq(inv.count("cement"), 0)
	assert_eq(inv.count("paint"), 0)
	assert_eq(inv.count("tile"), 7)
	assert_eq(inv.item_ids().size(), 2)


func test_kho_phat_signal() -> void:
	var inv := Inventory.new()
	var events: Array = []
	inv.changed.connect(func(item_id: String, n: int) -> void: events.append([item_id, n]))
	inv.add("brick", 2)
	inv.remove("brick", 1)
	assert_eq(events, [["brick", 2], ["brick", 1]])


func test_vi_tien() -> void:
	var w := Wallet.new()
	w.balance = 1000
	assert_true(w.spend(400))
	assert_eq(w.balance, 600)
	assert_false(w.spend(601))
	assert_eq(w.balance, 600)
	assert_false(w.spend(-10), "không cho tiêu số âm")
	w.earn(-50)
	assert_eq(w.balance, 600)
	w.earn(50)
	assert_eq(w.balance, 650)
