extends TestCase
## Bản vẽ: dữ liệu, phân tích BFS, kiểm tra hợp lệ.


func _errors(bp: Blueprint) -> String:
	return " | ".join(BlueprintValidator.validate(bp))


# ─── Blueprint ───

func test_them_tuong_chuan_hoa_hai_dau() -> void:
	var bp := Blueprint.new()
	var i := bp.add_wall(Vector2i(5, 3), Vector2i(1, 3))
	assert_eq(bp.wall_a[i], Vector2i(1, 3))
	assert_eq(bp.wall_b[i], Vector2i(5, 3))
	assert_true(bp.is_horizontal(i))
	assert_near(bp.wall_length(i), 4.0)


func test_xoa_tuong_doi_chi_so_cua() -> void:
	var bp := Fixtures.rect_house()
	bp.remove_wall(2)
	assert_eq(bp.openings.size(), 1, "cửa trên tường bị xoá cũng mất")
	assert_eq(int(bp.openings[0]["wall"]), 2, "tường 3 lùi thành tường 2")


func test_luu_va_doc_giu_nguyen() -> void:
	var bp := Fixtures.two_room_house()
	assert_eq(Blueprint.from_dict(bp.to_dict()).to_dict(), bp.to_dict())
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(bp.to_dict()))
	assert_eq(Blueprint.from_dict(through_json).to_dict(), bp.to_dict(), "qua JSON (số thành float) vẫn giữ nguyên")


func test_doc_du_lieu_rac_khong_crash() -> void:
	var bp := Blueprint.from_dict({
		"size": "abc", "roof": 42, "wall_height": null,
		"walls": [[1, 2], "x", [0, 0, 3, 0], [null, 1, 2, 1]],
		"openings": [5, {"wall": "a"}],
	})
	assert_eq(bp.size, Vector2i(12, 12))
	assert_eq(bp.wall_count(), 2)
	assert_eq(bp.openings.size(), 0)
	assert_eq(bp.roof, "gable")
	assert_near(bp.wall_height, 3.0)


func test_hinh_chu_nhat_cua() -> void:
	var bp := Fixtures.rect_house()
	assert_rect_near(bp.opening_rect(0), Rect2(2.4, 0.0, 1.0, 2.2))
	assert_rect_near(bp.opening_rect(1), Rect2(1.4, 0.8, 1.2, 1.2))


# ─── BlueprintAnalysis ───

func test_nha_chu_nhat_mot_phong() -> void:
	var an := BlueprintAnalysis.new(Fixtures.rect_house(2, 2, 6, 4))
	assert_eq(an.interior_cells.size(), 24)
	assert_eq(an.rooms.size(), 1)
	assert_eq(an.bounds, Rect2i(2, 2, 6, 4))
	assert_true(an.is_rectangular())
	assert_true(an.is_interior(Vector2i(2, 2)))
	assert_false(an.is_interior(Vector2i(1, 2)))
	assert_false(an.is_interior(Vector2i(8, 2)))


func test_tuong_ngan_chia_hai_phong() -> void:
	var an := BlueprintAnalysis.new(Fixtures.two_room_house())
	assert_eq(an.rooms.size(), 2)
	assert_eq(an.interior_cells.size(), 40)
	assert_ne(an.room_of(Vector2i(5, 3)), an.room_of(Vector2i(6, 3)))


func test_nha_chu_L() -> void:
	var an := BlueprintAnalysis.new(Fixtures.l_house())
	assert_eq(an.interior_cells.size(), 27)
	assert_false(an.is_rectangular())
	assert_false(an.is_interior(Vector2i(6, 3)), "góc khuyết không phải trong nhà")


func test_tuong_ho_thi_khong_co_phong() -> void:
	var bp := Fixtures.rect_house()
	bp.remove_wall(1)
	assert_eq(BlueprintAnalysis.new(bp).interior_cells.size(), 0)


func test_mat_tuong_trong_va_ngoai() -> void:
	var an := BlueprintAnalysis.new(Fixtures.two_room_house())
	assert_false(an.side_is_interior(0, 0), "tường sau: mặt 0 nhìn ra ngoài")
	assert_true(an.side_is_interior(0, 1))
	assert_true(an.is_exterior_wall(0))
	assert_false(an.is_exterior_wall(4), "tường ngăn: cả hai mặt đều trong nhà")


