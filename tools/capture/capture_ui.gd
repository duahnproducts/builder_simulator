extends Node
## Chạy scene game thật rồi chụp HUD và từng bảng giao diện để kiểm tra bằng mắt.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . res://tools/capture/capture_ui.tscn

const OUT_DIR := "res://test_output"


func _ready() -> void:
	CaptureUtil.prepare_dir(OUT_DIR)
	GameState.new_game()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.world.day_night.running = false
	GameState.time_of_day = 9.5
	await _wait(10)
	await _shot("20_hud_bat_dau")
	var ui: UIRoot = main.ui
	ui.help.visible = false
	ui.open_panel("contracts")
	await _shot("21_bang_hop_dong")
	(ui.panels["contracts"] as ContractPanel).accept()
	ui.open_panel("shop")
	await _shot("22_cua_hang")
	ui.open_panel("blueprint")
	(ui.panels["blueprint"] as BlueprintEditor).load_template("nha_mai_bang_L")
	await _shot("23_ban_ve")
	ui.open_panel("pause")
	await _shot("24_tam_dung")
	ui.close_panel("pause")
	# Nhìn vào một bức tường của lô A1 để thấy gợi ý thao tác và checklist.
	var p := GameState.project_at("A1")
	GameState.wallet.balance = 1_000_000_000
	GameState.buy_many(GameState.missing_for_project("A1"))
	for c in p.dig.cells:
		p.dig_cell(c)
	for c in p.pour.cells:
		p.pour_cell(c)
	for i in 60:
		p.lay_brick(2)
	var player: Node3D = main.player
	var a1: Node3D = main.world.plot_node("A1")
	player.global_position = a1.to_global(Vector3(7.0, 0.3, 13.0))
	player.look_at(a1.to_global(Vector3(7.0, 1.6, 11.0)), Vector3.UP)
	player.rotation.x = 0.0
	await _wait(8)
	await _shot("25_dang_xay_co_goi_y")
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await _wait(4)
	var path := OUT_DIR.path_join(file_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("Đã lưu ", ProjectSettings.globalize_path(path))
