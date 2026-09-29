class_name Hud
extends Control
## HUD: tiền, uy tín, giờ; checklist công trình; tâm ngắm + gợi ý; thanh chế độ; thông báo.
## Xem docs/09-giao-dien.md.

const TOAST_SECONDS := 3.5
const STATUS_ICON := {
	ConstructionProject.Status.DONE: "✓",
	ConstructionProject.Status.AVAILABLE: "»",
	ConstructionProject.Status.LOCKED: "·",
}

var build: BuildController
var world: World

var _money: Label
var _reputation: Label
var _clock: Label
var _project_box: PanelContainer
var _project_title: Label
var _stage_rows: VBoxContainer
var _hint: Label
var _crosshair: Control
var _hotbar_box: Control
var _hotbar: Array[PanelContainer] = []
var _selection: Label
var _selection_swatch: ColorRect
var _toasts: VBoxContainer
var _refresh_timer := 0.0


func setup(p_build: BuildController, p_world: World) -> void:
	build = p_build
	world = p_world
	name = "Hud"
	# set_anchors_preset() giữ nguyên kích thước hiện tại (0×0) bằng cách tự chỉnh offset;
	# phải đặt cả offset để HUD phủ kín màn hình.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status_box()
	_build_project_box()
	_build_center()
	_build_hotbar()
	_build_toasts()
	GameState.money_changed.connect(func(_b: int) -> void: _update_status())
	GameState.contracts_changed.connect(_update_status)
	GameState.toast.connect(show_toast)
	if build != null:
		build.hint_changed.connect(_on_hint_changed)
		build.mode_changed.connect(func(_m: int) -> void: _update_hotbar())
		build.selection_changed.connect(func(_id: String) -> void: _update_hotbar())
	GameState.inventory_changed.connect(func(_id: String, _n: int) -> void: _update_hotbar())
	_update_status()
	_update_hotbar()
	refresh_project()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_clock.text = GameState.clock_text()
		refresh_project()


## Lô đất của công trình đang hiển thị: nơi nhân vật đứng, nếu không thì hợp đồng đang làm.
func current_plot_id() -> String:
	if world != null and is_inside_tree():
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var here := world.plot_at((players[0] as Node3D).global_position)
			if not here.is_empty() and GameState.project_at(here) != null:
				return here
	if not GameState.active_contract.is_empty():
		return str(Catalog.contract(GameState.active_contract).get("plot", ""))
	if GameState.project_at(GameState.HOME_PLOT) != null:
		return GameState.HOME_PLOT
	return ""


func refresh_project() -> void:
	var plot_id := current_plot_id()
	var p := GameState.project_at(plot_id)
	_project_box.visible = p != null
	if p == null:
		return
	_project_title.text = _project_name(plot_id)
	var order := p.stage_order()
	while _stage_rows.get_child_count() < order.size():
		_stage_rows.add_child(_stage_row())
	for i in order.size():
		var row := _stage_rows.get_child(i) as HBoxContainer
		var status := p.stage_status(order[i])
		var label := row.get_child(0) as Label
		label.text = "%s  %s" % [STATUS_ICON[status], ConstructionProject.stage_name(order[i])]
		var color := UITheme.OK if status == ConstructionProject.Status.DONE else (
				UITheme.TEXT if status == ConstructionProject.Status.AVAILABLE else UITheme.TEXT_DIM)
		label.add_theme_color_override("font_color", color)
		(row.get_child(1) as ProgressBar).value = p.stage_progress(order[i]) * 100.0
	if p.is_complete() and plot_id != GameState.HOME_PLOT and GameState.active_contract != "":
		_project_title.text += "\n→ Xong! Mở bảng hợp đồng (J) để nghiệm thu"


func show_toast(text: String, kind := "info") -> void:
	var box := PanelContainer.new()
	var label := UITheme.label(text, 18, _toast_color(kind))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	_toasts.add_child(box)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	get_tree().create_timer(TOAST_SECONDS, true).timeout.connect(_expire_toast.bind(box))


func toast_count() -> int:
	return _toasts.get_child_count()


func hint_text() -> String:
	return _hint.text


func money_text() -> String:
	return _money.text


## Hình chữ nhật (toạ độ màn hình) của các thành phần chính — để test bố cục không tràn ra ngoài.
func element_rects() -> Dictionary:
	return {
		"hint": _hint.get_global_rect(),
		"crosshair": _crosshair.get_global_rect(),
		"hotbar": _hotbar_box.get_global_rect(),
		"toasts": _toasts.get_global_rect(),
		"project": _project_box.get_global_rect(),
	}


func highlighted_mode() -> int:
	for i in _hotbar.size():
		if _hotbar[i].modulate == Color.WHITE:
			return i
	return -1


