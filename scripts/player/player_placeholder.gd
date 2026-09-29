class_name PlayerPlaceholder
extends CharacterBody3D
## NHÂN VẬT TẠM — chỉ để chơi thử các hệ thống xây dựng.
##
## Đây là phần của bạn: hãy thay bằng nhân vật của bạn theo docs/08-nhan-vat.md.
## Giao kèo tối thiểu mà game cần ở nhân vật:
##   1. Nằm trong nhóm "player".
##   2. Có một Camera3D đang active (BuildController bắn tia từ camera này).
##   3. Đứng yên khi GameState.is_input_blocked() là true (đang mở giao diện).
##   4. (Tuỳ chọn) get_save_state() / apply_save_state() để lưu vị trí.

@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025

var camera: Camera3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("player")
	collision_layer = Colliders.PLAYER
	collision_mask = Colliders.WORLD | Colliders.FURNITURE
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.6
	camera.fov = 75.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_input_blocked() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		rotate_y(-motion.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - motion.relative.y * mouse_sensitivity, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Vector2.ZERO
	var speed := walk_speed
	if not GameState.is_input_blocked():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_pressed("sprint"):
			speed = sprint_speed
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


func get_save_state() -> Dictionary:
	return {"pos": [position.x, position.y, position.z], "yaw": rotation.y, "pitch": camera.rotation.x}


func apply_save_state(data: Dictionary) -> void:
	var pos := DataUtil.to_array(data.get("pos"))
	if pos.size() == 3:
		position = Vector3(DataUtil.to_float(pos[0]), DataUtil.to_float(pos[1]), DataUtil.to_float(pos[2]))
	rotation.y = DataUtil.to_float(data.get("yaw"))
	camera.rotation.x = clampf(DataUtil.to_float(data.get("pitch")), -1.45, 1.45)
	velocity = Vector3.ZERO
