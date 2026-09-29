extends Node
## Trình chạy test tự viết, không cần addon ngoài.
##
## Chạy:  godot --headless --path . res://tests/runner.tscn -- [--filter=chuoi]
## Mã thoát: 0 nếu tất cả đạt, 1 nếu có test hỏng.

const SEARCH_DIRS: Array[String] = [
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/acceptance",
]


## Bắt lỗi runtime (SCRIPT ERROR, push_error...) để tính vào test đang chạy.
## Không có bước này, một test bị lỗi giữa chừng vẫn có thể "đạt" vì không assert nào hỏng.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if not rationale.is_empty() else code
		_mutex.lock()
		errors.append("lỗi runtime: %s (%s:%d)" % [text, file.get_file(), line])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out


## Thư mục lưu game riêng cho test — test không bao giờ đụng vào file lưu thật của người chơi.
const TEST_SAVE_DIR := "user://test_saves"

var _catcher := ErrorCatcher.new()


func _ready() -> void:
	OS.add_logger(_catcher)
	SaveSystem.save_dir = TEST_SAVE_DIR
	SaveSystem.autosave_enabled = false
	await get_tree().process_frame
	var code := await _run_all(_parse_filter())
	_remove_test_saves()
	OS.remove_logger(_catcher)
	get_tree().quit(code)


func _remove_test_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file))
	DirAccess.remove_absolute(TEST_SAVE_DIR)


func _parse_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.substr("--filter=".length())
	return ""


func _run_all(filter: String) -> int:
	var passed := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for path in _discover():
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed.append("%s: không load được script" % path.get_file())
			print("✗ %s — không load được script" % path.get_file())
			continue
		var methods := _test_methods(script)
		var printed_header := false
		for method in methods:
			var full_name := "%s::%s" % [path.get_file().get_basename(), method]
			if not filter.is_empty() and not full_name.contains(filter):
				continue
			if not printed_header:
				print("● %s" % path.get_file())
				printed_header = true
			var problems: Array[String] = await _run_one(script, method)
			if problems.is_empty():
				passed += 1
				print("  ✓ %s" % method)
			else:
				failed.append(full_name)
				print("  ✗ %s" % method)
				for p in problems:
					print("      - %s" % p)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print("Kết quả: %d đạt, %d hỏng (%.1f giây)" % [passed, failed.size(), seconds])
	for failed_name in failed:
		print("  HỎNG: %s" % failed_name)
	if passed == 0 and failed.is_empty():
		print("Không tìm thấy test nào khớp bộ lọc.")
		return 1
	return 0 if failed.is_empty() else 1


func _run_one(script: GDScript, method: String) -> Array[String]:
	var children_before := get_children()
	_catcher.take()
	var test: TestCase = script.new()
	test.runner = self
	await test.before_each()
	await test.call(method)
	await test.after_each()
	var problems: Array[String] = test.get_failures().duplicate()
	problems.append_array(_catcher.take())
	# Dọn node mà test đã thêm vào cây để test sau bắt đầu sạch sẽ.
	for child in get_children():
		if not children_before.has(child):
			child.queue_free()
	await get_tree().process_frame
	return problems


func _discover() -> Array[String]:
	var found: Array[String] = []
	for dir in SEARCH_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for file: String in files:
			if file.begins_with("test_") and file.ends_with(".gd"):
				found.append(dir.path_join(file))
	return found


func _test_methods(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for info: Dictionary in script.get_script_method_list():
		var method_name: String = info["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names
