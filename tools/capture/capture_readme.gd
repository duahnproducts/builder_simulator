extends Node
## Chụp bộ ảnh minh hoạ cho README (docs/images/*.jpg) từ scene game thật.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --audio-driver Dummy --path . \
##       res://tools/capture/capture_readme.tscn
## Chạy lại khi hình ảnh hoặc giao diện thay đổi nhiều. Công trình được dựng thẳng qua
## ConstructionProject cho nhanh (bài nghiệm thu mới là nơi chơi thật qua BuildController).

const OUT_DIR := "res://docs/images"
const QUALITY := 0.85

var main: Main
var cam := Camera3D.new()
var _caption_layer: CanvasLayer
var _caption_box: PanelContainer
var _caption: Label


func _ready() -> void:
	CaptureUtil.prepare_dir(OUT_DIR)
	SaveSystem.autosave_enabled = false
	GameState.new_game()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.world.day_night.running = false
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_build_caption()
	GameState.wallet.balance = 5_000_000_000
	_set_hour(15.0)
	await _wait(5)
	await _stages_collage()
	await _overview()
	await _interior()
	await _building_with_hud()
	await _panels()
	get_tree().quit()


# ─── Các ảnh ────────────────────────────────────────────────────────────────

## Bốn giai đoạn của cùng một căn nhà (lô A2), ghép thành lưới 2 × 2.
func _stages_collage() -> void:
	main.ui.visible = false
	var p := _project("A2", "nha_cap4_2phong")
	var view := [Vector3(-51.0, 5.5, -2.0), Vector3(-43.0, 1.4, -12.0)]
	var tiles: Array[Image] = []
	_dig_pour(p, 0.6)
	tiles.append(await _grab("1 · Đào và đổ móng", view))
	_dig_pour(p, 1.0)
	_walls(p, 0.5)
	for w in 2:
		while not p.is_wall_done(w):
			p.lay_brick(w)
	tiles.append(await _grab("2 · Xây tường từng viên gạch", view))
	_walls(p, 1.0)
	_openings(p)
	_roof(p, 0.45)
	tiles.append(await _grab("3 · Lắp cửa, xây tường hồi, lợp mái", view))
	_roof(p, 1.0)
	_finish(p, "paint_yellow")
	main.world.house_view("A2").opening_view(0).set_open(true)
	tiles.append(await _grab("4 · Trát, sơn, lát nền — xong!", view))
	_caption_layer.visible = false
	_save(CaptureUtil.collage_2x2(tiles), "02_cac_giai_doan")


## Toàn cảnh: nhà xong, nhà đang lợp, nhà đang xây tường; cửa hàng và bảng hợp đồng phía xa.
func _overview() -> void:
	var a1 := _project("A1", "nha_cap4_nho", Catalog.contract_furniture("hd01"))
	_dig_pour(a1, 1.0)
	_walls(a1, 1.0)
	_openings(a1)
	_roof(a1, 1.0)
	_finish(a1, "paint_cream")
	_furnish_a1(a1)
	var a3 := _project("A3", "nha_mai_bang_L")
	_dig_pour(a3, 1.0)
	_walls(a3, 0.55)
	_set_hour(16.0)
	await _shot("01_toan_canh", [Vector3(-12.0, 24.0, 20.0), Vector3(-40.0, 0.0, -14.0)])


func _interior() -> void:
	main.world.house_view("A1").opening_view(0).set_open(true)
	_set_hour(15.0)
	await _shot("04_noi_that", [Vector3(-60.6, 2.2, -9.5), Vector3(-64.5, 0.6, -12.8)])


## Góc nhìn người chơi đang xây tường ở lô A3: gợi ý thao tác, checklist, thanh công cụ.
func _building_with_hud() -> void:
	main.ui.visible = true
	main.ui.help.visible = false
	main.player.global_position = main.world.plot_node("A3").to_global(Vector3(7.0, 0.1, 13.5))
	GameState.buy_many(GameState.missing_for_project("A3"))
	_set_hour(10.0)
	var a3 := main.world.plot_node("A3")
	cam.look_at_from_position(a3.to_global(Vector3(9.5, 1.7, 15.2)), a3.to_global(Vector3(9.0, 1.0, 12.0)))
	await _wait(12)
	_save(CaptureUtil.grab(get_viewport()), "03_dang_xay")


