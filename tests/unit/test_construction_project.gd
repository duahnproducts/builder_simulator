extends TestCase
## Luật thi công: điều kiện, vật tư, giai đoạn, lưu/tải.

const R = ConstructionProject.Result
const S = ConstructionProject.Status

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new()


## Tạo công trình; `stock` = nạp sẵn đúng lượng vật tư dự toán.
func _project(bp: Blueprint = null, stock := true) -> ConstructionProject:
	var p := ConstructionProject.new(bp if bp != null else Fixtures.rect_house(), inv, "A1")
	if stock:
		var need := p.remaining_materials()
		for item_id: String in need:
			inv.add(item_id, need[item_id])
	return p


func _foundation(p: ConstructionProject) -> void:
	for c in p.dig.cells:
		p.dig_cell(c)
	for c in p.pour.cells:
		p.pour_cell(c)


func _walls(p: ConstructionProject) -> void:
	for w in p.walls.size():
		while not p.is_wall_done(w):
			if p.lay_brick(w) != R.OK:
				return


## Làm hết mọi phần việc trừ nội thất. Trả về số thao tác KHÔNG ra kết quả OK.
func _build_all(p: ConstructionProject, paint := "paint_white") -> int:
	var fails := 0
	for c in p.dig.cells:
		fails += int(p.dig_cell(c) != R.OK)
	for c in p.pour.cells:
		fails += int(p.pour_cell(c) != R.OK)
	for w in p.walls.size():
		while not p.is_wall_done(w):
			if p.lay_brick(w) != R.OK:
				fails += 1
				break
	for k in p.openings_done.size():
		fails += int(p.install_opening(k) != R.OK)
	if p.roof != null:
		for g in p.roof.gables.size():
			while not p.is_gable_done(g):
				if p.lay_gable_brick(g) != R.OK:
					fails += 1
					break
		while p.roof_laid < p.roof.piece_count():
			if p.lay_roof_piece() != R.OK:
				fails += 1
				break
	else:
		for c in p.roof_cells.cells:
			fails += int(p.pour_roof_cell(c) != R.OK)
	for w in p.walls.size():
		for side in 2:
			while p.plaster[w][side] < 1.0:
				if p.apply_plaster(w, side, 5.0) != R.OK:
					fails += 1
					break
			while p.paint_progress[w][side] < 1.0:
				if p.apply_paint(w, side, paint, 5.0) != R.OK:
					fails += 1
					break
	for c in p.floor_tiles.cells:
		fails += int(p.tile_floor(c) != R.OK)
	return fails


func test_trang_thai_ban_dau() -> void:
	var p := _project()
	assert_eq(p.stage_status("excavation"), S.AVAILABLE)
	assert_eq(p.stage_status("foundation"), S.LOCKED)
	assert_eq(p.stage_status("furnish"), S.LOCKED)
	assert_false(p.is_complete())
	assert_eq(p.stage_order()[0], "excavation")
	assert_eq(p.stage_order()[-1], "furnish")
	assert_eq(p.stage_progress("furnish"), 0.0, "chưa được bày đồ thì thanh nội thất trống")


func test_do_mong_can_dao_truoc_va_can_xi_mang() -> void:
	var p := _project(null, false)
	var c := p.dig.cells[0]
	assert_eq(p.pour_cell(c), R.LOCKED, "chưa đào thì chưa đổ được")
	assert_eq(p.dig_cell(c), R.OK)
	assert_eq(p.dig_cell(c), R.DONE)
	assert_eq(p.pour_cell(c), R.NO_MATERIAL)
	inv.add("cement", 3)
	assert_eq(p.pour_cell(c), R.OK)
	assert_eq(inv.count("cement"), 1, "mỗi ô tốn 2 bao")
	assert_eq(p.pour_cell(Vector2i(0, 0)), R.INVALID, "ô ngoài nhà")


func test_xay_gach_can_do_xong_mong() -> void:
	var p := _project()
	assert_eq(p.lay_brick(0), R.LOCKED)
	_foundation(p)
	var before := inv.count("brick")
	assert_eq(p.lay_brick(0), R.OK)
	assert_eq(inv.count("brick"), before - 1)
	assert_eq(p.bricks[0], 1)
	assert_eq(p.lay_brick(99), R.INVALID)


