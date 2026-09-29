extends TestCase
## HouseView đồng bộ với ConstructionProject, và raycast nhận đúng mục tiêu.

const R = ConstructionProject.Result

var inv: Inventory
var project: ConstructionProject
var view: HouseView


func before_each() -> void:
	inv = Inventory.new()


func _setup(bp: Blueprint = null, xform := Transform3D.IDENTITY) -> void:
	project = ConstructionProject.new(bp if bp != null else Fixtures.rect_house(), inv, "T")
	var need := project.remaining_materials()
	for id: String in need:
		inv.add(id, need[id])
	view = HouseView.new()
	view.transform = xform
	add_to_tree(view)
	view.setup(project)


func _foundation() -> void:
	for c in project.dig.cells:
		project.dig_cell(c)
	for c in project.pour.cells:
		project.pour_cell(c)


func _walls() -> void:
	for w in project.walls.size():
		while not project.is_wall_done(w):
			project.lay_brick(w)


func _ray(from_local: Vector3, to_local: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(view.to_global(from_local), view.to_global(to_local), mask)
	var hit := view.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	return view.describe_hit(hit["collider"], hit["position"], hit["normal"])


func test_khoi_tao_day_du_thanh_phan() -> void:
	_setup()
	assert_eq(view.roof_view().roof.gables.size(), 2)
	assert_not_null(view.gable_view(1))
	assert_not_null(view.opening_view(1))
	assert_gt(Colliders.shape_count(view.foundation_target()), 0)
	assert_eq(view.foundation_target().collision_layer, Colliders.BLUEPRINT)
	assert_eq(view.wall_view(0).visible_bricks(), 0)
	assert_false(view.wall_view(0).ghost_visible(), "chưa đổ móng thì chưa hiện viên gạch mờ")


func test_dao_va_do_mong() -> void:
	_setup()
	for i in 5:
		project.dig_cell(project.dig.cells[i])
	assert_eq(view.cells_view("dig").visible_count(), 5)
	_foundation()
	assert_eq(view.cells_view("pour").visible_count(), project.pour.total())
	assert_eq(view.foundation_target().collision_layer, 0, "đổ xong thì tắt vùng nhắm móng")
	assert_eq(Colliders.shape_count(view.slab_body()), project.pour.total())
	assert_true(view.wall_view(0).ghost_visible(), "đổ xong móng thì hiện viên gạch mờ")


func test_xay_tuong_va_mo_khoa_lap_cua() -> void:
	_setup()
	_foundation()
	for i in 25:
		project.lay_brick(3)
	assert_eq(view.wall_view(3).visible_bricks(), 25)
	assert_gt(Colliders.shape_count(view.wall_view(3).solid_body()), 0)
	assert_false(view.opening_view(1).hologram_visible(), "tường chưa xong thì chưa hiện chỗ lắp cửa")
	while not project.is_wall_done(3):
		project.lay_brick(3)
	assert_eq(view.wall_view(3).target_body().collision_layer, 0)
	assert_false(view.wall_view(3).ghost_visible())
	assert_true(view.opening_view(1).hologram_visible(), "cửa sổ trên tường 3 chờ lắp")
	assert_eq(project.install_opening(1), R.OK)
	assert_false(view.opening_view(1).hologram_visible())


func test_mai_ngoi_hien_theo_thu_tu() -> void:
	_setup()
	_foundation()
	_walls()
	assert_true(view.gable_view(0).ghost_visible(), "xây xong tường thì tới tường hồi")
	for g in project.roof.gables.size():
		while not project.is_gable_done(g):
			project.lay_gable_brick(g)
	assert_true(view.roof_view().ghost_visible())
	var trusses := project.roof.truss_count()
	for i in trusses + 3:
		project.lay_roof_piece()
	assert_eq(view.roof_view().visible_counts(), Vector3i(trusses, 3, 0))


func test_trat_son_tao_mesh_hoan_thien() -> void:
	_setup()
	_foundation()
	_walls()
	assert_eq(view.wall_view(0).finish_mesh(1), null)
	project.apply_plaster(0, 1, 3.0)
	assert_not_null(view.wall_view(0).finish_mesh(1))


func test_dat_va_nhac_noi_that() -> void:
	_setup()
	project.required_furniture = {}
	inv.add("bed", 1)
	# Đặt thẳng vào dữ liệu để test hiển thị (điều kiện giai đoạn đã có unit test riêng).
	project.furniture.append({"uid": 7, "id": "bed", "pos": Vector3(4.5, 0.3, 3.5), "yaw": PI / 2})
	project.changed.emit("furniture", 7)
	var fv := view.furniture_view(7)
	assert_not_null(fv)
	assert_vec_near(fv.position, Vector3(4.5, 0.3, 3.5))
	assert_eq(fv.get_meta("kind"), "furniture")
	project.furniture.clear()
	project.changed.emit("furniture", 7)
	assert_eq(view.furniture_view(7), null)


func test_cua_di_mo_dong() -> void:
	_setup()
	_foundation()
	_walls()
	assert_eq(project.install_opening(0), R.OK)
	var door := view.opening_view(0)
	assert_false(door.is_open)
	door.set_open(true)
	assert_true(door.is_open)
	door.toggle_door()
	assert_false(door.is_open)


func test_raycast_nhan_dung_muc_tieu_khi_nha_bi_xoay() -> void:
	_setup(null, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(100, 0, 50)))
	await wait_physics_frames(2)
	var hit := _ray(Vector3(5, 1.5, -5), Vector3(5, 1.5, 3), Colliders.BLUEPRINT)
	assert_eq(hit.get("kind"), "wall")
	assert_eq(hit.get("index"), 0)
	var down := _ray(Vector3(4.5, 2.0, 3.5), Vector3(4.5, -1.0, 3.5), Colliders.BLUEPRINT)
	assert_eq(down.get("kind"), "foundation")
	assert_eq(down.get("cell"), Vector2i(4, 3))
	_foundation()
	_walls()
	await wait_physics_frames(2)
	var built := _ray(Vector3(5, 1.5, -5), Vector3(5, 1.5, 3), Colliders.WORLD)
	assert_eq(built.get("kind"), "wall_built")
	assert_eq(built.get("side"), 0, "nhìn từ ngoài vào: mặt 0 của tường sau")
	var slab := _ray(Vector3(4.5, 2.0, 3.5), Vector3(4.5, -1.0, 3.5), Colliders.WORLD)
	assert_eq(slab.get("kind"), "slab")
	assert_eq(slab.get("cell"), Vector2i(4, 3))


