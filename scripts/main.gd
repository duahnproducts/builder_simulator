extends Node3D
## Scene gốc của game: dựng thế giới, nhân vật, bộ điều khiển xây dựng và giao diện.
##
## Muốn dùng nhân vật của bạn: chọn node Main → Inspector → Player Scene
## (giao kèo nhân vật: docs/08-nhan-vat.md).

@export var player_scene: PackedScene = preload("res://scenes/player/player_placeholder.tscn")

var world: World
var player: Node3D
var build_controller: BuildController


func _ready() -> void:
	world = World.new()
	add_child(world)
	world.build()
	player = player_scene.instantiate()
	add_child(player)
	player.global_position = world.spawn_point()
	player.rotation.y = world.spawn_yaw()
	build_controller = BuildController.new()
	build_controller.name = "BuildController"
	add_child(build_controller)
	GameState.input_blocked_changed.connect(_update_mouse)
	_update_mouse(GameState.is_input_blocked())


func _update_mouse(blocked: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if blocked else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Bấm chuột vào cửa sổ game thì bắt lại chuột (khi không mở giao diện nào).
	var click := event as InputEventMouseButton
	if click != null and click.pressed and not GameState.is_input_blocked() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
