extends TestCase
## Thế giới mở: sinh tất định, không cây nào trên lô đất/đường, công trình gắn đúng lô.


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	GameState.new_game()


func _world() -> World:
	var w := World.new()
	add_to_tree(w)
	w.build()
	w.day_night.running = false
	return w


func test_dung_du_thanh_phan() -> void:
	var w := _world()
	assert_eq(w.plots.size(), Catalog.plots().size())
	for kind in ["shop", "job_board", "drawing_table"]:
		assert_true(w.interactables.has(kind), "thiếu " + kind)
		assert_eq(w.interactables[kind].get_meta("kind"), kind)
	assert_gt(w.tree_positions.size(), 60)
	assert_gt(w.decor_lots.size(), 10)


func test_sinh_tat_dinh() -> void:
	var a := _world()
	var b := _world()
	assert_eq(a.tree_positions, b.tree_positions, "cùng seed thì cây mọc đúng chỗ cũ")


func test_khong_cay_tren_lo_dat_hay_duong() -> void:
	var w := _world()
	var bad := 0
	for p in w.tree_positions:
		if absf(p.z) < World.ROAD_HALF + World.SIDEWALK or not w.plot_at(p).is_empty():
			bad += 1
		if World.PLAZA_RECT.has_point(Vector2(p.x, p.z)):
			bad += 1
		for lot in w.decor_lots:
			if lot.has_point(Vector2(p.x, p.z)):
				bad += 1
	assert_eq(bad, 0)


func test_vi_tri_xuat_hien_tren_mat_dat() -> void:
	var w := _world()
	await wait_physics_frames(2)
	var from := w.spawn_point() + Vector3(0, 5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -10, 0), Colliders.WORLD)
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	assert_false(hit.is_empty(), "phải có mặt đất dưới chân")
	assert_near(hit.get("position", Vector3.ONE).y, 0.0, 0.01)
	assert_eq(w.plot_at(w.spawn_point()), "")


func test_cong_trinh_gan_dung_lo_dat() -> void:
	var w := _world()
	assert_eq(GameState.accept_contract("hd01"), "")
	var view := w.house_view("A1")
	assert_not_null(view, "nhận hợp đồng thì hiện công trình trên lô A1")
	var node := w.plot_node("A1")
	assert_vec_near(view.global_position, node.global_position)
	var center := node.to_global(Vector3(7, 0, 7))
	assert_eq(w.plot_at(center), "A1")
	assert_true(node.label_text().contains("Đang thi công"), node.label_text())
	GameState.abandon_contract("hd01")
	assert_eq(w.house_view("A1"), null)
	assert_true(node.label_text().contains("Có hợp đồng"), node.label_text())


func test_lo_nha_minh_xoay_ra_duong() -> void:
	var w := _world()
	var home := w.plot_node(GameState.HOME_PLOT)
	var front := home.to_global(Vector3(7, 0, 14))
	var back := home.to_global(Vector3(7, 0, 0))
	assert_lt(absf(front.z), absf(back.z), "mặt trước lô gần đường hơn mặt sau")


func test_ngay_dem() -> void:
	var w := _world()
	w.day_night.apply(12.0)
	var noon := w.sun.light_energy
	w.day_night.apply(0.0)
	assert_gt(noon, w.sun.light_energy, "trưa sáng hơn nửa đêm")
	assert_near(DayNight.daylight(0.0), 0.0)
	assert_near(DayNight.daylight(12.0), 1.0)
	assert_gt(w.day_night.lamp_material.emission_energy_multiplier, 0.0, "đêm thì đèn đường sáng")
	w.day_night.apply(12.0)
	assert_near(w.day_night.lamp_material.emission_energy_multiplier, 0.0)


func test_scene_chinh_chay_duoc() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_tree(main)
	await wait_frames(3)
	assert_eq(runner.get_tree().get_nodes_in_group("player").size(), 1)
	assert_not_null(main.get_node_or_null("BuildController"))
	assert_not_null(main.get_node_or_null("World"))
