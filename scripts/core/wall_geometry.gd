class_name WallGeometry
extends RefCounted
## Một mảng tường đặt trong toạ độ lô đất: bố cục gạch + vị trí + hướng.
## Xem docs/02-xay-tuong.md.

## Chỉ số tường trong bản vẽ; −1 với tường hồi.
var index := -1
var is_gable := false
var layout: WallLayout
## Vị trí ứng với u = 0, v = 0 (điểm a của tường, ở chân tường).
var origin := Vector3.ZERO
## Hướng u tăng.
var dir := Vector3.RIGHT
## Hướng về phía mặt 1.
var normal := Vector3.BACK
## Kéo dài (+) hoặc thu lại (−) ở đầu a / đầu b để khớp góc.
var ext_a := 0.0
var ext_b := 0.0


## Biến đổi đưa hộp đơn vị thành viên gạch thứ i.
func slot_transform(i: int) -> Transform3D:
	return rect_transform(layout.slots[i], BuildConst.WALL_THICKNESS, 0.0)


## Hộp đơn vị → hộp phủ hình chữ nhật r (u, v), dày `thickness`, lệch `offset` theo pháp tuyến.
func rect_transform(r: Rect2, thickness: float, offset: float) -> Transform3D:
	var center := (origin + dir * (r.position.x + r.size.x / 2.0)
			+ Vector3.UP * (r.position.y + r.size.y / 2.0) + normal * offset)
	return GeomUtil.box_transform(center, dir, Vector3.UP, Vector3(r.size.x, r.size.y, thickness))


## Điểm trong toạ độ lô đất → (u, v) của tường.
func to_uv(p: Vector3) -> Vector2:
	var rel := p - origin
	return Vector2(rel.dot(dir), rel.y)


## Pháp tuyến bề mặt (khi raycast trúng tường) → mặt 0 hoặc 1.
func side_from_normal(n: Vector3) -> int:
	return 1 if n.dot(normal) > 0.0 else 0


## Các mảng trát (u, v). Ở đầu tường bị thu lại, mảng trát được nới ra để che kín góc ngoài.
func plaster_rects() -> Array[Rect2]:
	var extra_a := BuildConst.HALF_WALL if ext_a < 0.0 else 0.0
	var extra_b := BuildConst.HALF_WALL if ext_b < 0.0 else 0.0
	var out: Array[Rect2] = []
	for r in layout.face_rects():
		var u0 := r.position.x
		var u1 := r.end.x
		if absf(u0 - layout.u_min) < 0.001:
			u0 -= extra_a
		if absf(u1 - layout.u_max) < 0.001:
			u1 += extra_b
		out.append(Rect2(u0, r.position.y, u1 - u0, r.size.y))
	return out


## Diện tích một mặt tường cần trát/sơn (m²), đã trừ lỗ cửa.
func side_area() -> float:
	return layout.face_area()


## Dựng hình học cho mọi tường trong bản vẽ, kể cả xử lý mối nối góc.
static func build_for_blueprint(bp: Blueprint) -> Array[WallGeometry]:
	var out: Array[WallGeometry] = []
	for i in bp.wall_count():
		var g := WallGeometry.new()
		g.index = i
		var a := bp.wall_a[i]
		var horizontal := bp.is_horizontal(i)
		g.origin = Vector3(a.x * BuildConst.CELL, BuildConst.FOUNDATION_TOP, a.y * BuildConst.CELL)
		g.dir = Vector3.RIGHT if horizontal else Vector3.BACK
		g.normal = Vector3.BACK if horizontal else Vector3.RIGHT
		g.ext_a = end_extension(bp, i, bp.wall_a[i])
		g.ext_b = end_extension(bp, i, bp.wall_b[i])
		var ops: Array[Rect2] = []
		for k in bp.openings_on_wall(i):
			ops.append(bp.opening_rect(k))
		g.layout = WallLayout.new(-g.ext_a, bp.wall_length(i) + g.ext_b, bp.wall_height, ops)
		out.append(g)
	return out


## Phần kéo dài ở đầu tường i tại điểm p.
## Bảng quy tắc: docs/02-xay-tuong.md, mục "Mối nối góc".
static func end_extension(bp: Blueprint, i: int, p: Vector2i) -> float:
	var ends_h := 0  # số tường ngang có đầu mút tại p (kể cả tường i)
	var ends_v := 0
	for j in bp.wall_count():
		if bp.wall_a[j] == p or bp.wall_b[j] == p:
			if bp.is_horizontal(j):
				ends_h += 1
			else:
				ends_v += 1
		elif _passes_through(bp, j, p):
			return -BuildConst.HALF_WALL  # chữ T: tường i đâm vào hông tường j
	if ends_h + ends_v <= 1:
		return 0.0  # đầu tự do
	if bp.is_horizontal(i):
		if ends_h >= 2:
			return 0.0  # nối thẳng với một tường ngang khác
		return -BuildConst.HALF_WALL if ends_v >= 2 else BuildConst.HALF_WALL
	if ends_h >= 2 or (ends_h == 1 and ends_v < 2):
		return -BuildConst.HALF_WALL  # góc L, hoặc tường ngang chạy thẳng qua p
	return 0.0


static func _passes_through(bp: Blueprint, j: int, p: Vector2i) -> bool:
	var a := bp.wall_a[j]
	var b := bp.wall_b[j]
	if bp.is_horizontal(j):
		return p.y == a.y and a.x < p.x and p.x < b.x
	return p.x == a.x and a.y < p.y and p.y < b.y
