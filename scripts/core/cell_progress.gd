class_name CellProgress
extends RefCounted
## Tiến độ trên một tập ô lưới (đào móng, đổ móng, lát nền, đổ mái bằng).
## Xem docs/03-mong-mai-nen.md.
##
## "order" giữ các ô đã làm theo đúng thứ tự người chơi làm; view vẽ bằng MultiMesh
## với visible_instance_count = số ô đã làm.

var cells: Array[Vector2i] = []
var order: Array[Vector2i] = []
var _index: Dictionary = {}
var _done: Dictionary = {}


func _init(p_cells: Array[Vector2i] = []) -> void:
	cells = p_cells.duplicate()
	cells.sort()
	for i in cells.size():
		_index[cells[i]] = i


func total() -> int:
	return cells.size()


func done_count() -> int:
	return order.size()


func remaining() -> int:
	return cells.size() - order.size()


func is_complete() -> bool:
	return order.size() == cells.size()


func progress() -> float:
	return 1.0 if cells.is_empty() else float(order.size()) / cells.size()


func has_cell(c: Vector2i) -> bool:
	return _index.has(c)


func is_done(c: Vector2i) -> bool:
	return _done.has(c)


## Vị trí của ô trong `cells`, hoặc −1.
func index_of(c: Vector2i) -> int:
	return _index.get(c, -1)


## Đánh dấu ô đã làm. Trả về false nếu ô không thuộc tập hoặc đã làm rồi.
func mark(c: Vector2i) -> bool:
	if not _index.has(c) or _done.has(c):
		return false
	_done[c] = order.size()
	order.append(c)
	return true


## Ô đầu tiên chưa làm, hoặc (−1, −1) nếu đã xong hết.
func first_remaining() -> Vector2i:
	for c in cells:
		if not _done.has(c):
			return c
	return Vector2i(-1, -1)


func reset() -> void:
	order.clear()
	_done.clear()


func to_array() -> Array:
	var out := []
	for c in order:
		out.append([c.x, c.y])
	return out


## Nạp lại từ dữ liệu lưu; bỏ qua ô không hợp lệ hoặc trùng lặp.
func load_array(data: Variant) -> void:
	reset()
	for item: Variant in DataUtil.to_array(data):
		var pair := DataUtil.to_array(item)
		if pair.size() == 2:
			mark(Vector2i(DataUtil.to_int(pair[0], -9999), DataUtil.to_int(pair[1], -9999)))
