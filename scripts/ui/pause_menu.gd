class_name PauseMenu
extends PanelBase
## Menu tạm dừng: tiếp tục, lưu/tải 3 ô, ván mới, hướng dẫn, thoát. Mở menu thì game dừng hẳn.

signal help_requested

const SLOTS := ["slot1", "slot2", "slot3"]

var _slot_labels: Dictionary = {}
var _new_game_button: Button
var _confirm_new_game := false


func _ready() -> void:
	panel_id = "pause"
	name = "PauseMenu"
	var body := build_frame("Tạm dừng", Vector2(640, 0))
	body.add_child(UITheme.button("Tiếp tục chơi", close))
	body.add_child(UITheme.button("Hướng dẫn phím (F1)", func() -> void: help_requested.emit()))
	body.add_child(HSeparator.new())
	body.add_child(UITheme.label("Lưu / tải game", 20, UITheme.ACCENT))
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var row := HBoxContainer.new()
		var info := UITheme.label("", 16, UITheme.TEXT_DIM)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		row.add_child(UITheme.button("Lưu", func() -> void: save(slot)))
		row.add_child(UITheme.button("Tải", func() -> void: load_game(slot)))
		body.add_child(row)
		_slot_labels[slot] = info
	var auto_row := HBoxContainer.new()
	var auto_info := UITheme.label("", 16, UITheme.TEXT_DIM)
	auto_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_row.add_child(auto_info)
	auto_row.add_child(UITheme.button("Tải", func() -> void: load_game(SaveSystem.AUTOSAVE_SLOT)))
	body.add_child(auto_row)
	_slot_labels[SaveSystem.AUTOSAVE_SLOT] = auto_info
	body.add_child(HSeparator.new())
	_new_game_button = UITheme.button("Ván mới", new_game)
	body.add_child(_new_game_button)
	body.add_child(UITheme.button("Thoát game", func() -> void: get_tree().quit()))


func open() -> void:
	super.open()
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	super.close()
	get_tree().paused = false


func refresh() -> void:
	_confirm_new_game = false
	_new_game_button.text = "Ván mới"
	for slot: String in _slot_labels:
		var info := SaveSystem.slot_info(slot)
		var title := "Tự động lưu" if slot == SaveSystem.AUTOSAVE_SLOT else "Ô " + slot.trim_prefix("slot")
		var text := "%s: trống" % title
		if info.has("error") and info["exists"]:
			text = "%s: %s" % [title, info["error"]]
		elif info["exists"]:
			text = "%s: %s — ngày %d — %s" % [title, info["saved_at"], info["day"], Money.format(info["money"])]
		(_slot_labels[slot] as Label).text = text


func save(slot: String) -> String:
	var err := SaveSystem.save_slot(slot)
	if not err.is_empty():
		GameState.notify(err, "error")
	refresh()
	return err


func load_game(slot: String) -> String:
	var err := SaveSystem.load_slot(slot)
	if err.is_empty():
		GameState.notify("Đã tải game.", "ok")
		close()
	else:
		GameState.notify(err, "error")
	return err


## Bấm lần đầu để hỏi lại, lần hai mới bắt đầu ván mới (tránh bấm nhầm mất tiến độ).
func new_game() -> void:
	if not _confirm_new_game:
		_confirm_new_game = true
		_new_game_button.text = "Bấm lần nữa để xác nhận ván mới (tiến độ chưa lưu sẽ mất)"
		return
	GameState.new_game()
	GameState.notify("Bắt đầu ván mới.", "ok")
	close()
