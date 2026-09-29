class_name UITheme
extends RefCounted
## Bảng màu và theme giao diện (dựng bằng code). Tông tối, điểm nhấn vàng cam công trường.

const BG := Color(0.08, 0.1, 0.13, 0.92)
const BG_LIGHT := Color(0.16, 0.19, 0.24, 0.95)
const BG_HOVER := Color(0.22, 0.26, 0.33, 0.98)
const ACCENT := Color(0.98, 0.72, 0.25)
const TEXT := Color(0.93, 0.94, 0.95)
const TEXT_DIM := Color(0.64, 0.68, 0.73)
const OK := Color(0.45, 0.85, 0.5)
const WARN := Color(1.0, 0.76, 0.32)
const ERROR := Color(1.0, 0.47, 0.42)
const INFO := Color(0.55, 0.78, 1.0)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _box(BG, 10, 16))
	t.set_stylebox("panel", "Panel", _box(BG, 10, 16))
	t.set_stylebox("normal", "Button", _box(BG_LIGHT, 6, 8))
	t.set_stylebox("hover", "Button", _box(BG_HOVER, 6, 8))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.35), 6, 8))
	t.set_stylebox("disabled", "Button", _box(Color(0.12, 0.13, 0.15, 0.8), 6, 8))
	t.set_stylebox("focus", "Button", _outline(ACCENT))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "TabContainer", _box(BG_LIGHT, 8, 10))
	t.set_stylebox("tab_selected", "TabContainer", _box(ACCENT.darkened(0.45), 6, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(BG_LIGHT, 6, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(BG_HOVER, 6, 10))
	t.set_stylebox("panel", "ItemList", _box(BG_LIGHT, 8, 8))
	t.set_stylebox("selected", "ItemList", _box(ACCENT.darkened(0.45), 4, 4))
	t.set_stylebox("selected_focus", "ItemList", _box(ACCENT.darkened(0.4), 4, 4))
	t.set_stylebox("background", "ProgressBar", _box(Color(0.2, 0.22, 0.26), 4, 0))
	t.set_stylebox("fill", "ProgressBar", _box(OK.darkened(0.2), 4, 0))
	return t


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func _outline(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s


## Neo Control theo preset rồi đặt lề (offset) tính TỪ ĐIỂM NEO.
## Lưu ý: gán `position` cho Control đã neo ở giữa/phải/dưới sẽ đặt nó theo toạ độ tuyệt đối
## (dễ bị đẩy ra ngoài màn hình) — luôn dùng offset như hàm này.
static func anchor(c: Control, preset: Control.LayoutPreset, left: float, top: float, right: float,
		bottom: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


## Label có sẵn cỡ chữ và màu.
static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	return b


## Ô màu nhỏ (ví dụ màu sơn, màu vật tư).
static func swatch(color: Color, size := 22) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r