func _expire_toast(box: Control) -> void:
	if is_instance_valid(box):
		var tween := box.create_tween()
		tween.tween_property(box, "modulate:a", 0.0, 0.4)
		tween.tween_callback(box.queue_free)


static func _toast_color(kind: String) -> Color:
	match kind:
		"ok":
			return UITheme.OK
		"warn":
			return UITheme.WARN
		"error":
			return UITheme.ERROR
	return UITheme.TEXT


func _project_name(plot_id: String) -> String:
	if plot_id == GameState.HOME_PLOT:
		return "Nhà của bạn"
	for c in Catalog.contracts():
		if str(c.get("plot", "")) == plot_id:
			return str(c.get("title", plot_id))
	return Catalog.plot_name(plot_id)


func _update_status() -> void:
	_money.text = Money.format(GameState.wallet.balance)
	_reputation.text = "Uy tín: %d" % GameState.reputation
	_clock.text = GameState.clock_text()


func _update_hotbar() -> void:
	var mode := build.mode if build != null else 0
	for i in _hotbar.size():
		_hotbar[i].modulate = Color.WHITE if i == mode else Color(1, 1, 1, 0.45)
	var item := build.selected_item() if build != null else ""
	_selection_swatch.visible = not item.is_empty()
	if item.is_empty():
		_selection.text = ""
		return
	_selection_swatch.color = Catalog.item_color(item)
	_selection.text = "%s — kho: %d   (lăn chuột để đổi)" % [Catalog.item_name(item), GameState.inventory.count(item)]


func _on_hint_changed(text: String) -> void:
	_hint.text = text


func _build_status_box() -> void:
	var box := PanelContainer.new()
	box.position = Vector2(16, 16)
	var vb := VBoxContainer.new()
	_money = UITheme.label("", 26, UITheme.ACCENT)
	_reputation = UITheme.label("", 18)
	_clock = UITheme.label("", 16, UITheme.TEXT_DIM)
	vb.add_child(_money)
	vb.add_child(_reputation)
	vb.add_child(_clock)
	box.add_child(vb)
	add_child(box)


func _build_project_box() -> void:
	_project_box = PanelContainer.new()
	UITheme.anchor(_project_box, Control.PRESET_TOP_RIGHT, -350, 16, -16, 16)
	_project_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_project_box.custom_minimum_size = Vector2(334, 0)
	var vb := VBoxContainer.new()
	_project_title = UITheme.label("", 19, UITheme.ACCENT)
	_project_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_project_title)
	_stage_rows = VBoxContainer.new()
	vb.add_child(_stage_rows)
	_project_box.add_child(vb)
	add_child(_project_box)


func _stage_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := UITheme.label("", 16)
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(130, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	return row


func _build_center() -> void:
	_crosshair = Crosshair.new()
	UITheme.anchor(_crosshair, Control.PRESET_CENTER, -12, -12, 12, 12)
	add_child(_crosshair)
	_hint = UITheme.label("", 19)
	UITheme.anchor(_hint, Control.PRESET_CENTER, -450, 26, 450, 70)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_hint)


func _build_hotbar() -> void:
	var bottom := VBoxContainer.new()
	UITheme.anchor(bottom, Control.PRESET_CENTER_BOTTOM, -380, -100, 380, -18)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	var sel := HBoxContainer.new()
	sel.alignment = BoxContainer.ALIGNMENT_CENTER
	_selection_swatch = UITheme.swatch(Color.WHITE)
	sel.add_child(_selection_swatch)
	_selection = UITheme.label("", 17)
	_selection.add_theme_constant_override("outline_size", 6)
	_selection.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sel.add_child(_selection)
	bottom.add_child(sel)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	for i in BuildController.MODE_NAMES.size():
		var slot := PanelContainer.new()
		slot.add_child(UITheme.label("%d  %s" % [i + 1, BuildController.MODE_NAMES[i]], 17))
		bar.add_child(slot)
		_hotbar.append(slot)
	bottom.add_child(bar)
	add_child(bottom)
	_hotbar_box = bottom


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	UITheme.anchor(_toasts, Control.PRESET_CENTER_TOP, -250, 16, 250, 16)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


## Tâm ngắm: dấu cộng nhỏ ở giữa màn hình.
class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(24, 24)

	func _draw() -> void:
		var c := size / 2.0
		var color := Color(1, 1, 1, 0.9)
		draw_line(c - Vector2(9, 0), c + Vector2(9, 0), Color(0, 0, 0, 0.6), 4.0)
		draw_line(c - Vector2(0, 9), c + Vector2(0, 9), Color(0, 0, 0, 0.6), 4.0)
		draw_line(c - Vector2(8, 0), c + Vector2(8, 0), color, 2.0)
		draw_line(c - Vector2(0, 8), c + Vector2(0, 8), color, 2.0)