func _panels() -> void:
	var ui := main.ui
	GameState.reputation = 2
	GameState.contracts_changed.emit()
	ui.open_panel("contracts")
	(ui.panels["contracts"] as ContractPanel).select_contract("hd03")
	await _wait(6)
	_save(CaptureUtil.grab(get_viewport()), "06_hop_dong")
	ui.open_panel("blueprint")
	(ui.panels["blueprint"] as BlueprintEditor).load_template("nha_vuon")
	await _wait(6)
	_save(CaptureUtil.grab(get_viewport()), "05_ban_ve")
	ui.close_panel("blueprint")


# ─── Dựng công trình nhanh ──────────────────────────────────────────────────

func _project(plot_id: String, blueprint_id: String, furniture := {}) -> ConstructionProject:
	var p := ConstructionProject.new(Catalog.blueprint(blueprint_id), GameState.inventory, plot_id)
	p.required_furniture = furniture
	GameState.add_project(plot_id, p)
	return p


func _stock(p: ConstructionProject, paint := "paint_white") -> void:
	GameState.buy_many(GameState.inventory.missing_for(p.remaining_materials(paint)))


func _dig_pour(p: ConstructionProject, fraction: float) -> void:
	_stock(p)
	for c in p.dig.cells:
		p.dig_cell(c)
	for i in int(p.pour.total() * fraction):
		p.pour_cell(p.pour.cells[i])


func _walls(p: ConstructionProject, fraction: float) -> void:
	_stock(p)
	for w in p.walls.size():
		var target := int(p.walls[w].layout.slot_count() * fraction)
		while p.bricks[w] < target:
			p.lay_brick(w)


func _openings(p: ConstructionProject) -> void:
	_stock(p)
	for k in p.openings_done.size():
		p.install_opening(k)


func _roof(p: ConstructionProject, fraction: float) -> void:
	_stock(p)
	if p.is_flat_roof():
		for i in int(p.roof_cells.total() * fraction):
			p.pour_roof_cell(p.roof_cells.cells[i])
		return
	for g in p.roof.gables.size():
		while not p.is_gable_done(g):
			p.lay_gable_brick(g)
	var target := p.roof.truss_count() + int(p.roof.tile_count() * fraction) if fraction < 1.0 \
			else p.roof.piece_count()
	while p.roof_laid < target:
		p.lay_roof_piece()


func _finish(p: ConstructionProject, paint: String) -> void:
	_stock(p, paint)
	for w in p.walls.size():
		for side in 2:
			while p.plaster[w][side] < 1.0:
				p.apply_plaster(w, side, 5.0)
			while p.paint_progress[w][side] < 1.0:
				p.apply_paint(w, side, paint, 5.0)
	for c in p.floor_tiles.cells:
		p.tile_floor(c)


func _furnish_a1(p: ConstructionProject) -> void:
	_stock(p)
	p.place_furniture("bed", Vector3(5.2, 0.33, 7.4), 0.0)
	p.place_furniture("wardrobe", Vector3(9.3, 0.33, 7.0), -PI / 2)
	p.place_furniture("table", Vector3(7.4, 0.33, 9.0), 0.0)
	p.place_furniture("chair", Vector3(7.0, 0.33, 8.4), 0.0)
	p.place_furniture("chair", Vector3(7.8, 0.33, 9.6), PI)


# ─── Chụp ───────────────────────────────────────────────────────────────────

func _build_caption() -> void:
	_caption_layer = CanvasLayer.new()
	_caption_layer.layer = 20
	_caption_layer.visible = false
	add_child(_caption_layer)
	_caption_box = PanelContainer.new()
	_caption_box.theme = UITheme.build()
	_caption_box.position = Vector2(28, 24)
	_caption_layer.add_child(_caption_box)
	_caption = UITheme.label("", 44, UITheme.ACCENT)
	_caption_box.add_child(_caption)


func _grab(caption: String, view: Array) -> Image:
	_caption.text = caption
	_caption_layer.visible = true
	_caption_box.reset_size()
	cam.look_at_from_position(view[0], view[1])
	await _wait(6)
	return CaptureUtil.grab(get_viewport())


func _shot(file_name: String, view: Array) -> void:
	_caption_layer.visible = false
	cam.look_at_from_position(view[0], view[1])
	await _wait(6)
	_save(CaptureUtil.grab(get_viewport()), file_name)


func _save(img: Image, file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(file_name + ".jpg"))
	img.save_jpg(path, QUALITY)
	print("Đã lưu ", path)


func _set_hour(hour: float) -> void:
	GameState.time_of_day = hour
	main.world.day_night.apply(hour)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