func test_mai_bang_co_vung_nham() -> void:
	_setup(Fixtures.l_house())
	assert_eq(view.roof_view(), null)
	assert_not_null(view.roof_slab_target())
	_foundation()
	_walls()
	for c in project.roof_cells.cells:
		project.pour_roof_cell(c)
	assert_eq(view.cells_view("roof").visible_count(), project.roof_cells.total())
	assert_eq(view.roof_slab_target().collision_layer, 0)


func test_nen_mong_khong_bien_mat_khi_giai_doan_hoan_thanh() -> void:
	_setup()
	_foundation()
	var body := view.slab_body()
	assert_eq(body.get_child_count(), project.pour.total(), "mỗi ô móng một hộp va chạm")
	var first := body.get_child(0)
	_walls()  # xây xong tường → refresh_all()
	view.refresh_all()
	assert_eq(body.get_child_count(), project.pour.total())
	assert_true(body.get_child(0) == first,
			"không dựng lại hộp va chạm của nền (hộp mới chỉ có hiệu lực từ frame vật lý sau)")
	await wait_physics_frames(1)
	var hit := _ray(Vector3(5.5, 2.0, 4.5), Vector3(5.5, -1.0, 4.5), Colliders.WORLD)
	assert_eq(hit.get("kind"), "slab")


func test_va_cham_khong_phai_cua_nha_thi_bo_qua() -> void:
	_setup()
	var other := Colliders.make_body(Colliders.WORLD, {}, "Other")
	add_to_tree(other)
	assert_eq(view.describe_hit(other, Vector3.ZERO, Vector3.UP), {}, "vật không có metadata")
	var foreign := Colliders.make_body(Colliders.WORLD, {"kind": "wall", "house": Node.new()}, "Foreign")
	add_to_tree(foreign)
	assert_eq(view.describe_hit(foreign, Vector3.ZERO, Vector3.UP), {}, "va chạm của nhà khác")
	(foreign.get_meta("house") as Node).free()