func test_lap_cua_chi_can_tuong_chua_cua_xong() -> void:
	var p := _project()
	_foundation(p)
	var door_wall: int = p.blueprint.openings[0]["wall"]
	assert_eq(p.install_opening(0), R.LOCKED)
	while not p.is_wall_done(door_wall):
		p.lay_brick(door_wall)
	assert_false(p.are_walls_done())
	assert_eq(p.install_opening(0), R.OK)
	assert_eq(p.install_opening(0), R.DONE)


func test_lop_mai_ngoi_theo_thu_tu() -> void:
	var p := _project()
	_foundation(p)
	_walls(p)
	assert_eq(p.lay_roof_piece(), R.LOCKED, "chưa xây tường hồi")
	for g in p.roof.gables.size():
		while not p.is_gable_done(g):
			p.lay_gable_brick(g)
	assert_eq(p.next_roof_item(), "roof_truss")
	var trusses := inv.count("roof_truss")
	for i in p.roof.truss_count():
		assert_eq(p.lay_roof_piece(), R.OK)
	assert_eq(inv.count("roof_truss"), trusses - p.roof.truss_count())
	assert_eq(p.next_roof_item(), "roof_tile")


func test_trat_va_son() -> void:
	var p := _project()
	_foundation(p)
	_walls(p)
	var cement := inv.count("cement")
	var need := p.plaster_cement_needed(0)
	assert_eq(p.apply_paint(0, 0, "paint_white", 1.0), R.LOCKED, "chưa trát thì chưa sơn")
	assert_eq(p.apply_plaster(0, 0, 1.0), R.OK)
	assert_eq(inv.count("cement"), cement - need, "trừ xi măng khi bắt đầu trát")
	assert_eq(p.apply_plaster(0, 0, 1.0), R.OK)
	assert_eq(inv.count("cement"), cement - need, "trát tiếp không trừ thêm")
	while p.plaster[0][0] < 1.0:
		p.apply_plaster(0, 0, 5.0)
	assert_eq(p.apply_plaster(0, 0, 1.0), R.DONE)
	var cans := p.paint_cans_needed(0)
	var white := inv.count("paint_white")
	assert_eq(p.apply_paint(0, 0, "paint_white", 100.0), R.OK)
	assert_eq(inv.count("paint_white"), white - cans)
	assert_eq(p.apply_paint(0, 0, "paint_white", 1.0), R.DONE)
	inv.add("paint_blue", 10)
	assert_eq(p.apply_paint(0, 0, "paint_blue", 1.0), R.OK, "đổi màu thì sơn lại")
	assert_eq(p.paint_color[0][0], "paint_blue")
	assert_lt(p.paint_progress[0][0], 1.0)
	assert_eq(inv.count("paint_blue"), 10 - cans)


func test_noi_that_theo_hop_dong() -> void:
	var p := _project()
	p.required_furniture = {"bed": 1}
	inv.add("bed", 2)
	var inside := Vector3(3.5, BuildConst.FOUNDATION_TOP, 3.5)
	assert_eq(p.place_furniture("bed", inside, 0.0), R.LOCKED)
	assert_eq(_build_all(p), 0)
	assert_eq(p.stage_status("furnish"), S.AVAILABLE)
	assert_eq(p.place_furniture("bed", Vector3(0.5, 0.0, 0.5), 0.0), R.OK, "đặt ngoài nhà vẫn được")
	assert_eq(p.stage_status("furnish"), S.AVAILABLE, "nhưng không được tính")
	assert_eq(p.place_furniture("bed", inside, 0.0), R.OK)
	assert_eq(p.stage_status("furnish"), S.DONE)
	assert_true(p.is_complete())
	assert_eq(p.remove_furniture(p.last_furniture_uid), R.OK)
	assert_eq(inv.count("bed"), 1, "nhặt lên thì trả về kho")
	assert_false(p.is_complete())
	assert_eq(p.remove_furniture(9999), R.INVALID)


func test_du_toan_vat_tu_khop_tieu_thu_thuc_te() -> void:
	for bp: Blueprint in [Fixtures.rect_house(), Fixtures.two_room_house(), Fixtures.l_house()]:
		inv = Inventory.new()
		var p := ConstructionProject.new(bp, inv, "X")
		p.required_furniture = {"bed": 1, "table": 1}
		var need := p.remaining_materials()
		for item_id: String in need:
			inv.add(item_id, need[item_id])
		assert_eq(_build_all(p), 0, "mọi bước phải OK: " + bp.id)
		var cell := p.analysis.interior_cells[0]
		var pos := Vector3(cell.x + 0.5, BuildConst.FOUNDATION_TOP, cell.y + 0.5)
		assert_eq(p.place_furniture("bed", pos, 0.0), R.OK)
		assert_eq(p.place_furniture("table", pos, 0.0), R.OK)
		assert_true(p.is_complete(), bp.id)
		assert_eq(inv.item_ids().size(), 0, bp.id + " còn thừa " + str(inv.to_dict()))
		assert_eq(p.remaining_materials().size(), 0)


