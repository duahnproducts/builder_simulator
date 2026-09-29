class_name UIRoot
extends CanvasLayer
## Gốc giao diện: HUD + các bảng (mỗi lúc chỉ mở một bảng) + phím tắt. Chạy cả khi game tạm dừng.
## Xem docs/09-giao-dien.md.

var hud: Hud
var help: HelpOverlay
## id → PanelBase ("shop", "contracts", "blueprint", "pause")
var panels: Dictionary = {}

var _center: CenterContainer
## Nền tối mờ phía sau bảng đang mở, cho chữ trên bảng dễ đọc.
var _backdrop: ColorRect


func setup(build: BuildController, world: World) -> void:
	name = "UI"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	hud.setup(build, world)
	help = HelpOverlay.new()
	root.add_child(help)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.02, 0.03, 0.05, 0.45)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	root.add_child(_backdrop)
	_center = CenterContainer.new()
	_center.name = "Panels"
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_center)
	var shop := ShopPanel.new()
	shop.current_plot = hud.current_plot_id
	shop.paint_choice = func() -> String: return build.paint_item if build != null else "paint_white"
	_add_panel(shop)
	_add_panel(ContractPanel.new())
	_add_panel(BlueprintEditor.new())
	var pause := PauseMenu.new()
	_add_panel(pause)
	pause.help_requested.connect(toggle_help)
	GameState.panel_requested.connect(open_panel)
	SaveSystem.saved.connect(_on_saved)


func open_panel(id: String) -> void:
	if not panels.has(id):
		return
	var current := open_panel_id()
	if current == id:
		return
	if not current.is_empty():
		(panels[current] as PanelBase).close()
	(panels[id] as PanelBase).open()


func close_panel(id: String) -> void:
	if panels.has(id):
		(panels[id] as PanelBase).close()


func toggle_panel(id: String) -> void:
	if open_panel_id() == id:
		close_panel(id)
	else:
		open_panel(id)


## Mã bảng đang mở, "" nếu không có.
func open_panel_id() -> String:
	for id: String in panels:
		if (panels[id] as PanelBase).is_open():
			return id
	return ""


func toggle_help() -> void:
	help.visible = not help.visible


func is_backdrop_visible() -> bool:
	return _backdrop.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var current := open_panel_id()
		if current.is_empty():
			open_panel("pause")
		else:
			close_panel(current)
	elif event.is_action_pressed("open_shop"):
		toggle_panel("shop")
	elif event.is_action_pressed("open_contracts"):
		toggle_panel("contracts")
	elif event.is_action_pressed("open_blueprint"):
		toggle_panel("blueprint")
	elif event.is_action_pressed("toggle_help"):
		toggle_help()
	elif event.is_action_pressed("quicksave"):
		var err := SaveSystem.save_slot(SaveSystem.QUICK_SLOT)
		if not err.is_empty():
			GameState.notify(err, "error")
	elif event.is_action_pressed("quickload"):
		var err := SaveSystem.load_slot(SaveSystem.QUICK_SLOT)
		GameState.notify(err if not err.is_empty() else "Đã tải bản lưu nhanh.", "error" if not err.is_empty() else "ok")
	else:
		return
	get_viewport().set_input_as_handled()


func _add_panel(panel: PanelBase) -> void:
	_center.add_child(panel)
	panels[panel.panel_id] = panel
	panel.opened.connect(_on_panels_changed)
	panel.closed.connect(_on_panels_changed)


## Có bảng mở: hiện nền mờ và thu gọn HUD (ẩn checklist, tâm ngắm, gợi ý, thanh công cụ).
func _on_panels_changed() -> void:
	var any := not open_panel_id().is_empty()
	_backdrop.visible = any
	hud.set_panel_mode(any)


func _on_saved(slot: String) -> void:
	if slot != SaveSystem.AUTOSAVE_SLOT:
		GameState.notify("Đã lưu game.", "ok")
