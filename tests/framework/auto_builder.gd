class_name AutoBuilder
extends RefCounted
## "Thợ tự động" cho bài test nghiệm thu: chơi như người thật — đặt camera nhắm vào mục tiêu,
## để BuildController tự raycast rồi bấm chuột. KHÔNG gọi thẳng ConstructionProject,
## nên đi qua đủ các lớp: va chạm → HouseView.describe_hit → BuildController → luật thi công → hiển thị.
##
## Dùng camera riêng làm camera đang active: BuildController chỉ cần "có một Camera3D đang active"
## (giao kèo nhân vật, docs/08-nhan-vat.md), nên bài test không phụ thuộc nhân vật cụ thể.
## Mỗi giai đoạn bắt đầu bằng một frame vật lý: thân va chạm mới tạo chỉ được raycast thấy từ frame sau.
##
## Báo lỗi qua Callable `fail` của bài test (Callable không giữ tham chiếu mạnh), tránh vòng
## tham chiếu test ↔ thợ làm rò bộ nhớ.

const R = ConstructionProject.Result
## Khoảng cách từ camera tới bề mặt mục tiêu khi nhắm (trong tầm với BuildController.REACH).
const AIM_DISTANCE := 1.2
## Phím chọn chế độ, theo thứ tự BuildController.Mode.
const MODE_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

var ctrl: BuildController
var cam: Camera3D
## Tổng số lần bấm chuột trái thành công.
var clicks := 0


var _fail: Callable


## `fail`: hàm báo lỗi của bài test (thường là TestCase.fail).
func _init(fail: Callable, p_ctrl: BuildController, p_cam: Camera3D) -> void:
	_fail = fail
	ctrl = p_ctrl
	cam = p_cam


# ─── Nhắm và bấm ────────────────────────────────────────────────────────────

## Đặt camera ở `from`, nhìn vào `at` (toạ độ thế giới) rồi để BuildController quét lại mục tiêu.
func aim(from: Vector3, at: Vector3) -> void:
	var up := Vector3.FORWARD if absf((at - from).normalized().y) > 0.98 else Vector3.UP
	cam.look_at_from_position(from, at, up)
	ctrl.scan()


## Nhìn thẳng xuống tâm ô `cell` của nhà, camera ở độ cao `height` (toạ độ lô đất).
func aim_down_at_cell(house: HouseView, cell: Vector2i, height: float, target_y := 0.0) -> void:
	aim(house.to_global(Vector3(cell.x + 0.5, height, cell.y + 0.5)),
			house.to_global(Vector3(cell.x + 0.5, target_y, cell.y + 0.5)))


## Nhắm vào thân va chạm `body` sao cho mục tiêu BuildController thấy khớp `expect`
## (vd. {"kind": "wall", "index": 2}). Thử từng hộp va chạm (mặt to trước) và cả hai phía của hộp,
## giống người chơi đi vòng tìm chỗ nhìn được. Trả về true nếu nhắm được.
func aim_at_body(body: Node, expect: Dictionary, distance := AIM_DISTANCE) -> bool:
	for cs in _boxes_largest_first(body):
		var size := (cs.shape as BoxShape3D).size
		var axis := _thin_axis(size)
		var xf := cs.global_transform
		var n := xf.basis[axis].normalized()
		for s: float in [1.0, -1.0]:
			aim(xf.origin + n * s * (size[axis] / 2.0 + distance), xf.origin)
			if matches(expect):
				return true
	_fail.call("không nhắm được %s — đang thấy %s" % [str(expect), _describe_current()])
	return false


## Mục tiêu hiện tại có khớp mọi khoá trong `expect` không.
func matches(expect: Dictionary) -> bool:
	for key: String in expect:
		if not ctrl.current.has(key) or ctrl.current[key] != expect[key]:
			return false
	return true


## Bấm chuột trái một lần; thao tác phải đúng `action` và thành công.
func click(action: String) -> bool:
	if ctrl.current_action() != action:
		_fail.call("mong đợi thao tác \"%s\" nhưng là \"%s\" (%s)" % [action, ctrl.current_action(),
				_describe_current()])
		return false
	var result := ctrl.perform_primary()
	if result != R.OK:
		_fail.call("thao tác %s trả về %d — gợi ý: %s" % [action, result, ctrl.hint])
		return false
	clicks += 1
	return true


## Giữ chuột trái (bấm lặp cùng một thao tác) đến khi `done` trả về true. Trả về số lần bấm, −1 nếu hỏng.
func hold(action: String, done: Callable, max_clicks := 5000) -> int:
	var n := 0
	while not done.call():
		if n >= max_clicks:
			_fail.call("bấm %d lần mà chưa xong thao tác %s" % [n, action])
			return -1
		if not click(action):
			return -1
		n += 1
	return n


## Nhấn rồi nhả một phím, đi qua Input Map như bàn phím thật.
func press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func set_mode(mode: BuildController.Mode) -> void:
	press_key(MODE_KEYS[mode])
	_check(ctrl.mode == mode, "phím số không đổi được sang chế độ %d" % mode)


## Lăn chuột (phím Q) đến khi chọn được `item_id` (màu sơn hoặc món nội thất).
func select_item(item_id: String) -> bool:
	for i in 64:
		if ctrl.selected_item() == item_id:
			return true
		press_key(KEY_Q)
	_fail.call("không chọn được %s" % item_id)
	return false


func physics_frame() -> void:
	await ctrl.get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail.call(message)


# ─── Từng giai đoạn thi công ────────────────────────────────────────────────

