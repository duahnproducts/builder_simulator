class_name ContractPanel
extends PanelBase
## Bảng hợp đồng: danh sách, chi tiết, xem trước bản vẽ; nhận, nghiệm thu, huỷ.
## Xem docs/05-kinh-te-hop-dong.md.

const STATUS_TEXT := {
	"locked": "Chưa mở — cần thêm uy tín",
	"available": "Có thể nhận",
	"busy": "Đang bận hợp đồng khác",
	"active": "ĐANG LÀM",
	"done": "Đã hoàn thành",
}

var selected := ""

## Mỗi hợp đồng một hàng (nút bật/tắt có 2 dòng: tên + trạng thái): id → Button.
var _rows: Dictionary = {}
var _group := ButtonGroup.new()
var _ids: Array[String] = []
var _title: Label
var _desc: Label
var _info: RichTextLabel
var _preview: BlueprintPreview
var _accept: Button
var _complete: Button
var _abandon: Button


func _ready() -> void:
	panel_id = "contracts"
	name = "ContractPanel"
	var body := build_frame("Bảng hợp đồng", Vector2(1100, 660))
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	# ItemList chỉ hiện một dòng mỗi mục (ký tự xuống dòng bị bỏ), nên tự dựng từng hàng.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	for c in Catalog.contracts():
		var id := str(c["id"])
		_ids.append(id)
		_rows[id] = _make_row(id, str(c.get("title", id)))
		list.add_child(_rows[id])
	scroll.add_child(list)
	split.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UITheme.label("", 22, UITheme.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_title)
	_desc = UITheme.label("", 17, UITheme.TEXT_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_desc)
	var detail := HBoxContainer.new()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview = BlueprintPreview.new()
	_preview.custom_minimum_size = Vector2(320, 340)
	detail.add_child(_preview)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("normal_font_size", 17)
	_info.add_theme_font_size_override("bold_font_size", 17)
	detail.add_child(_info)
	right.add_child(detail)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_accept = UITheme.button("Nhận hợp đồng", accept)
	_complete = UITheme.button("Nghiệm thu, nhận tiền", complete)
	_abandon = UITheme.button("Huỷ hợp đồng", abandon)
	for b in [_accept, _complete, _abandon]:
		buttons.add_child(b)
	right.add_child(buttons)
	split.add_child(right)
	body.add_child(split)
	GameState.contracts_changed.connect(_on_contracts_changed)


func refresh() -> void:
	for id in _ids:
		var status := GameState.contract_status(id)
		var label := (_rows[id] as Button).find_child("Status", true, false) as Label
		label.text = STATUS_TEXT.get(status, status)
		label.add_theme_color_override("font_color", _status_color(status))
	if selected.is_empty() or not _ids.has(selected):
		selected = _default_selection()
	# set_pressed_no_signal() không tự bỏ chọn các nút khác trong ButtonGroup, nên đặt cho từng hàng.
	for id in _ids:
		(_rows[id] as Button).set_pressed_no_signal(id == selected)
	_show(selected)


## Các hợp đồng đang được đánh dấu chọn trong danh sách (cho test; đúng ra chỉ có một).
func pressed_rows() -> Array[String]:
	var out: Array[String] = []
	for id in _ids:
		if (_rows[id] as Button).button_pressed:
			out.append(id)
	return out


## Chữ trạng thái đang hiện ở hàng của hợp đồng `id` (cho test).
func row_status_text(id: String) -> String:
	var row: Button = _rows.get(id)
	return (row.find_child("Status", true, false) as Label).text if row != null else ""


func select_contract(id: String) -> void:
	selected = id
	refresh()


func accept() -> String:
	var err := GameState.accept_contract(selected)
	if not err.is_empty():
		GameState.notify(err, "error")
	refresh()
	return err


func complete() -> String:
	var err := GameState.complete_contract(selected)
	if not err.is_empty():
		GameState.notify(err, "warn")
	refresh()
	return err


func abandon() -> String:
	var err := GameState.abandon_contract(selected)
	if not err.is_empty():
		GameState.notify(err, "error")
	refresh()
	return err


func _default_selection() -> String:
	if not GameState.active_contract.is_empty():
		return GameState.active_contract
	for id in _ids:
		if GameState.contract_status(id) == "available":
			return id
	return _ids[0] if not _ids.is_empty() else ""


func _show(id: String) -> void:
	var c := Catalog.contract(id)
	if c.is_empty():
		_title.text = ""
		_desc.text = ""
		_info.text = ""
		return
	var status := GameState.contract_status(id)
	_title.text = "%s — %s" % [str(c.get("title", id)), str(c.get("client", ""))]
	_desc.text = str(c.get("desc", ""))
	var bp_id := str(c.get("blueprint", ""))
	_preview.blueprint = Catalog.blueprint(bp_id)
	var cost := Catalog.contract_cost(id)
	var reward := Catalog.contract_reward(id)
	var lines: Array[String] = [
		"[b]Trạng thái:[/b] %s" % STATUS_TEXT.get(status, status),
		"[b]Nhà:[/b] %s" % Catalog.blueprint_name(bp_id),
		"[b]Địa điểm:[/b] %s" % Catalog.plot_name(str(c.get("plot", ""))),
		"[b]Tiền công:[/b] [color=#f9b840]%s[/color]" % Money.format(reward),
		"[b]Dự toán vật tư:[/b] %s  (lãi khoảng %s)" % [Money.format(cost), Money.format(reward - cost)],
		"[b]Uy tín:[/b] +%d khi hoàn thành (cần ≥ %d)" % [DataUtil.to_int(c.get("reputation"), 1),
				DataUtil.to_int(c.get("min_reputation"))],
		"[b]Nội thất yêu cầu:[/b] %s" % _furniture_text(Catalog.contract_furniture(id)),
	]
	var p := GameState.project_at(str(c.get("plot", "")))
	if status == "active" and p != null:
		lines.append("")
		lines.append("[b]Tiến độ:[/b]")
		for stage in p.stage_order():
			var done := p.stage_status(stage) == ConstructionProject.Status.DONE
			lines.append("  %s %s — %d%%" % ["[color=#73d980]✓[/color]" if done else "·",
					ConstructionProject.stage_name(stage), roundi(p.stage_progress(stage) * 100)])
		var missing := p.missing_furniture()
		if not missing.is_empty() and p.can_furnish():
			lines.append("  Còn thiếu nội thất: " + _furniture_text(missing))
	_info.text = "\n".join(lines)
	_accept.visible = status == "available"
	_complete.visible = status == "active"
	_complete.disabled = p == null or not p.is_complete()
	_abandon.visible = status == "active"


static func _furniture_text(items: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in items:
		parts.append("%d %s" % [int(items[id]), Catalog.item_name(id).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "không"


static func _status_color(status: String) -> Color:
	match status:
		"available":
			return UITheme.OK
		"active":
			return UITheme.ACCENT
		"done":
			return UITheme.INFO
	return UITheme.TEXT_DIM


func _make_row(id: String, title: String) -> Button:
	var row := Button.new()
	row.name = "Row_" + id
	row.toggle_mode = true
	row.button_group = _group
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, 62)
	row.pressed.connect(select_contract.bind(id))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10 if side in ["left", "right"] else 6)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	var title_label := UITheme.label(title, 17)
	title_label.name = "Title"
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title_label)
	var status_label := UITheme.label("", 15)
	status_label.name = "Status"
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(status_label)
	margin.add_child(vb)
	row.add_child(margin)
	return row


func _on_contracts_changed() -> void:
	if visible:
		refresh()
