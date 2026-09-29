class_name Main
extends Node3D
## Scene gốc của game: dựng thế giới, nhân vật, bộ điều khiển xây dựng và giao diện.
##
## Muốn dùng nhân vật của bạn: chọn node Main → Inspector → Player Scene
## (giao kèo nhân vật: docs/08-nhan-vat.md).

@export var player_scene: PackedScene = preload("res://scenes/player/player_placeholder.tscn")

var world: World
var player: Node3D
var build_controller: BuildController
var ui: UIRoot


func _ready() -> void:
	world = World.new()
	add_child(world)
	world.build()
	player = player_scene.instantiate()
	add_child(player)
	_place_player_at_spawn()
	build_controller = BuildController.new()
	build_controller.name = "BuildController"
	add_child(build_controller)
	ui = UIRoot.new()
	add_child(ui)
	ui.setup(build_controller, world)
	ui.help.show_for(20.0)
	GameState.input_blocked_changed.connect(_update_mouse)
	GameState.game_reset.connect(_place_player_at_spawn)
	_update_mouse(GameState.is_input_blocked())
	GameState.notify("Chào mừng! Xem việc ở bảng hợp đồng (J), mua vật liệu ở cửa hàng (B), "
			+ "thiết kế nhà riêng ở bàn vẽ (P).", "info")


func _place_player_at_spawn() -> void:
	player.global_position = world.spawn_point()
	player.rotation.y = world.spawn_yaw()


func _update_mouse(blocked: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if blocked else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Bấm chuột vào cửa sổ game thì bắt lại chuột (khi không mở giao diện nào).
	var click := event as InputEventMouseButton
	if click != null and click.pressed and not GameState.is_input_blocked() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
