extends TestCase
## Dữ liệu trong data/*.json phải nhất quán và đọc đúng.


func test_du_lieu_nhat_quan() -> void:
	var errors := Catalog.validate_data()
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_doc_du_lieu() -> void:
	assert_true(Catalog.has_item("brick"))
	assert_eq(Catalog.price("brick"), 6000)
	assert_eq(Catalog.item_name("cement"), "Xi măng")
	assert_gt(Catalog.paint_ids().size(), 5)
	assert_gt(Catalog.furniture_ids().size(), 10)
	assert_true(Catalog.is_furniture("bed"))
	assert_false(Catalog.is_furniture("brick"))
	assert_true(Catalog.is_paint("paint_blue"))
	assert_eq(Catalog.blueprint_ids().size(), 5)
	assert_eq(Catalog.contracts().size(), 5)
	assert_not_null(Catalog.blueprint("nha_cap4_nho"))
	assert_eq(Catalog.blueprint("khong_co"), null)
	assert_vec_near(Catalog.furniture_size("bed"), Vector3(1.6, 0.95, 2.1))


func test_ban_sao_ban_ve_doc_lap() -> void:
	var a := Catalog.blueprint("nha_cap4_nho")
	a.remove_wall(0)
	assert_eq(Catalog.blueprint("nha_cap4_nho").wall_count(), 4, "sửa bản sao không ảnh hưởng dữ liệu gốc")


func test_tien_cong_co_lai() -> void:
	for c in Catalog.contracts():
		var id := str(c["id"])
		var cost := Catalog.contract_cost(id)
		var reward := Catalog.contract_reward(id)
		assert_gt(cost, 0, id)
		assert_gt(reward, cost, id + ": tiền công phải lớn hơn chi phí vật tư")
		assert_eq(reward % 100_000, 0, id + ": làm tròn 100.000 đ")


func test_tien_khoi_dau_du_lam_hop_dong_dau() -> void:
	var first := str(Catalog.contracts()[0]["id"])
	assert_gt(Catalog.start_money, Catalog.contract_cost(first))


func test_bien_doi_lo_dat() -> void:
	var t := Catalog.plot_transform(Catalog.plot("HOME"))
	assert_vec_near(t * Vector3.ZERO, Vector3(7, 0, 20), 0.001)
	assert_vec_near(t * Vector3(0, 0, 14), Vector3(7, 0, 6), 0.001, "mặt trước lô đất hướng ra đường")
	assert_eq(Catalog.plot_size(Catalog.plot("A1")), Vector2i(14, 14))
