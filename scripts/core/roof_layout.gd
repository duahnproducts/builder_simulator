class_name RoofLayout
extends RefCounted
## Mái ngói hai mái trên nhà hình chữ nhật. Xem docs/03-mong-mai-nen.md.
##
## Hệ toạ độ mái: r chạy dọc nóc, s chạy ngang nóc, y hướng lên.
## Thứ tự lợp (roof_laid tăng dần): vì kèo → ngói (từng hàng từ mép mái lên nóc,
## mỗi hàng lợp bên 0 rồi bên 1) → ngói nóc.

enum Piece { TRUSS, TILE, RIDGE }

var ridge_along_x := true
## Mặt ngoài tường: Rect2(x, z, rộng, sâu).
var outer := Rect2()
var wall_top := 0.0
var pitch := deg_to_rad(BuildConst.ROOF_PITCH_DEG)
## Chiều cao tường hồi, tính từ đỉnh tường đến đỉnh tam giác.
var rise := 0.0
var r_start := 0.0
var r_len := 0.0
var s_start := 0.0
var s_len := 0.0
## Chiều dài mái dốc từ mép mái lên nóc.
var slope_len := 0.0
var rows := 0
var row_len := 0.0
var segs := 0
var seg_len := 0.0
var truss_positions := PackedFloat32Array()
var gables: Array[WallGeometry] = []


func _init(interior_bounds: Rect2i, p_wall_top: float) -> void:
	wall_top = p_wall_top
	var half := BuildConst.HALF_WALL
	var cell := BuildConst.CELL
	outer = Rect2(interior_bounds.position.x * cell - half, interior_bounds.position.y * cell - half,
			interior_bounds.size.x * cell + 2.0 * half, interior_bounds.size.y * cell + 2.0 * half)
	ridge_along_x = interior_bounds.size.x >= interior_bounds.size.y
	if ridge_along_x:
		r_start = outer.position.x
		r_len = outer.size.x
		s_start = outer.position.y
		s_len = outer.size.y
	else:
		r_start = outer.position.y
		r_len = outer.size.y
		s_start = outer.position.x
		s_len = outer.size.x
	rise = s_len / 2.0 * tan(pitch)
	slope_len = (s_len / 2.0 + BuildConst.ROOF_OVERHANG) / cos(pitch)
	rows = maxi(1, ceili(slope_len / BuildConst.ROOF_TILE_ROW - 0.001))
	row_len = slope_len / rows
	var total := r_len + 2.0 * BuildConst.ROOF_OVERHANG
	segs = maxi(1, ceili(total / BuildConst.ROOF_TILE_SEGMENT - 0.001))
	seg_len = total / segs
	var n := maxi(2, ceili(r_len / BuildConst.TRUSS_SPACING))
	for i in range(1, n):
		truss_positions.append(r_start + r_len * i / n)
	_build_gables(interior_bounds)


func axis_r() -> Vector3:
	return Vector3.RIGHT if ridge_along_x else Vector3.BACK


func axis_s() -> Vector3:
	return Vector3.BACK if ridge_along_x else Vector3.RIGHT


## (r, s, y) → toạ độ lô đất.
func point(r: float, s: float, y: float) -> Vector3:
	return Vector3(r, y, s) if ridge_along_x else Vector3(s, y, r)


func s_center() -> float:
	return s_start + s_len / 2.0


## Độ cao mặt mái cách mặt ngoài tường một khoảng ngang d (d âm: phần mái đua ra ngoài).
func roof_height_at(d: float) -> float:
	return wall_top + BuildConst.ROOF_LIFT + d * tan(pitch)


func ridge_height() -> float:
	return roof_height_at(s_len / 2.0)


## Pháp tuyến hướng ra ngoài của mặt mái bên `side`.
func roof_normal(side: int) -> Vector3:
	var toward_ridge := 1.0 if side == 0 else -1.0
	return (Vector3.UP * cos(pitch) - axis_s() * toward_ridge * sin(pitch)).normalized()


func truss_count() -> int:
	return truss_positions.size()


func tile_count() -> int:
	return 2 * rows * segs


func ridge_count() -> int:
	return segs


func piece_count() -> int:
	return truss_count() + tile_count() + ridge_count()


func piece_kind(i: int) -> Piece:
	if i < truss_count():
		return Piece.TRUSS
	if i < truss_count() + tile_count():
		return Piece.TILE
	return Piece.RIDGE


