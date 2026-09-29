class_name BlueprintAnalysis
extends RefCounted
## Phân tích bản vẽ bằng BFS loang (flood fill) trên lưới ô. Xem docs/01-ban-ve.md.
##
## Tường chặn CẠNH giữa hai ô kề nhau. Khoá của một cạnh là Vector3i(x, z, trục):
##   trục 0: cạnh trên đường lưới ngang z, từ điểm (x, z) đến (x + 1, z)
##   trục 1: cạnh trên đường lưới dọc x, từ điểm (x, z) đến (x, z + 1)

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Chỉ số "phòng" dành cho ngoài trời.
const OUTSIDE := -1

var blueprint: Blueprint
## Các ô trong nhà, sắp theo hàng (z) rồi cột (x).
var interior_cells: Array[Vector2i] = []
## Mỗi phòng là một Array[Vector2i].
var rooms: Array = []
## Hình chữ nhật nhỏ nhất bao các ô trong nhà.
var bounds := Rect2i()

var _blocked: Dictionary = {}
var _outside: Dictionary = {}
var _room_of: Dictionary = {}


func _init(bp: Blueprint) -> void:
	blueprint = bp
	for i in bp.wall_count():
		_block_wall(bp.wall_a[i], bp.wall_b[i])
	_flood_outside()
	_collect_rooms()


## Có đi được từ ô c sang ô c + d không (không bị tường chắn)?
func can_move(c: Vector2i, d: Vector2i) -> bool:
	return not _blocked.has(_edge_key(c, d))


## Cạnh giữa ô c và ô c + d có tường không?
func has_wall_edge(c: Vector2i, d: Vector2i) -> bool:
	return _blocked.has(_edge_key(c, d))


func is_interior(c: Vector2i) -> bool:
	return _room_of.has(c)


## Chỉ số phòng chứa ô c, hoặc OUTSIDE.
func room_of(c: Vector2i) -> int:
	return _room_of.get(c, OUTSIDE)


func is_rectangular() -> bool:
	return not interior_cells.is_empty() and interior_cells.size() == bounds.get_area()


## Ô chứa điểm p (toạ độ lô đất, mét).
static func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / BuildConst.CELL), floori(p.z / BuildConst.CELL))


## Tấm sàn của ô c theo mét: Rect2(x, z, rộng, sâu).
## Cạnh nào có tường thì nới thêm nửa bề dày tường để phủ kín chân tường và góc nhà.
func slab_rect(c: Vector2i) -> Rect2:
	var h := BuildConst.HALF_WALL
	var cell := BuildConst.CELL
	var x0 := c.x * cell - (h if has_wall_edge(c, Vector2i(-1, 0)) else 0.0)
	var x1 := (c.x + 1) * cell + (h if has_wall_edge(c, Vector2i(1, 0)) else 0.0)
	var z0 := c.y * cell - (h if has_wall_edge(c, Vector2i(0, -1)) else 0.0)
	var z1 := (c.y + 1) * cell + (h if has_wall_edge(c, Vector2i(0, 1)) else 0.0)
	return Rect2(x0, z0, x1 - x0, z1 - z0)


## Hai ô ở hai bên tường i, tại ô thứ "along" dọc tường: [phía mặt 0, phía mặt 1].
func wall_side_cells(i: int, along: int) -> Array[Vector2i]:
	var a := blueprint.wall_a[i]
	if blueprint.is_horizontal(i):
		return [Vector2i(a.x + along, a.y - 1), Vector2i(a.x + along, a.y)]
	return [Vector2i(a.x - 1, a.y + along), Vector2i(a.x, a.y + along)]


## Mặt side (0/1) của tường i có giáp ô trong nhà không.
func side_is_interior(i: int, side: int) -> bool:
	for k in int(blueprint.wall_length(i)):
		if is_interior(wall_side_cells(i, k)[side]):
			return true
	return false


func wall_touches_interior(i: int) -> bool:
	return side_is_interior(i, 0) or side_is_interior(i, 1)


## Tường ngoài: có ít nhất một mặt nhìn ra ngoài trời.
func is_exterior_wall(i: int) -> bool:
	return not (side_is_interior(i, 0) and side_is_interior(i, 1))