func test_mai_bang_nha_chu_L() -> void:
	var p := _project(Fixtures.l_house())
	assert_true(p.is_flat_roof())
	assert_eq(p.roof_cells.total(), 27)
	assert_eq(p.lay_roof_piece(), R.INVALID)
	assert_eq(p.pour_roof_cell(Vector2i(2, 2)), R.LOCKED)
	assert_eq(_build_all(p), 0)
	assert_eq(p.stage_status("roof"), S.DONE)


func test_bao_hoan_thanh_giai_doan() -> void:
	var p := _project()
	var done: Array[String] = []
	p.stage_completed.connect(func(stage: String) -> void: done.append(stage))
	for c in p.dig.cells:
		p.dig_cell(c)
	assert_eq(done, ["excavation"] as Array[String])
	_build_all(p)
	assert_true(done.has("furnish"), "không yêu cầu nội thất thì xong luôn")
	assert_eq(done.size(), ConstructionProject.STAGES.size())


func test_tien_do_giai_doan() -> void:
	var p := _project()
	assert_near(p.stage_progress("excavation"), 0.0)
	var half := floori(p.dig.cells.size() / 2.0)
	for i in half:
		p.dig_cell(p.dig.cells[i])
	assert_near(p.stage_progress("excavation"), float(half) / p.dig.total())
	assert_near(p.stage_progress("openings"), 0.0)


func test_luu_tai_qua_json_giu_nguyen() -> void:
	var p := _project()
	p.required_furniture = {"bed": 1}
	inv.add("bed", 1)
	inv.add("paint_blue", 50)
	_build_all(p, "paint_blue")
	p.place_furniture("bed", Vector3(3.5, 0.3, 3.5), 1.5)
	var text := JSON.stringify(p.to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	var before := inv.to_dict()
	var q := ConstructionProject.from_dict(parsed, inv)
	assert_eq(inv.to_dict(), before, "tải game không được trừ vật tư")
	assert_eq(JSON.stringify(q.to_dict()), text)
	assert_true(q.is_complete())


func test_tai_du_lieu_bi_sua_tay() -> void:
	var p := _project(null, false)
	var data := p.to_dict()
	data["bricks"] = [999999, -5, "abc", 3]
	data["plaster"] = [[5.0, -1.0], "x"]
	data["roof_laid"] = 1e12
	data["pour"] = [[3, 3]]
	data["furniture"] = [
		{"uid": 1, "id": "bed", "pos": [1, 2, 3], "yaw": 0},
		{"uid": 1, "id": "trung_uid", "pos": [1, 2, 3]},
		{"uid": 2, "id": "", "pos": [0, 0, 0]},
		"rác",
	]
	var q := ConstructionProject.from_dict(data, inv)
	assert_eq(q.bricks[0], q.walls[0].layout.slot_count())
	assert_eq(q.bricks[1], 0)
	assert_eq(q.bricks[2], 0)
	assert_eq(q.bricks[3], 3)
	assert_near(q.plaster[0][0], 1.0)
	assert_near(q.plaster[0][1], 0.0)
	assert_eq(q.roof_laid, q.roof.piece_count())
	assert_eq(q.furniture.size(), 1)
	assert_true(q.dig.is_done(Vector2i(3, 3)), "ô đã đổ thì coi như đã đào")
	q.inventory.add("bed", 1)
	q.required_furniture = {}
	assert_eq(q.place_furniture("bed", Vector3.ZERO, 0.0), R.LOCKED)


func test_khong_bat_buoc_noi_that_thi_xong_khi_duoc_bay_do() -> void:
	var p := _project()
	assert_eq(p.stage_progress("furnish"), 0.0, "đang khoá thì thanh tiến độ trống")
	assert_eq(_build_all(p), 0)
	assert_eq(p.stage_status("furnish"), S.DONE)
	assert_eq(p.stage_progress("furnish"), 1.0)
	assert_true(p.is_complete())
