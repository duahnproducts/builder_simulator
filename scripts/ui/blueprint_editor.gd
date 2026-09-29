class_name BlueprintEditor
extends PanelBase
## Bàn vẽ: thiết kế nhà cho đất nhà mình. Kéo chuột để vẽ tường, bấm để đặt cửa hoặc tẩy.
## Hoàn tác dùng ngăn xếp (stack) các bản chụp bản vẽ. Xem docs/09-giao-dien.md.

const MAX_UNDO := 50
const PICK_DISTANCE := 0.35
const TOOL_NAMES := {"wall": "Tường", "door": "Cửa đi", "window": "Cửa sổ", "erase": "Tẩy"}

var blueprint: Blueprint
var tool := "wall"

var _undo: Array[Dictionary] = []
var _canvas: BlueprintCanvas
var _tool_buttons: Dictionary = {}
var _roof: OptionButton
var _templates: OptionButton
var _errors: RichTextLabel
var _cost: Label
var _start: Button
var _demolish: Button


func _ready() -> void:
	panel_id = "blueprint"
	name = "BlueprintEditor"
	var body := build_frame("Bàn vẽ — thiết kế nhà của bạn", Vector2(1140, 700))
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	_canvas = BlueprintCanvas.new()
	_canvas.custom_minimum_size = Vector2(620, 590)
	_canvas.wall_drawn.connect(add_wall)
	_canvas.point_clicked.connect(_on_point_clicked)
	split.add_child(_canvas)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	var help := UITheme.label("Kéo chuột trái trên lưới để vẽ tường (ngang hoặc dọc). Chọn Cửa đi / Cửa sổ rồi "
			+ "bấm lên một bức tường. Ctrl+Z để hoàn tác.", 16, UITheme.TEXT_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(help)
	var tools := HBoxContainer.new()
	for id: String in TOOL_NAMES:
		var b := UITheme.button(TOOL_NAMES[id], set_tool.bind(id))
		b.toggle_mode = true
		tools.add_child(b)
		_tool_buttons[id] = b
	side.add_child(tools)
	_roof = OptionButton.new()
	_roof.add_item("Mái ngói (nhà hình chữ nhật)")
	_roof.add_item("Mái bằng (mọi hình dạng)")
	_roof.item_selected.connect(func(index: int) -> void: set_roof("gable" if index == 0 else "flat"))
	side.add_child(_roof)
	_templates = OptionButton.new()
	_templates.add_item("— Nạp bản vẽ mẫu —")
	for id in Catalog.blueprint_ids():
		_templates.add_item(Catalog.blueprint_name(id))
	_templates.item_selected.connect(_on_template_selected)
	side.add_child(_templates)
	var edit := HBoxContainer.new()
	edit.add_child(UITheme.button("Hoàn tác", undo))
	edit.add_child(UITheme.button("Xoá hết", clear_all))
	side.add_child(edit)
	_errors = RichTextLabel.new()
	_errors.bbcode_enabled = true
	_errors.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_errors.add_theme_font_size_override("normal_font_size", 16)
	side.add_child(_errors)
	_cost = UITheme.label("", 18, UITheme.ACCENT)
	side.add_child(_cost)
	_start = UITheme.button("Bắt đầu xây", start_building)
	side.add_child(_start)
	_demolish = UITheme.button("Phá bỏ nhà hiện tại", demolish)
	side.add_child(_demolish)
	split.add_child(side)
	body.add_child(split)
	set_tool("wall")


func refresh() -> void:
	if blueprint == null:
		blueprint = _initial_blueprint()
	_canvas.blueprint = blueprint
	_update_validation()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and key.ctrl_pressed and key.physical_keycode == KEY_Z:
		undo()
		get_viewport().set_input_as_handled()


# ─── API chỉnh sửa (chuột và test đều gọi qua đây) ─────────────────────────

func set_tool(id: String) -> void:
	tool = id
	_canvas.tool = id
	for key: String in _tool_buttons:
		(_tool_buttons[key] as Button).button_pressed = key == id


## Thêm tường nối hai điểm lưới (phải cùng hàng hoặc cùng cột).
func add_wall(a: Vector2i, b: Vector2i) -> bool:
	if a == b or (a.x != b.x and a.y != b.y):
		return false
	_push_undo()
	blueprint.add_wall(_clamp_point(a), _clamp_point(b))
	_changed()
	return true


## Đặt cửa (door/window) lên bức tường gần điểm `point` nhất (toạ độ lưới), căn giữa vào điểm bấm.
func add_opening_at(point: Vector2, type: String) -> bool:
	var w := wall_near(point)
	if w < 0 or not BuildConst.OPENING_TYPES.has(type):
		return false
	var width: float = BuildConst.OPENING_TYPES[type]["width"]
	var length := blueprint.wall_length(w)
	var margin := BuildConst.OPENING_MARGIN
	if length - width - 2.0 * margin < -0.001:
		GameState.notify("Tường quá ngắn để đặt %s." % str(BuildConst.OPENING_TYPES[type]["name"]).to_lower(), "warn")
		return false
	var offset := clampf(snappedf(_along(w, point) - width / 2.0, 0.2), margin, length - width - margin)
	_push_undo()
	blueprint.add_opening(w, type, offset)
	_changed()
	return true


## Tẩy cửa (ưu tiên) hoặc tường gần điểm bấm.
func erase_at(point: Vector2) -> bool:
	var k := opening_near(point)
	if k >= 0:
		_push_undo()
		blueprint.remove_opening(k)
		_changed()
		return true
	var w := wall_near(point)
	if w >= 0:
		_push_undo()
		blueprint.remove_wall(w)
		_changed()
		return true
	return false


func undo() -> bool:
	if _undo.is_empty():
		return false
	blueprint = Blueprint.from_dict(_undo.pop_back())
	_canvas.blueprint = blueprint
	_changed()
	return true


func undo_depth() -> int:
	return _undo.size()


func clear_all() -> void:
	_push_undo()
	var empty := Blueprint.new()
	empty.id = "home"
	empty.name = "Nhà của bạn"
	empty.size = blueprint.size
	empty.roof = blueprint.roof
	blueprint = empty
	_canvas.blueprint = blueprint
	_changed()


func set_roof(roof: String) -> void:
	if blueprint.roof == roof:
		return
	_push_undo()
	blueprint.roof = roof
	_changed()


func load_template(id: String) -> bool:
	var template := Catalog.blueprint(id)
	if template == null:
		return false
	_push_undo()
	template.id = "home"
	blueprint = template
	_canvas.blueprint = blueprint
	_changed()
	return true


func validation_errors() -> Array[String]:
	return BlueprintValidator.validate(blueprint)


## Dự toán tiền vật tư của bản vẽ (0 nếu bản vẽ chưa hợp lệ).
func estimated_cost() -> int:
	if not validation_errors().is_empty():
		return 0
	return Catalog.cost_of(ConstructionProject.new(blueprint.duplicate_blueprint(), Inventory.new()).remaining_materials())


func start_building() -> String:
	var err := GameState.start_home_project(blueprint.duplicate_blueprint())
	if err.is_empty():
		close()
	else:
		GameState.notify(err, "error")
		_update_validation()
	return err


func demolish() -> void:
	if GameState.project_at(GameState.HOME_PLOT) == null:
		return
	GameState.demolish_home_project()
	GameState.notify("Đã phá bỏ công trình trên đất nhà bạn.", "warn")
	_update_validation()


## Chỉ số tường gần điểm (toạ độ lưới) nhất trong phạm vi PICK_DISTANCE, hoặc −1.
func wall_near(point: Vector2) -> int:
	var best := -1
	var best_dist := PICK_DISTANCE
	for i in blueprint.wall_count():
		var d := _distance_to_segment(point, Vector2(blueprint.wall_a[i]), Vector2(blueprint.wall_b[i]))
		if d <= best_dist:
			best = i
			best_dist = d
	return best


## Chỉ số cửa gần điểm nhất trong phạm vi PICK_DISTANCE, hoặc −1.
func opening_near(point: Vector2) -> int:
	for k in blueprint.openings.size():
		var w := int(blueprint.openings[k]["wall"])
		if w < 0 or w >= blueprint.wall_count():
			continue
		var a := Vector2(blueprint.wall_a[w])
		var dir := (Vector2(blueprint.wall_b[w]) - a).normalized()
		var u0: float = blueprint.openings[k]["offset"]
		var seg_a := a + dir * u0
		var seg_b := a + dir * (u0 + blueprint.opening_width(k))
		if _distance_to_segment(point, seg_a, seg_b) <= PICK_DISTANCE:
			return k
	return -1


func _initial_blueprint() -> Blueprint:
	var current := GameState.project_at(GameState.HOME_PLOT)
	if current != null:
		return current.blueprint.duplicate_blueprint()
	var bp := Blueprint.new()
	bp.id = "home"
	bp.name = "Nhà của bạn"
	bp.size = Catalog.plot_size(Catalog.plot(GameState.HOME_PLOT))
	return bp


func _push_undo() -> void:
	_undo.append(blueprint.to_dict())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func _changed() -> void:
	_canvas.blueprint_changed()
	_update_validation()


func _update_validation() -> void:
	if _errors == null:
		return
	_roof.selected = 0 if blueprint.roof == "gable" else 1
	var errors := validation_errors()
	var current := GameState.project_at(GameState.HOME_PLOT)
	var busy := current != null and not current.is_complete() and current.dig.done_count() > 0
	_demolish.visible = current != null
	if errors.is_empty():
		_errors.text = "[color=#73d980]Bản vẽ hợp lệ.[/color] %d tường, %d cửa." % [blueprint.wall_count(),
				blueprint.openings.size()]
		_cost.text = "Dự toán vật tư: " + Money.format(estimated_cost())
	else:
		_errors.text = "[color=#ff7a6b]" + "\n".join(errors) + "[/color]"
		_cost.text = ""
	if busy:
		_errors.text += "\n[color=#ffc452]Đất nhà bạn đang có công trình dở dang — phá bỏ trước khi xây bản vẽ mới.[/color]"
	_start.disabled = not errors.is_empty() or busy


func _on_point_clicked(point: Vector2) -> void:
	if tool == "erase":
		erase_at(point)
	else:
		add_opening_at(point, tool)


func _on_template_selected(index: int) -> void:
	if index > 0:
		load_template(Catalog.blueprint_ids()[index - 1])
	_templates.selected = 0


func _clamp_point(p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x, 0, blueprint.size.x), clampi(p.y, 0, blueprint.size.y))


func _along(w: int, point: Vector2) -> float:
	var a := Vector2(blueprint.wall_a[w])
	var dir := (Vector2(blueprint.wall_b[w]) - a).normalized()
	return clampf((point - a).dot(dir), 0.0, blueprint.wall_length(w))


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
