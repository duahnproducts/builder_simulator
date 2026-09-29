extends TestCase
## Bố cục gạch, mối nối góc, gộp va chạm, mái ngói.


func _has_rect(rects: Array[Rect2], expected: Rect2) -> bool:
	for r in rects:
		if (r.position - expected.position).length() < 0.001 and (r.size - expected.size).length() < 0.001:
			return true
	return false


func _slot_aabb(g: WallGeometry, i: int) -> AABB:
	return g.slot_transform(i) * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


# ─── RectMerge ───

func test_noi_doan_lien_nhau() -> void:
	var pieces: Array[Vector2] = [Vector2(0, 0.4), Vector2(0.4, 0.8), Vector2(1.0, 1.4), Vector2(1.4, 1.6)]
	var runs := RectMerge.join_runs(pieces)
	assert_eq(runs.size(), 2)
	assert_vec_near(runs[0], Vector2(0, 0.8))
	assert_vec_near(runs[1], Vector2(1.0, 1.6))


func test_gop_hang_thanh_hinh_chu_nhat() -> void:
	var rows := [
		{"v0": 0.0, "v1": 0.2, "runs": [Vector2(0, 4)]},
		{"v0": 0.2, "v1": 0.4, "runs": [Vector2(0, 4)]},
		{"v0": 0.4, "v1": 0.6, "runs": [Vector2(0, 1), Vector2(2, 4)]},
	]
	var rects := RectMerge.merge_rows(rows)
	assert_eq(rects.size(), 3)
	assert_true(_has_rect(rects, Rect2(0, 0, 4, 0.4)))
	assert_true(_has_rect(rects, Rect2(0, 0.4, 1, 0.2)))
	assert_true(_has_rect(rects, Rect2(2, 0.4, 2, 0.2)))


func test_o_luoi_thanh_hinh_chu_nhat() -> void:
	var cells: Array[Vector2i] = []
	for z in 3:
		for x in 4:
			cells.append(Vector2i(x, z))
	cells.append(Vector2i(0, 3))
	var rects := RectMerge.cells_to_rects(cells)
	assert_eq(rects.size(), 2)
	assert_true(_has_rect(rects, Rect2(0, 0, 4, 3)))
	assert_true(_has_rect(rects, Rect2(0, 3, 1, 1)))


# ─── WallLayout ───

func test_tuong_4m_cao_3m() -> void:
	var w := WallLayout.new(0.0, 4.0, 3.0)
	assert_eq(w.course_count(), 15)
	assert_eq(w.slot_count(), 8 * 10 + 7 * 11, "hàng chẵn 10 viên, hàng lẻ nửa + 9 + nửa")
	assert_near(w.face_area(), 12.0, 0.001)
	var rects := w.face_rects()
	assert_eq(rects.size(), 1)
	assert_rect_near(rects[0], Rect2(0, 0, 4, 3))


func test_xay_so_le() -> void:
	var w := WallLayout.new(0.0, 4.0, 3.0)
	assert_near(w.slots[0].size.x, 0.4, 0.0001, "hàng 0 bắt đầu bằng viên nguyên")
	var first_odd := w.slots[w.course_first[1]]
	assert_near(first_odd.size.x, 0.2, 0.0001, "hàng 1 bắt đầu bằng nửa viên")
	assert_near(first_odd.position.y, 0.2)


func test_thu_tu_xay_tu_duoi_len_trai_sang_phai() -> void:
	var w := WallLayout.new(0.0, 4.0, 3.0)
	var ordered := true
	for i in range(1, w.slot_count()):
		var a := w.slots[i - 1]
		var b := w.slots[i]
		var next_row := b.position.y > a.position.y + 0.001
		var same_row_right := is_equal_approx(b.position.y, a.position.y) and b.position.x > a.position.x
		ordered = ordered and (next_row or same_row_right)
	assert_true(ordered)


