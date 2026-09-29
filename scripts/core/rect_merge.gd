class_name RectMerge
extends RefCounted
## Gộp các đoạn thẳng thành hình chữ nhật lớn. Xem docs/02-xay-tuong.md, mục "Gộp va chạm".

const EPS := 0.0001


## Nối các đoạn Vector2(đầu, cuối) — đã sắp theo đầu tăng dần — mà chạm hoặc chồng nhau.
static func join_runs(pieces: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in pieces:
		if not out.is_empty() and p.x <= out[-1].y + EPS:
			out[-1] = Vector2(out[-1].x, maxf(out[-1].y, p.y))
		else:
			out.append(p)
	return out


## Gộp theo chiều dọc. rows: các hàng theo v tăng dần, mỗi hàng là
## {"v0": float, "v1": float, "runs": Array[Vector2]}.
## Đoạn nào trùng khớp (cùng đầu, cùng cuối) với một đoạn ở hàng ngay dưới thì kéo dài
## hình chữ nhật đó lên; ngược lại mở hình chữ nhật mới.
static func merge_rows(rows: Array) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var active: Array = []  # mỗi phần tử: [u0, u1, v0, v1]
	for row: Dictionary in rows:
		var v0: float = row["v0"]
		var v1: float = row["v1"]
		var used: Array[bool] = []
		used.resize(active.size())
		var next_active: Array = []
		for run: Vector2 in row["runs"]:
			var extended := false
			for i in active.size():
				var r: Array = active[i]
				if (not used[i] and absf(r[0] - run.x) < EPS and absf(r[1] - run.y) < EPS
						and absf(r[3] - v0) < EPS):
					r[3] = v1
					used[i] = true
					next_active.append(r)
					extended = true
					break
			if not extended:
				next_active.append([run.x, run.y, v0, v1])
		for i in active.size():
			if not used[i]:
				result.append(_to_rect(active[i]))
		active = next_active
	for r: Array in active:
		result.append(_to_rect(r))
	return result


## Tập ô lưới → các hình chữ nhật (đơn vị ô) phủ kín đúng tập ô đó.
static func cells_to_rects(cells: Array[Vector2i]) -> Array[Rect2]:
	var by_row: Dictionary = {}
	for c in cells:
		if not by_row.has(c.y):
			by_row[c.y] = []
		by_row[c.y].append(c.x)
	var zs: Array = by_row.keys()
	zs.sort()
	var rows := []
	for z: int in zs:
		var xs: Array = by_row[z]
		xs.sort()
		var pieces: Array[Vector2] = []
		for x: int in xs:
			pieces.append(Vector2(x, x + 1))
		rows.append({"v0": float(z), "v1": float(z + 1), "runs": join_runs(pieces)})
	return merge_rows(rows)


static func _to_rect(r: Array) -> Rect2:
	return Rect2(r[0], r[2], r[1] - r[0], r[3] - r[2])