func test_tam_san_noi_ra_duoi_chan_tuong() -> void:
	var an := BlueprintAnalysis.new(Fixtures.rect_house(2, 2, 6, 4))
	assert_rect_near(an.slab_rect(Vector2i(2, 2)), Rect2(1.9, 1.9, 1.1, 1.1))
	assert_rect_near(an.slab_rect(Vector2i(4, 3)), Rect2(4, 3, 1, 1))
	assert_rect_near(an.slab_rect(Vector2i(7, 5)), Rect2(7, 5, 1.1, 1.1))


func test_phong_khong_co_loi_vao() -> void:
	var bp := Fixtures.two_room_house()
	assert_eq(BlueprintAnalysis.new(bp).rooms_without_access().size(), 0)
	bp.remove_opening(2)
	assert_eq(BlueprintAnalysis.new(bp).rooms_without_access().size(), 1)


func test_o_chua_diem() -> void:
	assert_eq(BlueprintAnalysis.cell_at(Vector3(3.7, 1.0, 2.1)), Vector2i(3, 2))
	assert_eq(BlueprintAnalysis.cell_at(Vector3(-0.2, 0.0, 0.0)), Vector2i(-1, 0))


# ─── BlueprintValidator ───

func test_ban_ve_mau_hop_le() -> void:
	for bp: Blueprint in [Fixtures.rect_house(), Fixtures.two_room_house(), Fixtures.l_house()]:
		assert_eq(BlueprintValidator.validate(bp).size(), 0, bp.id + ": " + _errors(bp))


func test_loi_khong_co_tuong() -> void:
	assert_true(_errors(Blueprint.new()).contains("Chưa có bức tường"))


func test_loi_tuong_cheo_va_ngoai_lo() -> void:
	var bp := Blueprint.new()
	bp.size = Vector2i(10, 10)
	bp.add_wall(Vector2i(0, 0), Vector2i(3, 3))
	bp.add_wall(Vector2i(0, 0), Vector2i(0, 12))
	var text := _errors(bp)
	assert_true(text.contains("ngang hoặc dọc"), text)
	assert_true(text.contains("ngoài lô đất"), text)


func test_loi_tuong_chong_va_cat_nhau() -> void:
	var bp := Fixtures.rect_house()
	bp.add_wall(Vector2i(3, 2), Vector2i(5, 2))
	assert_true(_errors(bp).contains("chồng lên"))
	var bp2 := Fixtures.rect_house(2, 2, 6, 4)
	bp2.add_wall(Vector2i(5, 1), Vector2i(5, 7))
	assert_true(_errors(bp2).contains("cắt ngang"))


func test_loi_tuong_ho_va_tuong_thua() -> void:
	var bp := Fixtures.rect_house()
	bp.remove_wall(1)
	assert_true(_errors(bp).contains("chưa khép kín"))
	var bp2 := Fixtures.rect_house(2, 2, 6, 4)
	bp2.add_wall(Vector2i(0, 0), Vector2i(1, 0))
	assert_true(_errors(bp2).contains("không bao quanh phòng nào"))


func test_loi_cua_vuot_tuong_va_chong_nhau() -> void:
	var bp := Fixtures.rect_house()
	bp.add_opening(2, "window", 5.0)
	assert_true(_errors(bp).contains("vượt ra ngoài"))
	var bp2 := Fixtures.rect_house()
	bp2.add_opening(2, "window", 3.0)
	assert_true(_errors(bp2).contains("chồng lên cửa"))


func test_loi_cua_trung_cho_noi_tuong() -> void:
	var bp := Fixtures.two_room_house()
	bp.add_opening(0, "window", 3.6)
	assert_true(_errors(bp).contains("chỗ tường khác nối vào"))


func test_loi_phong_khong_co_cua() -> void:
	var bp := Fixtures.two_room_house()
	bp.remove_opening(2)
	assert_true(_errors(bp).contains("không có cửa đi vào"))


func test_loi_mai_ngoi_cho_nha_chu_L() -> void:
	var bp := Fixtures.l_house()
	bp.roof = "gable"
	assert_true(_errors(bp).contains("Mái ngói chỉ làm được"))


func test_loi_cua_sai_loai_hoac_sai_tuong() -> void:
	var bp := Fixtures.rect_house()
	bp.add_opening(99, "door", 1.0)
	bp.add_opening(0, "garage", 1.0)
	var text := _errors(bp)
	assert_true(text.contains("không tồn tại"), text)
	assert_true(text.contains("loại không hợp lệ"), text)