func test_khoet_lo_cua_di() -> void:
	var door := Rect2(1.4, 0.0, 1.0, 2.2)
	var ops: Array[Rect2] = [door]
	var w := WallLayout.new(0.0, 4.0, 3.0, ops)
	assert_near(w.face_area(), 12.0 - 2.2, 0.001)
	var rects := w.face_rects()
	assert_eq(rects.size(), 3, "trái cửa, phải cửa, trên cửa")
	assert_true(_has_rect(rects, Rect2(0, 0, 1.4, 2.2)))
	assert_true(_has_rect(rects, Rect2(2.4, 0, 1.6, 2.2)))
	assert_true(_has_rect(rects, Rect2(0, 2.2, 4, 0.8)))
	var overlapping := 0
	for s in w.slots:
		if s.grow(-0.001).intersects(door):
			overlapping += 1
	assert_eq(overlapping, 0, "không viên nào nằm trong lỗ cửa")


func test_va_cham_theo_so_vien_da_xay() -> void:
	var w := WallLayout.new(0.0, 4.0, 3.0)
	assert_eq(w.built_rects(0).size(), 0)
	var one_row := w.built_rects(10)
	assert_eq(one_row.size(), 1)
	assert_rect_near(one_row[0], Rect2(0, 0, 4, 0.2))
	assert_eq(w.built_rects(13).size(), 2, "hàng 0 trọn + 3 viên hàng 1")
	assert_eq(w.completed_courses(13), 1)


func test_tuong_hoi_tam_giac() -> void:
	var no_openings: Array[Rect2] = []
	var g := WallLayout.new(-0.1, 6.1, 0.0, no_openings, 1.79)
	assert_true(g.is_gable())
	assert_gt(g.slot_count(), 10)
	var inside := true
	for s in g.slots:
		var span := g.span_at(s.get_center().y)
		inside = inside and s.position.x >= span.x - 0.001 and s.end.x <= span.y + 0.001
	assert_true(inside, "mọi viên nằm trong tam giác")
	assert_near(g.face_area(), 6.2 * 1.79 / 2.0, 0.3, "diện tích xấp xỉ tam giác")


# ─── WallGeometry ───

func test_mo_rong_goc_nha_chu_nhat() -> void:
	var walls := WallGeometry.build_for_blueprint(Fixtures.rect_house(2, 2, 6, 4))
	for i in [0, 2]:
		assert_near(walls[i].ext_a, 0.1, 0.0001, "tường ngang %d sở hữu góc" % i)
		assert_near(walls[i].ext_b, 0.1)
	for i in [1, 3]:
		assert_near(walls[i].ext_a, -0.1, 0.0001, "tường dọc %d thu lại" % i)
		assert_near(walls[i].ext_b, -0.1)


func test_chu_T_thu_lai() -> void:
	var walls := WallGeometry.build_for_blueprint(Fixtures.two_room_house())
	assert_near(walls[4].ext_a, -0.1)
	assert_near(walls[4].ext_b, -0.1)
	assert_near(walls[0].ext_a, 0.1, 0.0001, "tường sau vẫn là góc L ở hai đầu")


func test_goc_khong_chong_khong_ho() -> void:
	var bp := Fixtures.rect_house(2, 2, 6, 4)
	bp.openings.clear()
	var walls := WallGeometry.build_for_blueprint(bp)
	var area := 0.0
	for g in walls:
		area += g.layout.face_area()
	# Chu vi đường tâm 20 m: tường ngang dài thêm 0,4 m, tường dọc ngắn đi 0,4 m → vẫn 20 m.
	assert_near(area, 20.0 * 3.0, 0.01)
	# Hai hàng đầu: không viên nào của tường này chồng lên viên của tường khác.
	var boxes: Array = []
	for w in walls.size():
		for i in walls[w].layout.course_first[2]:
			boxes.append([w, _slot_aabb(walls[w], i).grow(-0.001)])
	var overlaps := 0
	for a in boxes.size():
		for b in range(a + 1, boxes.size()):
			if boxes[a][0] != boxes[b][0] and (boxes[a][1] as AABB).intersects(boxes[b][1]):
				overlaps += 1
	assert_eq(overlaps, 0)
	var corner := Vector3(1.91, 0.4, 1.91)
	var covered := false
	for w in walls.size():
		for i in walls[w].layout.course_first[2]:
			covered = covered or _slot_aabb(walls[w], i).grow(0.001).has_point(corner)
	assert_true(covered, "góc ngoài được phủ kín")


