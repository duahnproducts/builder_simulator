class_name DataUtil
extends RefCounted
## Đọc giá trị từ dữ liệu JSON một cách an toàn.
##
## Dữ liệu có thể sai kiểu (lỗi soạn thảo, file lưu bị sửa tay). Thay vì crash,
## các hàm ở đây trả về giá trị mặc định.


static func to_int(value: Variant, default := 0) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value) if is_finite(value) else default
		TYPE_STRING:
			var text: String = value
			return text.to_int() if text.is_valid_int() else default
	return default


static func to_float(value: Variant, default := 0.0) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var f := float(value)
			return f if is_finite(f) else default
		TYPE_STRING:
			var text: String = value
			return text.to_float() if text.is_valid_float() else default
	return default


static func to_bool(value: Variant, default := false) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
	return default


static func to_array(value: Variant) -> Array:
	return value if value is Array else []


static func to_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## Đọc file JSON; trả về null nếu không có file hoặc sai cú pháp.
static func read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data
