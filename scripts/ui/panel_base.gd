class_name PanelBase
extends PanelContainer
## Lớp cơ sở cho các bảng giao diện: khung + tiêu đề + nút đóng, mở/đóng có chặn điều khiển nhân vật.
## Lớp con gọi build_frame() trong _ready() và override refresh(). Xem docs/09-giao-dien.md.

signal opened
signal closed

## Tên nguồn chặn điều khiển (GameState.block_input) — mỗi bảng một tên riêng.
var panel_id := "panel"


## Dựng khung: tiêu đề, nút đóng, đường kẻ. Trả về VBox để lớp con thêm nội dung.
func build_frame(title: String, min_size: Vector2) -> VBoxContainer:
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var header := HBoxContainer.new()
	var title_label := UITheme.label(title, 26, UITheme.ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(UITheme.button("×  Đóng (Esc)", close))
	vb.add_child(header)
	vb.add_child(HSeparator.new())
	return vb


func open() -> void:
	visible = true
	GameState.block_input(panel_id, true)
	refresh()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.block_input(panel_id, false)
	closed.emit()


func is_open() -> bool:
	return visible


## Cập nhật nội dung theo trạng thái game (lớp con override).
func refresh() -> void:
	pass