func test_he_truc_thuan_khong_lat_mat() -> void:
	for g in WallGeometry.build_for_blueprint(Fixtures.rect_house()):
		assert_gt(g.slot_transform(0).basis.determinant(), 0.0)


func test_doi_toa_do_va_mat_tuong() -> void:
	var walls := WallGeometry.build_for_blueprint(Fixtures.rect_house(2, 2, 6, 4))
	var g := walls[1]
	assert_vec_near(g.to_uv(Vector3(8.0, 1.3, 3.5)), Vector2(1.5, 1.0))
	assert_eq(g.side_from_normal(Vector3.RIGHT), 1)
	assert_eq(g.side_from_normal(Vector3.LEFT), 0)


func test_mang_trat_phu_goc() -> void:
	var walls := WallGeometry.build_for_blueprint(Fixtures.rect_house(2, 2, 6, 4))
	var vertical := walls[1].plaster_rects()
	assert_eq(vertical.size(), 1)
	assert_rect_near(vertical[0], Rect2(0, 0, 4, 3), 0.0001, "đầu thu lại được nới 0,1 m")
	var horizontal := walls[0].plaster_rects()
	assert_rect_near(horizontal[0], Rect2(-0.1, 0, 6.2, 3))


# ─── RoofLayout ───

func _roof(w := 6, d := 4) -> RoofLayout:
	return RoofLayout.new(Rect2i(2, 2, w, d), 3.3)


func test_noc_chay_theo_canh_dai() -> void:
	assert_true(_roof(6, 4).ridge_along_x)
	assert_false(_roof(4, 6).ridge_along_x)


func test_kich_thuoc_mai() -> void:
	var r := _roof(6, 4)
	assert_rect_near(r.outer, Rect2(1.9, 1.9, 6.2, 4.2))
	assert_near(r.rise, 2.1 * tan(deg_to_rad(30.0)))
	assert_near(r.row_len * r.rows, r.slope_len)
	assert_lt(r.row_len, 0.4001)
	assert_near(r.seg_len * r.segs, 6.2 + 0.8)
	assert_eq(r.piece_count(), r.truss_count() + 2 * r.rows * r.segs + r.segs)
	assert_gt(r.truss_count(), 3)


func test_thu_tu_lop_mai() -> void:
	var r := _roof()
	assert_eq(r.piece_kind(0), RoofLayout.Piece.TRUSS)
	assert_eq(r.piece_kind(r.truss_count()), RoofLayout.Piece.TILE)
	assert_eq(r.piece_kind(r.piece_count() - 1), RoofLayout.Piece.RIDGE)
	assert_eq(r.tile_coords(0), Vector3i(0, 0, 0))
	assert_eq(r.tile_coords(r.segs), Vector3i(1, 0, 0), "cùng hàng, lợp sang bên kia")
	assert_eq(r.tile_coords(2 * r.segs), Vector3i(0, 1, 0), "lên hàng kế tiếp")


