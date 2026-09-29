extends TestCase
## Lưới an toàn: mọi script trong res://scripts và res://tools phải load và biên dịch được.


func test_moi_script_bien_dich_duoc() -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	_collect("res://tools", files)
	assert_gt(files.size(), 5, "phải tìm thấy script")
	for path in files:
		var script := load(path) as GDScript
		assert_not_null(script, "không load được " + path)
		if script != null:
			assert_true(script.can_instantiate(), "không khởi tạo được " + path)


func _collect(dir: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), out)
