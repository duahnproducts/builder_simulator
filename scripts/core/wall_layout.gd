class_name WallLayout
extends RefCounted
## Bố cục gạch của một mảng tường trong hệ toạ độ riêng:
## u chạy dọc tường, v đi từ chân tường lên. Xem docs/02-xay-tuong.md.

const EPS := 0.0001

var u_min := 0.0
var u_max := 0.0
var height := 0.0
## > 0 nghĩa là tường hồi hình tam giác, đỉnh cao gable_peak nằm ở giữa.
var gable_peak := 0.0
var openings: Array[Rect2] = []
## Các viên gạch theo thứ tự xây: hàng dưới lên trên, trong mỗi hàng từ trái sang phải.
var slots: Array[Rect2] = []
## Chỉ số viên đầu tiên của mỗi hàng; phần tử cuối cùng = tổng số viên.
var course_first := PackedInt32Array()


func _init(p_u_min := 0.0, p_u_max := 1.0, p_height := BuildConst.DEFAULT_WALL_HEIGHT,
		p_openings: Array[Rect2] = [], p_gable_peak := 0.0) -> void:
	u_min = p_u_min
	u_max = p_u_max
	height = p_height
	openings = p_openings.duplicate()
	gable_peak = p_gable_peak
	_build()


func slot_count() -> int:
	return slots.size()


func course_count() -> int:
	return course_first.size() - 1


func is_gable() -> bool:
	return gable_peak > 0.0


## Khoảng u được phép xây ở độ cao v (tường hồi thu hẹp dần lên đỉnh).
func span_at(v: float) -> Vector2:
	if not is_gable():
		return Vector2(u_min, u_max)
	var half := (u_max - u_min) / 2.0
	var t := clampf(v / gable_peak, 0.0, 1.0)
	return Vector2(u_min + t * half, u_max - t * half)


## Các hình chữ nhật (u, v) bao phần đã xây khi đặt `laid` viên đầu tiên.
## Dùng cho va chạm của tường đang xây.
func built_rects(laid: int) -> Array[Rect2]:
	var count := clampi(laid, 0, slots.size())
	var rows := []
	for c in course_count():
		var first := course_first[c]
		if first >= count:
			break
		var last := mini(course_first[c + 1], count)
		if last <= first:
			continue
		var pieces: Array[Vector2] = []
		for i in range(first, last):
			pieces.append(Vector2(slots[i].position.x, slots[i].end.x))
		rows.append({
			"v0": slots[first].position.y,
			"v1": slots[first].end.y,
			"runs": RectMerge.join_runs(pieces),
		})
	return RectMerge.merge_rows(rows)


## Toàn bộ bề mặt tường khi xây xong (đã trừ lỗ cửa).
func face_rects() -> Array[Rect2]:
	return built_rects(slots.size())


## Diện tích một mặt tường (m²) = tổng diện tích các viên.
func face_area() -> float:
	var area := 0.0
	for s in slots:
		area += s.get_area()
	return area


## Số hàng đã xây trọn vẹn khi đã đặt `laid` viên.
func completed_courses(laid: int) -> int:
	var n := 0
	for c in course_count():
		if course_first[c + 1] > laid:
			break
		n += 1
	return n


func _build() -> void:
	slots.clear()
	course_first = PackedInt32Array()
	var top := gable_peak if is_gable() else height
	var course := 0
	while true:
		var v0 := course * BuildConst.BRICK_HEIGHT
		if v0 >= top - EPS:
			break
		var v1 := minf(v0 + BuildConst.BRICK_HEIGHT, top)
		var span := span_at((v0 + v1) / 2.0)
		if span.y - span.x < BuildConst.MIN_BRICK_PIECE:
			break
		course_first.append(slots.size())
		for piece in _course_pieces(course, span, v0, v1):
			slots.append(Rect2(piece.x, v0, piece.y - piece.x, v1 - v0))
		course += 1
	course_first.append(slots.size())


## Các viên của một hàng: chia theo bước BRICK_LENGTH (hàng lẻ lệch nửa viên — xây so le),
## cắt theo khoảng span, rồi khoét các lỗ cửa cắt ngang hàng.
func _course_pieces(course: int, span: Vector2, v0: float, v1: float) -> Array[Vector2]:
	var brick := BuildConst.BRICK_LENGTH
	var shift := brick / 2.0 if course % 2 == 1 else 0.0
	var pieces: Array[Vector2] = []
	var k := floori((span.x + shift) / brick)
	while true:
		var start := k * brick - shift
		if start >= span.y - EPS:
			break
		var lo := maxf(start, span.x)
		var hi := minf(start + brick, span.y)
		if hi - lo >= BuildConst.MIN_BRICK_PIECE:
			pieces.append(Vector2(lo, hi))
		k += 1
	for o in openings:
		if o.position.y < v1 - EPS and o.end.y > v0 + EPS:
			pieces = _cut(pieces, o.position.x, o.end.x)
	return pieces


## Bỏ phần [c0, c1] khỏi các đoạn; mẩu còn lại quá ngắn thì bỏ luôn.
static func _cut(pieces: Array[Vector2], c0: float, c1: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in pieces:
		if p.y <= c0 + EPS or p.x >= c1 - EPS:
			out.append(p)
			continue
		if c0 - p.x >= BuildConst.MIN_BRICK_PIECE:
			out.append(Vector2(p.x, c0))
		if p.y - c1 >= BuildConst.MIN_BRICK_PIECE:
			out.append(Vector2(c1, p.y))
	return out