## Hai ô ở hai bên lỗ mở thứ k (tính tại tâm lỗ).
func opening_side_cells(k: int) -> Array[Vector2i]:
	var o: Dictionary = blueprint.openings[k]
	var wall: int = o["wall"]
	var center: float = float(o["offset"]) + blueprint.opening_width(k) / 2.0
	var last := maxi(0, int(blueprint.wall_length(wall)) - 1)
	return wall_side_cells(wall, clampi(floori(center / BuildConst.CELL), 0, last))


## Các phòng KHÔNG đi tới được từ ngoài trời qua cửa đi.
## Đồ thị: đỉnh = phòng và OUTSIDE, cạnh = cửa đi. BFS bắt đầu từ OUTSIDE.
func rooms_without_access() -> Array[int]:
	var adjacency: Dictionary = {}
	for k in blueprint.openings.size():
		var o: Dictionary = blueprint.openings[k]
		var wall: int = o["wall"]
		if o["type"] != "door" or wall < 0 or wall >= blueprint.wall_count():
			continue
		var cells := opening_side_cells(k)
		var r0 := room_of(cells[0])
		var r1 := room_of(cells[1])
		if r0 == r1:
			continue
		if not adjacency.has(r0):
			adjacency[r0] = []
		if not adjacency.has(r1):
			adjacency[r1] = []
		adjacency[r0].append(r1)
		adjacency[r1].append(r0)
	var visited := {OUTSIDE: true}
	var queue: Array[int] = [OUTSIDE]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for next: int in adjacency.get(current, []):
			if not visited.has(next):
				visited[next] = true
				queue.append(next)
	var missing: Array[int] = []
	for r in rooms.size():
		if not visited.has(r):
			missing.append(r)
	return missing


func _block_wall(a: Vector2i, b: Vector2i) -> void:
	if a.y == b.y:
		for x in range(a.x, b.x):
			_blocked[Vector3i(x, a.y, 0)] = true
	elif a.x == b.x:
		for z in range(a.y, b.y):
			_blocked[Vector3i(a.x, z, 1)] = true


static func _edge_key(c: Vector2i, d: Vector2i) -> Vector3i:
	if d.x == 1:
		return Vector3i(c.x + 1, c.y, 1)
	if d.x == -1:
		return Vector3i(c.x, c.y, 1)
	if d.y == 1:
		return Vector3i(c.x, c.y + 1, 0)
	return Vector3i(c.x, c.y, 0)


## BFS từ góc ngoài lô đất (lưới được mở rộng thêm 1 ô viền). Hàng đợi dùng con trỏ head
## thay cho pop_front() (O(n) mỗi lần), nên cả thuật toán là O(số ô).
func _flood_outside() -> void:
	var size := blueprint.size
	var start := Vector2i(-1, -1)
	var queue: Array[Vector2i] = [start]
	_outside[start] = true
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in DIRS:
			var n := c + d
			if n.x < -1 or n.y < -1 or n.x > size.x or n.y > size.y:
				continue
			if _outside.has(n) or not can_move(c, d):
				continue
			_outside[n] = true
			queue.append(n)


func _collect_rooms() -> void:
	for z in blueprint.size.y:
		for x in blueprint.size.x:
			var c := Vector2i(x, z)
			if not _outside.has(c):
				interior_cells.append(c)
	if interior_cells.is_empty():
		return
	var lo := interior_cells[0]
	var hi := interior_cells[0]
	for c in interior_cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	bounds = Rect2i(lo, hi - lo + Vector2i.ONE)
	# Tách phòng: mỗi lần gặp ô chưa thuộc phòng nào thì BFS để lấy cả phòng.
	for c in interior_cells:
		if _room_of.has(c):
			continue
		var index := rooms.size()
		var room: Array[Vector2i] = [c]
		_room_of[c] = index
		var head := 0
		while head < room.size():
			var current := room[head]
			head += 1
			for d in DIRS:
				var n := current + d
				if _room_of.has(n) or _outside.has(n) or not can_move(current, d):
					continue
				_room_of[n] = index
				room.append(n)
		rooms.append(room)