## Đào rồi đổ móng từng ô: nhìn thẳng xuống ô, bấm một lần để đào, bấm lần nữa để đổ bê tông.
func build_foundation(house: HouseView) -> void:
	await physics_frame()
	var p := house.project
	for c in p.dig.cells:
		aim_down_at_cell(house, c, 1.8)
		_check(ctrl.current.get("cell") == c, "không nhắm trúng ô móng %s" % c)
		click("dig")
		click("pour")
	_check(p.pour.is_complete(), "chưa đổ xong móng")
	await physics_frame()


## Xây gạch từng bức tường cho đến khi đủ viên.
func build_walls(house: HouseView) -> void:
	await physics_frame()
	var p := house.project
	for w in p.walls.size():
		if aim_at_body(house.wall_view(w).target_body(), {"kind": "wall", "index": w}):
			var n := hold("brick", func() -> bool: return p.is_wall_done(w))
			_check(n == p.walls[w].layout.slot_count(), "tường %d: %d lần bấm, mỗi lần phải đúng một viên" % [w, n])
		await physics_frame()


func install_openings(house: HouseView) -> void:
	await physics_frame()
	var p := house.project
	for k in p.openings_done.size():
		if aim_at_body(house.opening_view(k).target_body(), {"kind": "opening", "index": k}):
			click("opening")
	await physics_frame()


## Mái ngói: xây hai tường hồi rồi lợp (vì kèo → ngói → ngói nóc). Mái bằng: đổ bê tông từng ô.
func build_roof(house: HouseView) -> void:
	await physics_frame()
	var p := house.project
	if p.is_flat_roof():
		var top := p.wall_top()
		for c in p.roof_cells.cells:
			aim_down_at_cell(house, c, top + 1.5, top)
			_check(ctrl.current.get("kind") == "roof_slab", "không nhắm trúng mái bằng ở ô %s" % c)
			click("roof_cell")
		await physics_frame()
		return
	for g in p.roof.gables.size():
		if aim_at_body(house.gable_view(g).target_body(), {"kind": "gable", "index": g}):
			hold("gable", func() -> bool: return p.is_gable_done(g))
		await physics_frame()
	if aim_at_body(house.roof_view().target_body(), {"kind": "roof"}, 2.0):
		var n := hold("roof", func() -> bool: return p.is_roof_done())
		_check(n == p.roof.piece_count(), "%d lần bấm, mỗi lần phải lợp đúng một mảnh" % n)
	await physics_frame()


## Trát rồi sơn cả hai mặt mọi bức tường bằng màu `paint_item` (đã chọn sẵn trên BuildController).
func plaster_and_paint(house: HouseView) -> void:
	await physics_frame()
	var p := house.project
	for w in p.walls.size():
		for side in 2:
			if aim_at_body(house.wall_view(w).solid_body(), {"kind": "wall_built", "index": w, "side": side}):
				hold("plaster", func() -> bool: return p.plaster[w][side] >= 1.0)
	set_mode(BuildController.Mode.PAINT)
	for w in p.walls.size():
		for side in 2:
			if aim_at_body(house.wall_view(w).solid_body(), {"kind": "wall_built", "index": w, "side": side}):
				hold("paint", func() -> bool: return p.paint_progress[w][side] >= 1.0)
	set_mode(BuildController.Mode.BUILD)


func tile_floor(house: HouseView) -> void:
	await physics_frame()
	var p := house.project
	for c in p.floor_tiles.cells:
		aim_down_at_cell(house, c, 1.8, BuildConst.FOUNDATION_TOP)
		click("floor")
	await physics_frame()


## Đặt nội thất như người chơi: chọn món, dò các ô trong nhà (xoay 90° nếu cần) đến khi
## bóng mờ báo hợp lệ thì bấm. Trả về số món đặt được.
func furnish(house: HouseView, items: Dictionary) -> int:
	await physics_frame()
	var p := house.project
	set_mode(BuildController.Mode.FURNITURE)
	var placed := 0
	for item_id: String in items:
		for i in int(items[item_id]):
			if not select_item(item_id):
				continue
			if _place_somewhere(house, p):
				placed += 1
			await physics_frame()  # để món vừa đặt chặn chỗ của món sau
	set_mode(BuildController.Mode.BUILD)
	return placed


func _place_somewhere(house: HouseView, p: ConstructionProject) -> bool:
	for c in p.analysis.interior_cells:
		for turn in 2:
			aim_down_at_cell(house, c, 2.4, BuildConst.FOUNDATION_TOP)
			if ctrl.placement.valid:
				return click("furniture")
			press_key(KEY_R)
	_fail.call("không tìm được chỗ đặt %s — %s" % [ctrl.furniture_item, ctrl.placement.reason])
	return false


# ─── Nội bộ ─────────────────────────────────────────────────────────────────

func _boxes_largest_first(body: Node) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			out.append(cs)
	out.sort_custom(_larger_face)
	return out


static func _larger_face(a: CollisionShape3D, b: CollisionShape3D) -> bool:
	return _face_area((a.shape as BoxShape3D).size) > _face_area((b.shape as BoxShape3D).size)


## Diện tích mặt lớn nhất của hộp = tích hai cạnh dài nhất.
static func _face_area(size: Vector3) -> float:
	return size.x * size.y * size.z / maxf(size[_thin_axis(size)], 0.0001)


## Trục mỏng nhất của hộp (pháp tuyến của mặt lớn nhất).
static func _thin_axis(size: Vector3) -> int:
	if size.x <= size.y and size.x <= size.z:
		return 0
	return 1 if size.y <= size.z else 2


func _describe_current() -> String:
	var info := ctrl.current.duplicate()
	info.erase("house")
	return str(info)
