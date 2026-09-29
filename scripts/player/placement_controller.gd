class_name PlacementController
extends Node3D
## Đặt nội thất: bóng mờ đi theo điểm nhìn, bắt lưới 0,1 m, xoay 90° bằng phím R,
## kiểm tra va chạm với tường, cửa và đồ khác. Xem docs/04-thi-cong.md.

const GRID := 0.1
## Đồ thấp hơn mức này (thảm) được đặt chồng dưới đồ khác.
const FLAT_HEIGHT := 0.05

var item_id := ""
var yaw := 0.0
var valid := false
## Lý do không đặt được (hiện trên HUD).
var reason := ""
var house: HouseView
## Vị trí trong toạ độ lô đất của nhà đang nhắm.
var local_pos := Vector3.ZERO

var _ghost: MeshInstance3D


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


func rotate_step() -> void:
	yaw = wrapf(yaw + PI / 2.0, 0.0, TAU)


func hide_ghost() -> void:
	_ghost.visible = false
	valid = false


func ghost_visible() -> bool:
	return _ghost.visible


## Cập nhật theo kết quả raycast thô (`hit`) và mô tả của HouseView (`info`).
func update(hit: Dictionary, info: Dictionary, id: String) -> void:
	item_id = id
	house = null
	valid = false
	reason = ""
	if id.is_empty():
		reason = "Kho chưa có nội thất — mua ở cửa hàng (phím B)."
		hide_ghost()
		return
	if hit.is_empty():
		hide_ghost()
		return
	var world_xform: Transform3D
	if info.get("kind", "") != "slab":
		reason = "Hãy nhắm vào nền nhà."
		world_xform = Transform3D(Basis(Vector3.UP, yaw), hit["position"])
	else:
		house = info["house"]
		var p := house.project
		local_pos = Vector3(snappedf(info["pos"].x, GRID),
				BuildConst.FOUNDATION_TOP + BuildConst.FLOOR_TILE_THICKNESS, snappedf(info["pos"].z, GRID))
		world_xform = house.global_transform * Transform3D(Basis(Vector3.UP, yaw), local_pos)
		if not p.can_furnish():
			reason = "Cần lắp cửa, lợp mái, sơn tường và lát nền xong trước."
		elif not GameState.inventory.has(id):
			reason = "Kho hết %s." % Catalog.item_name(id)
		else:
			var blocker := _blocker(world_xform)
			if blocker == null:
				valid = true
			elif str(blocker.get_meta("kind", "")) == "door_clearance":
				reason = "Chắn lối cửa đi — hãy chừa khoảng trống trước cửa."
			else:
				reason = "Vướng tường, cửa hoặc đồ khác."
	_ghost.mesh = FurnitureView.mesh_for(id)
	_ghost.material_override = Materials.ghost(not valid)
	_ghost.global_transform = world_xform
	_ghost.visible = true


## Đặt món đồ tại vị trí bóng mờ. Trả về ConstructionProject.Result.
func place() -> int:
	if house == null:
		return ConstructionProject.Result.INVALID
	if not valid:
		return ConstructionProject.Result.LOCKED if not house.project.can_furnish() \
				else ConstructionProject.Result.INVALID
	return house.project.place_furniture(item_id, local_pos, yaw)


## Vật cản đầu tiên chồng lên món đồ đặt ở `world_xform`; null nếu chỗ đó trống.
## Đồ phẳng (thảm) chỉ cần tránh tường; đồ khác còn phải tránh đồ đã đặt và khoảng trống trước cửa.
func _blocker(world_xform: Transform3D) -> Object:
	var size := Catalog.furniture_size(item_id)
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(size.x - 0.04, 0.02), maxf(size.y - 0.06, 0.02), maxf(size.z - 0.04, 0.02))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = world_xform * Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0 + 0.03, 0))
	query.collision_mask = Colliders.WORLD if size.y < FLAT_HEIGHT \
			else Colliders.WORLD | Colliders.FURNITURE | Colliders.CLEARANCE
	if house != null:
		query.exclude = [house.slab_body().get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 1)
	return null if hits.is_empty() else hits[0]["collider"]
