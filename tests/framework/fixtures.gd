class_name Fixtures
extends RefCounted
## Bản vẽ mẫu dùng chung cho các bài test.


## Nhà chữ nhật w × d ô, góc (x0, z0). Tường: 0 sau, 1 phải, 2 trước, 3 trái.
## Cửa 0: cửa đi ở tường trước (offset 2,4). Cửa 1: cửa sổ ở tường trái (offset 1,4).
static func rect_house(x0 := 2, z0 := 2, w := 6, d := 4, roof := "gable") -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "test_rect_%dx%d" % [w, d]
	bp.size = Vector2i(x0 * 2 + w, z0 * 2 + d)
	bp.roof = roof
	bp.add_wall(Vector2i(x0, z0), Vector2i(x0 + w, z0))
	bp.add_wall(Vector2i(x0 + w, z0), Vector2i(x0 + w, z0 + d))
	bp.add_wall(Vector2i(x0, z0 + d), Vector2i(x0 + w, z0 + d))
	bp.add_wall(Vector2i(x0, z0), Vector2i(x0, z0 + d))
	bp.add_opening(2, "door", 2.4)
	bp.add_opening(3, "window", 1.4)
	return bp


## Nhà 8 × 5 chia hai phòng bằng tường ngăn x = 6 (tường 4).
## Cửa 0: cửa đi ngoài (vào phòng trái). Cửa 1: cửa sổ. Cửa 2: cửa đi trong nối hai phòng.
static func two_room_house() -> Blueprint:
	var bp := rect_house(2, 2, 8, 5)
	bp.id = "test_two_rooms"
	var inner := bp.add_wall(Vector2i(6, 2), Vector2i(6, 7))
	bp.add_opening(inner, "door", 2.0)
	return bp


## Nhà chữ L mái bằng: hình vuông 6 × 6 khuyết góc sau-phải 3 × 3 (27 ô).
static func l_house() -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "test_l_house"
	bp.size = Vector2i(10, 10)
	bp.roof = "flat"
	bp.add_wall(Vector2i(2, 2), Vector2i(5, 2))
	bp.add_wall(Vector2i(5, 2), Vector2i(5, 5))
	bp.add_wall(Vector2i(5, 5), Vector2i(8, 5))
	bp.add_wall(Vector2i(8, 5), Vector2i(8, 8))
	bp.add_wall(Vector2i(2, 8), Vector2i(8, 8))
	bp.add_wall(Vector2i(2, 2), Vector2i(2, 8))
	bp.add_opening(4, "door", 2.4)
	return bp
