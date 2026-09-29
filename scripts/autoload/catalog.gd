extends Node
## Danh mục dữ liệu game, đọc từ data/*.json: vật phẩm, bản vẽ mẫu, lô đất, hợp đồng.
## Autoload tên "Catalog". Xem docs/05-kinh-te-hop-dong.md.

const ITEMS_PATH := "res://data/items.json"
const BLUEPRINTS_PATH := "res://data/blueprints.json"
const PLOTS_PATH := "res://data/plots.json"
const CONTRACTS_PATH := "res://data/contracts.json"
const PAINT_CATEGORY := "son"

var start_money := 100_000_000

var _items: Dictionary = {}
var _item_order: Array[String] = []
var _categories: Array[Dictionary] = []
var _blueprints: Dictionary = {}
var _blueprint_order: Array[String] = []
var _plots: Array[Dictionary] = []
var _contracts: Array[Dictionary] = []
var _reward_cache: Dictionary = {}


func _enter_tree() -> void:
	reload()


func reload() -> void:
	_items.clear()
	_item_order.clear()
	_categories.clear()
	_blueprints.clear()
	_blueprint_order.clear()
	_plots.clear()
	_contracts.clear()
	_reward_cache.clear()
	var items_data := DataUtil.to_dict(DataUtil.read_json_file(ITEMS_PATH))
	for c: Variant in DataUtil.to_array(items_data.get("categories")):
		var cd := DataUtil.to_dict(c)
		if cd.has("id"):
			_categories.append({"id": str(cd["id"]), "name": str(cd.get("name", cd["id"]))})
	for it: Variant in DataUtil.to_array(items_data.get("items")):
		var d := DataUtil.to_dict(it)
		var id := str(d.get("id", ""))
		if not id.is_empty() and not _items.has(id):
			_items[id] = d
			_item_order.append(id)
	var bp_data := DataUtil.to_dict(DataUtil.read_json_file(BLUEPRINTS_PATH))
	for b: Variant in DataUtil.to_array(bp_data.get("blueprints")):
		var d := DataUtil.to_dict(b)
		var id := str(d.get("id", ""))
		if not id.is_empty() and not _blueprints.has(id):
			_blueprints[id] = d
			_blueprint_order.append(id)
	var plot_data := DataUtil.to_dict(DataUtil.read_json_file(PLOTS_PATH))
	for p: Variant in DataUtil.to_array(plot_data.get("plots")):
		var d := DataUtil.to_dict(p)
		if d.has("id"):
			_plots.append(d)
	var contract_data := DataUtil.to_dict(DataUtil.read_json_file(CONTRACTS_PATH))
	start_money = DataUtil.to_int(contract_data.get("start_money"), start_money)
	for c: Variant in DataUtil.to_array(contract_data.get("contracts")):
		var d := DataUtil.to_dict(c)
		if d.has("id"):
			_contracts.append(d)


# ─── Vật phẩm ───────────────────────────────────────────────────────────────

func has_item(id: String) -> bool:
	return _items.has(id)


func item(id: String) -> Dictionary:
	return _items.get(id, {})


func item_ids() -> Array[String]:
	return _item_order.duplicate()


func item_name(id: String) -> String:
	return str(item(id).get("name", id))


func item_unit(id: String) -> String:
	return str(item(id).get("unit", ""))


func item_desc(id: String) -> String:
	return str(item(id).get("desc", ""))


func price(id: String) -> int:
	return DataUtil.to_int(item(id).get("price"), 0)


func item_color(id: String) -> Color:
	return Color.from_string(str(item(id).get("color", "#ffffff")), Color.WHITE)


func category_of(id: String) -> String:
	return str(item(id).get("category", ""))


func categories() -> Array[Dictionary]:
	return _categories.duplicate()


func items_in_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for id in _item_order:
		if category_of(id) == category:
			out.append(id)
	return out


func is_furniture(id: String) -> bool:
	return item(id).has("parts")


func furniture_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _item_order:
		if is_furniture(id):
			out.append(id)
	return out


func paint_ids() -> Array[String]:
	return items_in_category(PAINT_CATEGORY)


func is_paint(id: String) -> bool:
	return category_of(id) == PAINT_CATEGORY


## Kích thước khối bao của món nội thất (rộng, cao, sâu).
func furniture_size(id: String) -> Vector3:
	var s := DataUtil.to_array(item(id).get("size"))
	if s.size() != 3:
		return Vector3.ONE
	return Vector3(DataUtil.to_float(s[0], 1.0), DataUtil.to_float(s[1], 1.0), DataUtil.to_float(s[2], 1.0))


func furniture_parts(id: String) -> Array:
	return DataUtil.to_array(item(id).get("parts"))


## Tổng tiền của một danh sách vật tư {mã: số lượng}.
func cost_of(needs: Dictionary) -> int:
	var total := 0
	for id: String in needs:
		total += price(id) * int(needs[id])
	return total


# ─── Bản vẽ, lô đất, hợp đồng ───────────────────────────────────────────────

func blueprint_ids() -> Array[String]:
	return _blueprint_order.duplicate()


## Bản sao mới của bản vẽ mẫu (sửa thoải mái, không ảnh hưởng dữ liệu gốc); null nếu không có.
func blueprint(id: String) -> Blueprint:
	if not _blueprints.has(id):
		return null
	return Blueprint.from_dict(_blueprints[id])


func blueprint_name(id: String) -> String:
	return str(DataUtil.to_dict(_blueprints.get(id)).get("name", id))


func plots() -> Array[Dictionary]:
	return _plots.duplicate()