## Viên ngói thứ k (0 ≤ k < tile_count) → Vector3i(bên, hàng, đoạn).
func tile_coords(k: int) -> Vector3i:
	var per_row := 2 * segs
	@warning_ignore("integer_division")
	var row := k / per_row
	var rem := k % per_row
	@warning_ignore("integer_division")
	var side := rem / segs
	return Vector3i(side, row, rem % segs)


func tile_transform(k: int) -> Transform3D:
	var c := tile_coords(k)
	var side := c.x
	var along := (c.y + 0.5) * row_len  # khoảng cách theo mái dốc, tính từ mép mái
	var d := along * cos(pitch) - BuildConst.ROOF_OVERHANG  # khoảng cách ngang từ mặt ngoài tường
	var s := s_start + d if side == 0 else s_start + s_len - d
	var r := r_start - BuildConst.ROOF_OVERHANG + (c.z + 0.5) * seg_len
	var n := roof_normal(side)
	var center := point(r, s, roof_height_at(d)) + n * (BuildConst.ROOF_TILE_THICKNESS / 2.0)
	return GeomUtil.box_transform(center, axis_r(), n,
			Vector3(seg_len, BuildConst.ROOF_TILE_THICKNESS, row_len))


func ridge_transform(j: int) -> Transform3D:
	var r := r_start - BuildConst.ROOF_OVERHANG + (j + 0.5) * seg_len
	var center := point(r, s_center(), ridge_height() + 0.05)
	var diagonal := (Vector3.UP + axis_s()).normalized()
	return GeomUtil.box_transform(center, axis_r(), diagonal, Vector3(seg_len, 0.22, 0.22))


## Đặt vì kèo thứ i: trục x của vì kèo theo dọc nóc; gốc ở tâm nhà, ngang đỉnh tường.
func truss_transform(i: int) -> Transform3D:
	var origin := point(truss_positions[i], s_center(), wall_top)
	return GeomUtil.box_transform(origin, axis_r(), Vector3.UP, Vector3.ONE)


## Các thanh gỗ của một vì kèo, trong hệ toạ độ riêng của vì kèo
## (x: dọc nóc, y: lên, z: ngang nóc, gốc: tâm nhà ở đỉnh tường).
## Mỗi phần tử: {"from": Vector3, "to": Vector3} — thanh tiết diện vuông nối hai điểm.
func truss_members() -> Array[Dictionary]:
	var half := s_len / 2.0
	var t := 0.1
	var ov := BuildConst.ROOF_OVERHANG
	var members: Array[Dictionary] = []
	var peak := Vector3(0, BuildConst.ROOF_LIFT + half * tan(pitch) - t / 2.0, 0)
	for z_sign: float in [1.0, -1.0]:
		var eave := Vector3(0, BuildConst.ROOF_LIFT - ov * tan(pitch) - t / 2.0, z_sign * (half + ov))
		members.append({"from": eave, "to": peak})  # kèo chính
		var mid := Vector3(0, BuildConst.ROOF_LIFT + half / 2.0 * tan(pitch) - t, z_sign * half / 2.0)
		members.append({"from": Vector3(0, t, 0), "to": mid})  # thanh chống
	members.append({"from": Vector3(0, t / 2.0, -half), "to": Vector3(0, t / 2.0, half)})  # xà ngang
	members.append({"from": Vector3(0, t, 0), "to": peak})  # trụ giữa
	return members


func _build_gables(b: Rect2i) -> void:
	var half := BuildConst.HALF_WALL
	var cell := BuildConst.CELL
	var no_openings: Array[Rect2] = []
	for end in 2:
		var g := WallGeometry.new()
		g.is_gable = true
		g.ext_a = half
		g.ext_b = half
		var length: float
		if ridge_along_x:
			var x := (b.position.x if end == 0 else b.end.x) * cell
			g.origin = Vector3(x, wall_top, b.position.y * cell)
			g.dir = Vector3.BACK
			g.normal = Vector3.RIGHT
			length = b.size.y * cell
		else:
			var z := (b.position.y if end == 0 else b.end.y) * cell
			g.origin = Vector3(b.position.x * cell, wall_top, z)
			g.dir = Vector3.RIGHT
			g.normal = Vector3.BACK
			length = b.size.x * cell
		g.layout = WallLayout.new(-half, length + half, 0.0, no_openings, rise)
		gables.append(g)
