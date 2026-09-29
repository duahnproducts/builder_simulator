extends Node3D
## Chụp ảnh thế giới mở để kiểm tra bằng mắt.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . res://tools/capture/capture_world.tscn

const OUT_DIR := "res://test_output"

var _camera := Camera3D.new()
var _world: World


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	GameState.new_game()
	_world = World.new()
	add_child(_world)
	_world.build()
	_world.day_night.running = false
	add_child(_camera)
	_camera.current = true
	_camera.far = 400.0
	GameState.accept_contract("hd01")
	var p := GameState.project_at("A1")
	GameState.wallet.balance = 1_000_000_000
	GameState.buy_many(GameState.missing_for_project("A1"))
	for c in p.dig.cells:
		p.dig_cell(c)
	for c in p.pour.cells:
		p.pour_cell(c)
	for w in p.walls.size():
		for i in int(p.walls[w].layout.slot_count() * 0.6):
			p.lay_brick(w)
	await _shot("10_toan_canh", 10.0, Vector3(-30, 45, 55), Vector3(-10, 0, -5))
	await _shot("11_diem_xuat_hien", 10.0, Vector3(0, 1.7, 3.0), Vector3(-2, 1.4, -10))
	await _shot("12_lo_A1_dang_xay", 15.0, Vector3(-58, 6, 2), Vector3(-63, 1, -13))
	await _shot("13_dat_nha_ban", 16.5, Vector3(10, 4, -2), Vector3(2, 0.5, 12))
	await _shot("14_ban_dem", 21.0, Vector3(0, 1.7, 3.0), Vector3(-2, 1.4, -10))
	get_tree().quit()


func _shot(file_name: String, hour: float, from: Vector3, at: Vector3) -> void:
	GameState.time_of_day = hour
	_world.day_night.apply(hour)
	_camera.look_at_from_position(from, at)
	for i in 6:
		await get_tree().process_frame
	var path := OUT_DIR.path_join(file_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("Đã lưu ", ProjectSettings.globalize_path(path))