func plot(id: String) -> Dictionary:
	for p in _plots:
		if str(p["id"]) == id:
			return p
	return {}


func plot_name(id: String) -> String:
	return str(plot(id).get("name", id))


## Biến đổi từ toạ độ lô đất sang toạ độ thế giới.
static func plot_transform(p: Dictionary) -> Transform3D:
	var pos := DataUtil.to_array(p.get("position"))
	var x := DataUtil.to_float(pos[0]) if pos.size() > 0 else 0.0
	var z := DataUtil.to_float(pos[1]) if pos.size() > 1 else 0.0
	var yaw := deg_to_rad(DataUtil.to_float(p.get("yaw")))
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))


static func plot_size(p: Dictionary) -> Vector2i:
	var s := DataUtil.to_array(p.get("size"))
	if s.size() != 2:
		return Vector2i(14, 14)
	return Vector2i(DataUtil.to_int(s[0], 14), DataUtil.to_int(s[1], 14))


func contracts() -> Array[Dictionary]:
	return _contracts.duplicate()


func contract(id: String) -> Dictionary:
	for c in _contracts:
		if str(c["id"]) == id:
			return c
	return {}


## Nội thất bắt buộc của hợp đồng: {mã: số lượng}.
func contract_furniture(id: String) -> Dictionary:
	var out := {}
	var f := DataUtil.to_dict(contract(id).get("furniture"))
	for key: Variant in f:
		var n := DataUtil.to_int(f[key])
		if n > 0:
			out[str(key)] = n
	return out


## Dự toán tiền vật tư cho cả công trình (kể cả nội thất bắt buộc, sơn trắng).
func contract_cost(id: String) -> int:
	var bp := blueprint(str(contract(id).get("blueprint", "")))
	if bp == null:
		return 0
	var p := ConstructionProject.new(bp, Inventory.new())
	p.required_furniture = contract_furniture(id)
	return cost_of(p.remaining_materials())


## Tiền công = dự toán × margin, làm tròn đến 100.000 đ. Có cache vì tính dự toán khá tốn.
func contract_reward(id: String) -> int:
	if not _reward_cache.has(id):
		var margin := DataUtil.to_float(contract(id).get("margin"), 1.5)
		_reward_cache[id] = int(roundf(contract_cost(id) * margin / 100_000.0)) * 100_000
	return _reward_cache[id]


# ─── Kiểm tra dữ liệu ───────────────────────────────────────────────────────

## Kiểm tra tính nhất quán của toàn bộ dữ liệu. Trả về danh sách lỗi (rỗng = tốt).
func validate_data() -> Array[String]:
	var errors: Array[String] = []
	var category_ids: Array[String] = []
	for c in _categories:
		category_ids.append(str(c["id"]))
	for id in _item_order:
		var d: Dictionary = _items[id]
		if not d.has("name") or not d.has("unit"):
			errors.append("Vật phẩm %s thiếu name/unit." % id)
		if not category_ids.has(category_of(id)):
			errors.append("Vật phẩm %s có nhóm không tồn tại." % id)
		if price(id) <= 0:
			errors.append("Vật phẩm %s có giá không hợp lệ." % id)
		if is_furniture(id):
			var s := furniture_size(id)
			if s.x <= 0.0 or s.y <= 0.0 or s.z <= 0.0 or DataUtil.to_array(item(id).get("size")).size() != 3:
				errors.append("Nội thất %s có size không hợp lệ." % id)
			if furniture_parts(id).is_empty():
				errors.append("Nội thất %s không có parts." % id)
	for id in [ "brick", "cement", "roof_truss", "roof_tile", "ridge_tile", "floor_tile"]:
		if not has_item(id):
			errors.append("Thiếu vật phẩm bắt buộc %s." % id)
	for t: String in BuildConst.OPENING_TYPES:
		if not has_item(BuildConst.OPENING_TYPES[t]["item"]):
			errors.append("Thiếu vật phẩm cho lỗ mở %s." % t)
	for id in _blueprint_order:
		for e in BlueprintValidator.validate(blueprint(id)):
			errors.append("Bản vẽ %s: %s" % [id, e])
	var plot_ids: Array[String] = []
	for p in _plots:
		var pid := str(p["id"])
		if plot_ids.has(pid):
			errors.append("Trùng mã lô đất %s." % pid)
		plot_ids.append(pid)
	var contract_ids: Array[String] = []
	for c in _contracts:
		var cid := str(c["id"])
		if contract_ids.has(cid):
			errors.append("Trùng mã hợp đồng %s." % cid)
		contract_ids.append(cid)
		var bp := blueprint(str(c.get("blueprint", "")))
		if bp == null:
			errors.append("Hợp đồng %s dùng bản vẽ không tồn tại." % cid)
		var p := plot(str(c.get("plot", "")))
		if p.is_empty():
			errors.append("Hợp đồng %s dùng lô đất không tồn tại." % cid)
		elif DataUtil.to_bool(p.get("own")):
			errors.append("Hợp đồng %s không được dùng đất nhà người chơi." % cid)
		elif bp != null and (bp.size.x > plot_size(p).x or bp.size.y > plot_size(p).y):
			errors.append("Bản vẽ của hợp đồng %s lớn hơn lô đất." % cid)
		for f: String in contract_furniture(cid):
			if not is_furniture(f):
				errors.append("Hợp đồng %s yêu cầu nội thất không tồn tại: %s." % [cid, f])
		if DataUtil.to_float(c.get("margin"), 0.0) <= 1.0:
			errors.append("Hợp đồng %s có margin ≤ 1 (lỗ vốn)." % cid)
	return errors
