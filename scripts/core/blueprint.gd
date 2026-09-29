class_name Blueprint
extends RefCounted
## Bản vẽ mặt bằng một ngôi nhà. Xem docs/01-ban-ve.md.
##
## - Lưới ô 1 m; điểm lưới (x, z) với 0 ≤ x ≤ size.x, 0 ≤ z ≤ size.y.
## - Tường nối hai điểm lưới a → b, nằm ngang (cùng z) hoặc dọc (cùng x); a luôn đứng trước b.
## - Lỗ mở gắn vào một tường, cách điểm a của tường "offset" mét.

const MAX_SIZE := 64

var id := ""
var name := ""
var size := Vector2i(12, 12)
var roof := "gable"
var wall_height := BuildConst.DEFAULT_WALL_HEIGHT
var wall_a: Array[Vector2i] = []
var wall_b: Array[Vector2i] = []
## Mỗi phần tử: {"wall": int, "type": "door"|"window", "offset": float}
var openings: Array[Dictionary] = []


func wall_count() -> int:
	return wall_a.size()


func add_wall(a: Vector2i, b: Vector2i) -> int:
	if b < a:
		var tmp := a
		a = b
		b = tmp
	wall_a.append(a)
	wall_b.append(b)
	return wall_a.size() - 1


## Xoá tường, kèm các lỗ mở trên tường đó; dời chỉ số tường của các lỗ mở còn lại.
func remove_wall(index: int) -> void:
	if index < 0 or index >= wall_count():
		return
	wall_a.remove_at(index)
	wall_b.remove_at(index)
	var kept: Array[Dictionary] = []
	for o in openings:
		var w: int = o["wall"]
		if w == index:
			continue
		var copy := o.duplicate()
		if w > index:
			copy["wall"] = w - 1
		kept.append(copy)
	openings = kept


func add_opening(wall: int, type: String, offset: float) -> int:
	openings.append({"wall": wall, "type": type, "offset": offset})
	return openings.size() - 1


func remove_opening(index: int) -> void:
	if index >= 0 and index < openings.size():
		openings.remove_at(index)


func is_horizontal(wall: int) -> bool:
	return wall_a[wall].y == wall_b[wall].y


func wall_length(wall: int) -> float:
	var d := wall_b[wall] - wall_a[wall]
	return float(absi(d.x) + absi(d.y)) * BuildConst.CELL


func opening_type(index: int) -> Dictionary:
	return BuildConst.OPENING_TYPES.get(openings[index]["type"], {})


func opening_width(index: int) -> float:
	return float(opening_type(index).get("width", 1.0))


## Hình chữ nhật lỗ mở trong hệ toạ độ tường: u tính từ điểm a, v tính từ chân tường.
func opening_rect(index: int) -> Rect2:
	var t := opening_type(index)
	return Rect2(float(openings[index]["offset"]), float(t.get("sill", 0.0)),
			opening_width(index), float(t.get("height", 2.0)))


func openings_on_wall(wall: int) -> Array[int]:
	var out: Array[int] = []
	for i in openings.size():
		if int(openings[i]["wall"]) == wall:
			out.append(i)
	return out


func duplicate_blueprint() -> Blueprint:
	return Blueprint.from_dict(to_dict())


func to_dict() -> Dictionary:
	var walls := []
	for i in wall_count():
		walls.append([wall_a[i].x, wall_a[i].y, wall_b[i].x, wall_b[i].y])
	var ops := []
	for o in openings:
		ops.append({"wall": o["wall"], "type": o["type"], "offset": o["offset"]})
	return {
		"id": id,
		"name": name,
		"size": [size.x, size.y],
		"roof": roof,
		"wall_height": wall_height,
		"walls": walls,
		"openings": ops,
	}


## Đọc từ Dictionary (thường từ JSON). Giá trị sai kiểu được thay bằng mặc định thay vì làm crash;
## lỗi về ý nghĩa (tường cắt nhau...) do BlueprintValidator phát hiện.
static func from_dict(data: Dictionary) -> Blueprint:
	var bp := Blueprint.new()
	bp.id = str(data.get("id", ""))
	bp.name = str(data.get("name", ""))
	var s := DataUtil.to_array(data.get("size"))
	if s.size() == 2:
		bp.size = Vector2i(clampi(DataUtil.to_int(s[0], 12), 1, MAX_SIZE),
				clampi(DataUtil.to_int(s[1], 12), 1, MAX_SIZE))
	var roof_value := str(data.get("roof", "gable"))
	bp.roof = roof_value if roof_value in ["gable", "flat"] else "gable"
	var height := DataUtil.to_float(data.get("wall_height"), BuildConst.DEFAULT_WALL_HEIGHT)
	bp.wall_height = clampf(snappedf(height, BuildConst.BRICK_HEIGHT), 2.4, 4.0)
	for w: Variant in DataUtil.to_array(data.get("walls")):
		var arr := DataUtil.to_array(w)
		if arr.size() == 4:
			bp.add_wall(Vector2i(DataUtil.to_int(arr[0]), DataUtil.to_int(arr[1])),
					Vector2i(DataUtil.to_int(arr[2]), DataUtil.to_int(arr[3])))
	for o: Variant in DataUtil.to_array(data.get("openings")):
		var od := DataUtil.to_dict(o)
		if od.has("wall") and od.has("type") and od.has("offset"):
			bp.add_opening(DataUtil.to_int(od["wall"], -1), str(od["type"]),
					DataUtil.to_float(od["offset"]))
	return bp
