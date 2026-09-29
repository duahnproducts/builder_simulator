class_name CaptureUtil
extends RefCounted
## Tiện ích dùng chung cho các script chụp ảnh (tools/capture/).


## Tạo thư mục chứa ảnh, kèm file .gdignore để Godot không import ảnh chụp như tài nguyên game.
static func prepare_dir(dir: String) -> void:
	var path := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(path)
	var ignore := path.path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		if f != null:
			f.close()


## Ảnh của viewport hiện tại, dạng RGB8 (bỏ kênh alpha để ghép và nén JPG).
static func grab(viewport: Viewport) -> Image:
	var img := viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Ghép 4 ảnh thành lưới 2 × 2 cùng kích thước ảnh gốc.
static func collage_2x2(tiles: Array[Image]) -> Image:
	var size := tiles[0].get_size()
	var half := Vector2i(floori(size.x / 2.0), floori(size.y / 2.0))
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for i in mini(tiles.size(), 4):
		var tile := tiles[i].duplicate() as Image
		tile.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(tile, Rect2i(Vector2i.ZERO, half), Vector2i((i % 2) * half.x, floori(i / 2.0) * half.y))
	return out
