class_name Materials
extends RefCounted
## Vật liệu (material) và màu dùng chung. Mỗi loại chỉ tạo một lần rồi dùng lại.

const HOLOGRAM_COLOR := Color(0.35, 0.8, 1.0, 0.12)
const GHOST_COLOR := Color(0.45, 1.0, 0.55, 0.55)
const GHOST_BAD_COLOR := Color(1.0, 0.35, 0.3, 0.55)

const BRICK := Color(0.72, 0.33, 0.22)
const MORTAR := Color(0.63, 0.61, 0.57)
const CONCRETE := Color(0.63, 0.63, 0.61)
const DIRT := Color(0.42, 0.3, 0.2)
const PLASTER := Color(0.87, 0.85, 0.81)
const ROOF_TILE := Color(0.72, 0.3, 0.18)
const RIDGE_TILE := Color(0.55, 0.22, 0.13)
const WOOD := Color(0.55, 0.38, 0.22)
const DOOR_WOOD := Color(0.45, 0.28, 0.16)
const FRAME := Color(0.33, 0.21, 0.12)
const FLOOR_A := Color(0.88, 0.86, 0.82)
const FLOOR_B := Color(0.8, 0.77, 0.72)

static var _cache: Dictionary = {}


## Lấy màu từ màu đỉnh / màu instance của MultiMesh.
static func vertex_color() -> StandardMaterial3D:
	if not _cache.has("vertex_color"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		_cache["vertex_color"] = m
	return _cache["vertex_color"]


## Hình mờ (hologram): không chịu ánh sáng, trong suốt, màu lấy từ màu đỉnh/instance.
static func hologram() -> StandardMaterial3D:
	if not _cache.has("hologram"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color.WHITE
		_cache["hologram"] = m
	return _cache["hologram"]


## Khối "bóng mờ" cho biết chỗ sắp đặt. bad = vị trí không hợp lệ (màu đỏ).
static func ghost(bad := false) -> StandardMaterial3D:
	var key := "ghost_bad" if bad else "ghost"
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = GHOST_BAD_COLOR if bad else GHOST_COLOR
		m.no_depth_test = false
		_cache[key] = m
	return _cache[key]


static func glass() -> StandardMaterial3D:
	if not _cache.has("glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.62, 0.8, 0.95, 0.35)
		m.roughness = 0.05
		m.metallic_specular = 0.9
		_cache["glass"] = m
	return _cache["glass"]


## Biến đổi màu nhẹ, tất định theo số nguyên seed (cho gạch, ngói trông tự nhiên).
static func jitter(base: Color, seed_value: int, amount := 0.06) -> Color:
	var h := posmod(seed_value * 2654435761, 1000) / 1000.0
	var k := 1.0 + (h - 0.5) * 2.0 * amount
	return Color(base.r * k, base.g * k, base.b * k, base.a)
