class_name TestCase
extends RefCounted
## Lớp cơ sở cho mọi bài test.
##
## Mỗi hàm có tên bắt đầu bằng "test_" là một bài test. Runner tạo một instance
## mới cho từng bài test, nên các test không ảnh hưởng lẫn nhau.

## Node gốc của runner — dùng khi test cần scene tree (thêm node, chờ frame).
var runner: Node

var _failures: Array[String] = []


## Chạy trước mỗi bài test. Lớp con có thể override.
func before_each() -> void:
	pass


## Chạy sau mỗi bài test. Lớp con có thể override.
func after_each() -> void:
	pass


func get_failures() -> Array[String]:
	return _failures


func fail(msg: String) -> void:
	_failures.append("%s (%s)" % [msg, _where()])


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		fail(_label("mong đợi true", msg))


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		fail(_label("mong đợi false", msg))


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if not _equal(actual, expected):
		fail(_label("mong đợi <%s> nhưng nhận <%s>" % [str(expected), str(actual)], msg))


func assert_ne(actual: Variant, unexpected: Variant, msg := "") -> void:
	if _equal(actual, unexpected):
		fail(_label("không mong đợi <%s>" % str(actual), msg))


func assert_near(actual: float, expected: float, tolerance := 0.0001, msg := "") -> void:
	if absf(actual - expected) > tolerance:
		fail(_label("mong đợi %f ± %f nhưng nhận %f" % [expected, tolerance, actual], msg))


func assert_vec_near(actual: Variant, expected: Variant, tolerance := 0.0001, msg := "") -> void:
	var diff: float = (actual - expected).length()
	if diff > tolerance:
		fail(_label("mong đợi %s nhưng nhận %s" % [str(expected), str(actual)], msg))


func assert_rect_near(actual: Rect2, expected: Rect2, tolerance := 0.0001, msg := "") -> void:
	var diff := (actual.position - expected.position).length() + (actual.size - expected.size).length()
	if diff > tolerance:
		fail(_label("mong đợi %s nhưng nhận %s" % [str(expected), str(actual)], msg))


func assert_gt(actual: float, bound: float, msg := "") -> void:
	if not actual > bound:
		fail(_label("mong đợi > %s nhưng nhận %s" % [str(bound), str(actual)], msg))


func assert_lt(actual: float, bound: float, msg := "") -> void:
	if not actual < bound:
		fail(_label("mong đợi < %s nhưng nhận %s" % [str(bound), str(actual)], msg))


func assert_has(container: Variant, item: Variant, msg := "") -> void:
	if not container.has(item):
		fail(_label("mong đợi chứa <%s>" % str(item), msg))


func assert_not_null(value: Variant, msg := "") -> void:
	if value == null:
		fail(_label("mong đợi khác null", msg))


## Chờ n frame xử lý (process).
func wait_frames(n := 1) -> void:
	for i in n:
		await runner.get_tree().process_frame


## Chờ n frame vật lý — cần sau khi thêm body để raycast thấy được.
func wait_physics_frames(n := 1) -> void:
	for i in n:
		await runner.get_tree().physics_frame


## Thêm node vào scene tree của runner; runner tự giải phóng sau mỗi test.
func add_to_tree(node: Node) -> Node:
	runner.add_child(node)
	return node


static func _equal(a: Variant, b: Variant) -> bool:
	# So sánh số nguyên với số thực (JSON trả float) theo giá trị.
	# null thuần (Nil) và "Object null" (vd. property kiểu Resource chưa gán) coi như bằng nhau.
	if a == null or b == null:
		return a == null and b == null
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return is_equal_approx(float(a), float(b))
	if ta != tb:
		return false
	return a == b


static func _label(base: String, msg: String) -> String:
	return base if msg.is_empty() else "%s — %s" % [msg, base]


## Tìm dòng trong file test đã gọi assert (bỏ qua các frame của bộ khung test: TestCase, AutoBuilder...).
static func _where() -> String:
	for frame: Dictionary in get_stack():
		var source: String = frame.get("source", "")
		if not source.begins_with("res://tests/framework/"):
			return "%s:%d" % [source.get_file(), frame.get("line", 0)]
	return "?"
