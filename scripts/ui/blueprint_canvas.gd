class_name BlueprintCanvas
extends BlueprintPreview
## Vùng vẽ tương tác của bàn vẽ: kéo để vẽ tường, bấm để đặt cửa hoặc tẩy.
## Canvas KHÔNG biết BlueprintEditor — chỉ phát signal. Nếu hai class tham chiếu kiểu của nhau
## (vòng A → B → A), Godot không giải phóng được script khi thoát (rò bộ nhớ).

## Người dùng kéo xong một đoạn tường (đã bắt lưới và ép ngang/dọc).
signal wall_drawn(a: Vector2i, b: Vector2i)
## Người dùng bấm một điểm (toạ độ lưới) khi công cụ không phải "wall".
signal point_clicked(point: Vector2)

## Công cụ đang chọn: "wall", "door", "window", "erase" (bàn vẽ gán).
var tool := "wall"
var _drag_start := Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if blueprint == null:
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		var g := px_to_grid(click.position)
		if click.pressed:
			if tool == "wall":
				_drag_start = _snap(g)
				preview_wall = [_drag_start, _drag_start]
			else:
				point_clicked.emit(g)
		elif _drag_start.x >= 0:
			wall_drawn.emit(_drag_start, _axis_snap(_drag_start, _snap(g)))
			_drag_start = Vector2i(-1, -1)
			preview_wall = []
			queue_redraw()
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _drag_start.x >= 0:
		preview_wall = [_drag_start, _axis_snap(_drag_start, _snap(px_to_grid(motion.position)))]
		queue_redraw()


func _snap(g: Vector2) -> Vector2i:
	return Vector2i(clampi(roundi(g.x), 0, blueprint.size.x), clampi(roundi(g.y), 0, blueprint.size.y))


## Ép đoạn kéo thành ngang hoặc dọc (theo phương kéo dài hơn).
static func _axis_snap(a: Vector2i, b: Vector2i) -> Vector2i:
	if absi(b.x - a.x) >= absi(b.y - a.y):
		return Vector2i(b.x, a.y)
	return Vector2i(a.x, b.y)
