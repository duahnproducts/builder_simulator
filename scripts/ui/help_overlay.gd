class_name HelpOverlay
extends PanelContainer
## Bảng hướng dẫn phím (F1). Chỉ để xem, không chặn điều khiển. Tự ẩn sau một lúc khi mới vào game.

const KEYS := [
	["W A S D", "Đi lại (Shift chạy, Space nhảy)"],
	["Chuột trái", "Làm việc đang nhắm — giữ để làm liên tục"],
	["1 2 3 4", "Chế độ: Xây dựng · Sơn · Nội thất · Nhặt đồ"],
	["Lăn chuột / Q Z", "Đổi màu sơn / món nội thất"],
	["R", "Xoay nội thất"],
	["E", "Tương tác: cửa, cửa hàng, bảng hợp đồng, bàn vẽ"],
	["B · J · P", "Cửa hàng · Hợp đồng · Bàn vẽ"],
	["Esc", "Đóng bảng / Tạm dừng"],
	["F5 · F9", "Lưu nhanh · Tải nhanh"],
	["F1", "Ẩn / hiện hướng dẫn này"],
]


func _ready() -> void:
	name = "Help"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nằm ngay dưới bảng tiền/uy tín/giờ ở góc trên trái.
	UITheme.anchor(self, Control.PRESET_TOP_LEFT, 16, 160, 16, 160)
	var vb := VBoxContainer.new()
	vb.add_child(UITheme.label("Hướng dẫn (F1)", 20, UITheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	for pair: Array in KEYS:
		grid.add_child(UITheme.label(pair[0], 16, UITheme.ACCENT))
		grid.add_child(UITheme.label(pair[1], 16))
	vb.add_child(grid)
	add_child(vb)


## Hiện một lúc rồi tự ẩn (dùng khi mới vào game).
func show_for(seconds: float) -> void:
	visible = true
	get_tree().create_timer(seconds, true).timeout.connect(func() -> void: visible = false)
