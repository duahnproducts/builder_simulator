extends Node
## Đăng ký phím điều khiển (Input Map) bằng code.
##
## Lý do: file project.godot lưu phím ở dạng rất dài, dễ sai khi sửa tay.
## Action nào đã tồn tại (ví dụ bạn tự đặt trong Project Settings) sẽ được giữ nguyên.

## Phím bàn phím: action -> danh sách physical keycode (không phụ thuộc kiểu bàn phím).
const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"rotate": [KEY_R],
	"cycle_next": [KEY_Q],
	"cycle_prev": [KEY_Z],
	"tool_1": [KEY_1],
	"tool_2": [KEY_2],
	"tool_3": [KEY_3],
	"tool_4": [KEY_4],
	"open_shop": [KEY_B],
	"open_contracts": [KEY_J],
	"open_blueprint": [KEY_P],
	"pause": [KEY_ESCAPE],
	"quicksave": [KEY_F5],
	"quickload": [KEY_F9],
	"toggle_help": [KEY_F1],
}

## Nút chuột: action -> danh sách MouseButton.
const MOUSE_ACTIONS := {
	"primary": [MOUSE_BUTTON_LEFT],
	"secondary": [MOUSE_BUTTON_RIGHT],
	"cycle_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"cycle_prev": [MOUSE_BUTTON_WHEEL_UP],
}


func _enter_tree() -> void:
	register_all()


## Đăng ký tất cả action còn thiếu. Gọi nhiều lần vẫn an toàn (idempotent).
static func register_all() -> void:
	var names: Array = KEY_ACTIONS.keys()
	for action in MOUSE_ACTIONS.keys():
		if not names.has(action):
			names.append(action)
	for action: String in names:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in KEY_ACTIONS.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)
		for button: int in MOUSE_ACTIONS.get(action, []):
			var mev := InputEventMouseButton.new()
			mev.button_index = button as MouseButton
			InputMap.action_add_event(action, mev)
