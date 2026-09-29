extends Node
## Lưu/tải ván chơi ra file JSON trong user://saves/. Autoload tên "SaveSystem".
## Xem docs/06-luu-game.md (có phần an toàn: chỉ dùng JSON, giới hạn kích thước, ghi nguyên tử).

signal saved(slot: String)
signal loaded(slot: String)

const DIR := "user://saves"
const FORMAT := "builder_simulator_save"
const MAX_FILE_BYTES := 8 * 1024 * 1024
const AUTOSAVE_SECONDS := 300.0
const AUTOSAVE_SLOT := "auto"
const QUICK_SLOT := "quick"
const SLOT_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

## Thư mục chứa file lưu. Bộ test đổi sang thư mục riêng để không bao giờ đụng file lưu thật.
var save_dir := DIR
var autosave_enabled := true
## Giới hạn kích thước file lưu (biến để test có thể hạ xuống).
var max_file_bytes := MAX_FILE_BYTES
var _autosave_timer := AUTOSAVE_SECONDS


func _process(delta: float) -> void:
	if not autosave_enabled or get_tree().paused or _player() == null:
		return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_slot(AUTOSAVE_SLOT)


## Tên ô lưu chỉ gồm chữ thường, số, gạch dưới — chặn kiểu tên "../../x" để ghi ra ngoài thư mục lưu.
static func is_valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 32:
		return false
	for ch in slot:
		if not SLOT_CHARS.contains(ch):
			return false
	return true


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


## Lưu ván chơi. Trả về "" nếu thành công, ngược lại là lý do.
func save_slot(slot: String) -> String:
	if not is_valid_slot(slot):
		return "Tên ô lưu không hợp lệ."
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data := {
		"format": FORMAT,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"game": GameState.to_dict(),
		"player": _player_state(),
	}
	# Ghi ra file tạm rồi đổi tên: nếu game tắt giữa chừng thì file lưu cũ vẫn còn nguyên.
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "Không ghi được file lưu (%s)." % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return "Không hoàn tất được file lưu (%s)." % error_string(err)
	saved.emit(slot)
	return ""


## Tải ván chơi. Trả về "" nếu thành công, ngược lại là lý do (khi đó trạng thái game không đổi).
func load_slot(slot: String) -> String:
	var result := read_slot(slot)
	if result.has("error"):
		return result["error"]
	var data: Dictionary = result["data"]
	var err := GameState.from_dict(DataUtil.to_dict(data.get("game")))
	if not err.is_empty():
		return err
	_apply_player_state(DataUtil.to_dict(data.get("player")))
	_autosave_timer = AUTOSAVE_SECONDS
	loaded.emit(slot)
	return ""


## Đọc và kiểm tra file lưu. Trả về {"data": Dictionary} hoặc {"error": String}.
func read_slot(slot: String) -> Dictionary:
	if not is_valid_slot(slot):
		return {"error": "Tên ô lưu không hợp lệ."}
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		# Game tắt đúng lúc đang thay file (file cũ đã xoá, file mới còn tên .tmp): dùng file mới.
		if not FileAccess.file_exists(path + ".tmp"):
			return {"error": "Chưa có bản lưu ở ô này."}
		path += ".tmp"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Không mở được file lưu."}
	if file.get_length() > max_file_bytes:
		return {"error": "File lưu quá lớn — có thể đã bị hỏng."}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"error": "File lưu bị hỏng (lỗi JSON ở dòng %d)." % json.get_error_line()}
	var data := DataUtil.to_dict(json.data)
	if data.get("format") != FORMAT:
		return {"error": "Không phải file lưu của game này."}
	return {"data": data}


## Thông tin ngắn về ô lưu (cho menu): {"exists", "saved_at", "money", "day"}.
func slot_info(slot: String) -> Dictionary:
	var result := read_slot(slot)
	if result.has("error"):
		return {"exists": _slot_file_exists(slot), "error": result["error"]}
	var data: Dictionary = result["data"]
	var game := DataUtil.to_dict(data.get("game"))
	return {
		"exists": true,
		"saved_at": str(data.get("saved_at", "")),
		"money": DataUtil.to_int(game.get("money")),
		"day": DataUtil.to_int(game.get("day"), 1),
	}


func delete_slot(slot: String) -> void:
	if not is_valid_slot(slot):
		return
	for path: String in [slot_path(slot), slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _slot_file_exists(slot: String) -> bool:
	return is_valid_slot(slot) and (FileAccess.file_exists(slot_path(slot))
			or FileAccess.file_exists(slot_path(slot) + ".tmp"))


func _player() -> Node:
	if not is_inside_tree():
		return null
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


func _player_state() -> Dictionary:
	var player := _player()
	if player != null and player.has_method("get_save_state"):
		return player.call("get_save_state")
	return {}


func _apply_player_state(data: Dictionary) -> void:
	var player := _player()
	if player != null and player.has_method("apply_save_state") and not data.is_empty():
		player.call("apply_save_state", data)
