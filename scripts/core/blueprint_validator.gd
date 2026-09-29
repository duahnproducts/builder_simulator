class_name BlueprintValidator
extends RefCounted
## Kiểm tra bản vẽ có xây được không. Trả về danh sách lỗi; rỗng nghĩa là hợp lệ.
## Bảng quy tắc: docs/01-ban-ve.md.

const EPS := 0.001


static func validate(bp: Blueprint) -> Array[String]:
	var errors: Array[String] = []
	if bp.wall_count() == 0:
		errors.append("Chưa có bức tường nào.")
		return errors
	_check_walls(bp, errors)
	if not errors.is_empty():
		return errors  # tường sai hình học thì các bước sau không còn ý nghĩa
	var analysis := BlueprintAnalysis.new(bp)
	if analysis.interior_cells.is_empty():
		errors.append("Các bức tường chưa khép kín thành phòng nào.")
		return errors
	for i in bp.wall_count():
		if not analysis.wall_touches_interior(i):
			errors.append("Tường %d không bao quanh phòng nào — hãy xoá đi." % (i + 1))
	_check_openings(bp, errors)
	var no_access := analysis.rooms_without_access().size()
	if no_access > 0:
		errors.append("Có %d phòng không có cửa đi vào." % no_access)
	if bp.roof == "gable" and not analysis.is_rectangular():
		errors.append("Mái ngói chỉ làm được cho nhà hình chữ nhật — hãy chọn mái bằng.")
	return errors


static func _check_walls(bp: Blueprint, errors: Array[String]) -> void:
	for i in bp.wall_count():
		var a := bp.wall_a[i]
		var b := bp.wall_b[i]
		var label := "Tường %d" % (i + 1)
		if a == b:
			errors.append(label + " có độ dài bằng 0.")
		elif a.x != b.x and a.y != b.y:
			errors.append(label + " phải nằm ngang hoặc dọc.")
		if not _point_in_plot(a, bp.size) or not _point_in_plot(b, bp.size):
			errors.append(label + " nằm ngoài lô đất.")
	if not errors.is_empty():
		return
	for i in bp.wall_count():
		for j in range(i + 1, bp.wall_count()):
			match _relation(bp, i, j):
				"overlap":
					errors.append("Tường %d chồng lên tường %d." % [i + 1, j + 1])
				"cross":
					errors.append("Tường %d cắt ngang tường %d — hãy chia tường tại chỗ giao nhau." % [i + 1, j + 1])


static func _point_in_plot(p: Vector2i, size: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x <= size.x and p.y <= size.y


## Quan hệ giữa hai tường hợp lệ về hình học:
## "overlap" = cùng phương và chồng lên nhau; "cross" = cắt chéo mà không ai kết thúc tại giao điểm.
## Góc chữ L và chữ T là hợp lệ (trả về "").
static func _relation(bp: Blueprint, i: int, j: int) -> String:
	var ai := bp.wall_a[i]
	var bi := bp.wall_b[i]
	var aj := bp.wall_a[j]
	var bj := bp.wall_b[j]
	var hi := bp.is_horizontal(i)
	var hj := bp.is_horizontal(j)
	if hi == hj:
		if hi and ai.y == aj.y and maxi(ai.x, aj.x) < mini(bi.x, bj.x):
			return "overlap"
		if not hi and ai.x == aj.x and maxi(ai.y, aj.y) < mini(bi.y, bj.y):
			return "overlap"
		return ""
	var h_a := ai if hi else aj
	var h_b := bi if hi else bj
	var v_a := aj if hi else ai
	var v_b := bj if hi else bi
	var p := Vector2i(v_a.x, h_a.y)
	var inside_h := h_a.x < p.x and p.x < h_b.x
	var inside_v := v_a.y < p.y and p.y < v_b.y
	return "cross" if inside_h and inside_v else ""


static func _check_openings(bp: Blueprint, errors: Array[String]) -> void:
	for k in bp.openings.size():
		var o: Dictionary = bp.openings[k]
		var label := "Cửa %d" % (k + 1)
		var wall: int = o["wall"]
		if wall < 0 or wall >= bp.wall_count():
			errors.append(label + " gắn vào tường không tồn tại.")
			continue
		if not BuildConst.OPENING_TYPES.has(o["type"]):
			errors.append(label + " có loại không hợp lệ.")
			continue
		var start: float = o["offset"]
		var end := start + bp.opening_width(k)
		var margin := BuildConst.OPENING_MARGIN
		if start < margin - EPS or end > bp.wall_length(wall) - margin + EPS:
			errors.append(label + " vượt ra ngoài tường %d (phải cách đầu tường ít nhất 0,2 m)." % (wall + 1))
			continue
		for m in k:
			var other: Dictionary = bp.openings[m]
			if int(other["wall"]) != wall or not BuildConst.OPENING_TYPES.has(other["type"]):
				continue
			var other_start: float = other["offset"]
			var other_end := other_start + bp.opening_width(m)
			if start < other_end + margin - EPS and other_start < end + margin - EPS:
				errors.append(label + " quá gần hoặc chồng lên cửa %d." % (m + 1))
		for u in _junction_points(bp, wall):
			if u > start - BuildConst.HALF_WALL - EPS and u < end + BuildConst.HALF_WALL + EPS:
				errors.append(label + " nằm ngay chỗ tường khác nối vào tường %d." % (wall + 1))
				break


## Vị trí u (mét, tính từ điểm a) mà tường khác đâm vào hông tường w (chữ T).
static func _junction_points(bp: Blueprint, w: int) -> Array[float]:
	var out: Array[float] = []
	var a := bp.wall_a[w]
	var b := bp.wall_b[w]
	var horizontal := bp.is_horizontal(w)
	for j in bp.wall_count():
		if j == w:
			continue
		for p: Vector2i in [bp.wall_a[j], bp.wall_b[j]]:
			if horizontal and p.y == a.y and a.x < p.x and p.x < b.x:
				out.append((p.x - a.x) * BuildConst.CELL)
			elif not horizontal and p.x == a.x and a.y < p.y and p.y < b.y:
				out.append((p.y - a.y) * BuildConst.CELL)
	return out