func test_ngoi_nam_dung_mat_mai() -> void:
	for r: RoofLayout in [_roof(6, 4), _roof(4, 7)]:
		for k in [0, r.segs, r.tile_count() - 1]:
			var t := r.tile_transform(k)
			assert_gt(t.basis.determinant(), 0.0)
			var c := r.tile_coords(k)
			var on_plane := t.origin - r.roof_normal(c.x) * (BuildConst.ROOF_TILE_THICKNESS / 2.0)
			var s := on_plane.z if r.ridge_along_x else on_plane.x
			var d := s - r.s_start if c.x == 0 else r.s_start + r.s_len - s
			assert_near(on_plane.y, r.roof_height_at(d), 0.001)


func test_gach_tuong_hoi_nam_duoi_mat_mai() -> void:
	var r := _roof(6, 4)
	assert_eq(r.gables.size(), 2)
	var below := true
	for g in r.gables:
		assert_near(g.layout.gable_peak, r.rise)
		for slot in g.layout.slots:
			for u: float in [slot.position.x, slot.end.x]:
				var p := g.origin + g.dir * u + Vector3.UP * slot.end.y
				var d := minf(p.z - r.s_start, r.s_start + r.s_len - p.z)
				below = below and p.y < r.roof_height_at(d) + 0.0001
	assert_true(below, "không viên gạch nào lòi lên mặt mái")


# ─── StageGraph và CellProgress ───

func test_thu_tu_topo_ton_trong_phu_thuoc() -> void:
	var g := StageGraph.new()
	for s: Dictionary in ConstructionProject.STAGES:
		g.add_stage(s["id"], s["requires"])
	var order := g.topological_order()
	assert_eq(order.size(), ConstructionProject.STAGES.size())
	for s: Dictionary in ConstructionProject.STAGES:
		for req: String in s["requires"]:
			assert_lt(order.find(req), order.find(s["id"]), "%s phải trước %s" % [req, s["id"]])
	assert_eq(order, ["excavation", "foundation", "walls", "openings", "roof", "plaster", "paint", "floor",
			"furnish"], "trong các giai đoạn sẵn sàng, cái khai báo trước đứng trước")


func test_thu_tu_topo_uu_tien_thu_tu_khai_bao() -> void:
	var g := StageGraph.new()
	g.add_stage("goc", [])
	g.add_stage("a", ["goc"])
	g.add_stage("b", ["goc"])
	g.add_stage("a2", ["a"])
	g.add_stage("c", [])
	# Hàng đợi FIFO sẽ cho: goc, c, a, b, a2 ("c" chen lên vì sẵn sàng từ đầu).
	# Ưu tiên thứ tự khai báo: luôn lấy đỉnh sẵn sàng có chỉ số khai báo nhỏ nhất.
	assert_eq(g.topological_order(), ["goc", "a", "b", "a2", "c"])


func test_phat_hien_chu_trinh() -> void:
	var g := StageGraph.new()
	g.add_stage("a", ["c"])
	g.add_stage("b", ["a"])
	g.add_stage("c", ["b"])
	assert_true(g.has_cycle())
	var g2 := StageGraph.new()
	g2.add_stage("a", ["khong_ton_tai"])
	assert_eq(g2.topological_order().size(), 0)


func test_tien_do_theo_o() -> void:
	var cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1)]
	var p := CellProgress.new(cells)
	assert_true(p.mark(Vector2i(0, 1)))
	assert_false(p.mark(Vector2i(0, 1)), "không đánh dấu hai lần")
	assert_false(p.mark(Vector2i(5, 5)), "ô ngoài tập")
	assert_true(p.mark(Vector2i(1, 0)))
	assert_eq(p.order, [Vector2i(0, 1), Vector2i(1, 0)] as Array[Vector2i])
	assert_near(p.progress(), 2.0 / 3.0)
	assert_eq(p.first_remaining(), Vector2i(0, 0))
	var q := CellProgress.new(cells)
	q.load_array(p.to_array())
	assert_eq(q.order, p.order)
	q.load_array([[0, 1], "rác", [9, 9], [0, 1], [1]])
	assert_eq(q.order, [Vector2i(0, 1)] as Array[Vector2i])
