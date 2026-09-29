class_name DayNight
extends Node
## Chu kỳ ngày đêm. Xem docs/07-the-gioi.md, mục "Ngày và đêm".
## Mặt trời mọc 6h (phía đông), lặn 18h (phía tây); ánh sáng và màu trời nội suy theo độ cao mặt trời.

## Một ngày trong game dài bao nhiêu giây ngoài đời.
const DAY_SECONDS := 1200.0
const DAY_TOP := Color(0.3, 0.5, 0.82)
const DAY_HORIZON := Color(0.72, 0.8, 0.88)
const DUSK_HORIZON := Color(0.95, 0.6, 0.4)
const NIGHT_TOP := Color(0.03, 0.05, 0.12)
const NIGHT_HORIZON := Color(0.12, 0.15, 0.25)

var sun: DirectionalLight3D
var environment: Environment
var sky: ProceduralSkyMaterial
## Vật liệu chóa đèn đường (bật sáng ban đêm).
var lamp_material: StandardMaterial3D
var running := true


func setup(p_sun: DirectionalLight3D, p_env: Environment, p_sky: ProceduralSkyMaterial,
		p_lamp: StandardMaterial3D) -> void:
	sun = p_sun
	environment = p_env
	sky = p_sky
	lamp_material = p_lamp
	apply(GameState.time_of_day)


func _process(delta: float) -> void:
	if running:
		GameState.advance_time(delta * 24.0 / DAY_SECONDS)
	apply(GameState.time_of_day)


## Độ sáng ban ngày 0..1 tại giờ `hour` (0 lúc đêm, 1 lúc trưa).
static func daylight(hour: float) -> float:
	var elevation := sin((hour - 6.0) / 12.0 * PI)
	return clampf(elevation * 1.6, 0.0, 1.0)


func apply(hour: float) -> void:
	var day_t := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var elevation := sin((hour - 6.0) / 12.0 * PI)
	var light := daylight(hour)
	if elevation > 0.0:
		sun.rotation = Vector3(-deg_to_rad(8.0 + 62.0 * elevation), deg_to_rad(lerpf(90.0, -90.0, day_t)), 0.0)
		sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.97, 0.9), light)
		sun.light_energy = lerpf(0.25, 1.0, light)
	else:
		# Ánh trăng: chiếu nghiêng, màu xanh nhạt, đủ sáng để vẫn xây được.
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
		sun.light_color = Color(0.6, 0.7, 1.0)
		sun.light_energy = 0.22
	var horizon_day := DAY_HORIZON.lerp(DUSK_HORIZON, clampf(1.0 - light * 2.5, 0.0, 1.0))
	sky.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, light)
	sky.sky_horizon_color = NIGHT_HORIZON.lerp(horizon_day, clampf(light * 3.0, 0.0, 1.0))
	sky.ground_horizon_color = sky.sky_horizon_color.darkened(0.2)
	environment.ambient_light_energy = lerpf(0.35, 0.85, light)
	environment.fog_light_color = sky.sky_horizon_color
	if lamp_material != null:
		lamp_material.emission_energy_multiplier = 0.0 if light > 0.35 else 3.0
