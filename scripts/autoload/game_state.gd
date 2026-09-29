extends Node
## Trạng thái của một ván chơi: tiền, kho, uy tín, công trình, hợp đồng, thời gian.
## Autoload tên "GameState". Xem docs/05-kinh-te-hop-dong.md.

signal money_changed(balance: int)
signal inventory_changed(item_id: String, count: int)
signal project_added(plot_id: String)
signal project_removed(plot_id: String)
signal contracts_changed
## kind: "info", "ok", "warn", "error".
signal toast(text: String, kind: String)
signal input_blocked_changed(blocked: bool)
signal game_reset
## Yêu cầu giao diện mở một bảng: "shop", "contracts", "blueprint", "pause".
## Phát từ nơi khác (BuildController, bàn vẽ...), nên bỏ qua cảnh báo "signal không dùng".
@warning_ignore("unused_signal")
signal panel_requested(panel: String)

const SAVE_VERSION := 1
const HOME_PLOT := "HOME"
## Bán lại vật tư được 70% giá mua.
const SELL_RATIO := 0.7

var wallet := Wallet.new()
var inventory := Inventory.new()
var reputation := 0
## plot_id → ConstructionProject
var projects: Dictionary = {}
## contract_id → "active" | "done"
var contract_state: Dictionary = {}
var active_contract := ""
var day := 1
## Giờ trong ngày, 0..24.
var time_of_day := 7.0

var _input_blockers: Dictionary = {}


func _ready() -> void:
	wallet.changed.connect(_on_wallet_changed)
	inventory.changed.connect(_on_inventory_changed)
	new_game()


func new_game() -> void:
	for plot_id: String in projects.keys():
		remove_project(plot_id)
	wallet.balance = Catalog.start_money
	inventory.clear()
	reputation = 0
	contract_state.clear()
	active_contract = ""
	day = 1
	time_of_day = 7.0
	game_reset.emit()
	contracts_changed.emit()


func notify(text: String, kind := "info") -> void:
	toast.emit(text, kind)


# ─── Chặn điều khiển khi mở giao diện ───────────────────────────────────────

## Mỗi bảng giao diện đang mở là một "nguồn chặn"; còn nguồn nào thì nhân vật đứng yên, hiện chuột.
func block_input(source: String, blocked: bool) -> void:
	var before := is_input_blocked()
	if blocked:
		_input_blockers[source] = true
	else:
		_input_blockers.erase(source)
	if before != is_input_blocked():
		input_blocked_changed.emit(is_input_blocked())


func is_input_blocked() -> bool:
	return not _input_blockers.is_empty()


# ─── Mua bán ────────────────────────────────────────────────────────────────

func buy(item_id: String, amount: int) -> bool:
	if amount <= 0 or not Catalog.has_item(item_id):
		return false
	var cost := Catalog.price(item_id) * amount
	if not wallet.spend(cost):
		notify("Không đủ tiền: cần %s." % Money.format(cost), "error")
		return false
	inventory.add(item_id, amount)
	return true


## Mua cả danh sách {mã: số lượng}: đủ tiền cho tất cả thì mua, không thì không mua gì.
func buy_many(needs: Dictionary) -> bool:
	var cost := Catalog.cost_of(needs)
	if needs.is_empty():
		return true
	if not wallet.spend(cost):
		notify("Không đủ tiền: cần %s." % Money.format(cost), "error")
		return false
	for item_id: String in needs:
		inventory.add(item_id, int(needs[item_id]))
	return true


func sell_price(item_id: String) -> int:
	return int(Catalog.price(item_id) * SELL_RATIO)


func sell(item_id: String, amount: int) -> bool:
	if amount <= 0 or not inventory.remove(item_id, amount):
		return false
	wallet.earn(sell_price(item_id) * amount)
	return true


## Vật tư còn thiếu (đã trừ phần có trong kho) để làm xong công trình trên lô đất.
func missing_for_project(plot_id: String, paint_item := "paint_white") -> Dictionary:
	var p := project_at(plot_id)
	if p == null:
		return {}
	return inventory.missing_for(p.remaining_materials(paint_item))


# ─── Công trình ─────────────────────────────────────────────────────────────

func project_at(plot_id: String) -> ConstructionProject:
	return projects.get(plot_id)


func add_project(plot_id: String, project: ConstructionProject) -> void:
	if projects.has(plot_id):
		remove_project(plot_id)
	project.plot_id = plot_id
	project.inventory = inventory
	projects[plot_id] = project
	project_added.emit(plot_id)


func remove_project(plot_id: String) -> void:
	if projects.erase(plot_id):
		project_removed.emit(plot_id)


## Bắt đầu xây nhà theo bản vẽ riêng trên đất nhà mình. Trả về "" nếu thành công, ngược lại là lý do.
func start_home_project(bp: Blueprint) -> String:
	var errors := BlueprintValidator.validate(bp)
	if not errors.is_empty():
		return errors[0]
	var current := project_at(HOME_PLOT)
	if current != null and not current.is_complete() and _has_progress(current):
		return "Đất nhà bạn đang có công trình dở dang — hãy phá bỏ trước."
	var plot_size := Catalog.plot_size(Catalog.plot(HOME_PLOT))
	if bp.size.x > plot_size.x or bp.size.y > plot_size.y:
		return "Bản vẽ lớn hơn lô đất."
	add_project(HOME_PLOT, ConstructionProject.new(bp, inventory, HOME_PLOT))
	notify("Bắt đầu xây nhà của bạn!", "ok")
	return ""


func demolish_home_project() -> void:
	remove_project(HOME_PLOT)


static func _has_progress(p: ConstructionProject) -> bool:
	return p.dig.done_count() > 0 or p.furniture.size() > 0


# ─── Hợp đồng ───────────────────────────────────────────────────────────────

## "locked" (chưa đủ uy tín), "available", "busy" (đang làm hợp đồng khác), "active", "done".
func contract_status(id: String) -> String:
	if contract_state.has(id):
		return contract_state[id]
	var c := Catalog.contract(id)
	if c.is_empty():
		return "locked"
	if reputation < DataUtil.to_int(c.get("min_reputation"), 0):
		return "locked"
	if not active_contract.is_empty():
		return "busy"
	return "available"


## Nhận hợp đồng. Trả về "" nếu thành công, ngược lại là lý do.
func accept_contract(id: String) -> String:
	match contract_status(id):
		"locked":
			return "Chưa đủ uy tín để nhận hợp đồng này."
		"busy":
			return "Bạn đang làm một hợp đồng khác."
		"active", "done":
			return "Hợp đồng này đã nhận rồi."
	var c := Catalog.contract(id)
	var plot_id := str(c.get("plot", ""))
	var bp := Catalog.blueprint(str(c.get("blueprint", "")))
	if bp == null or Catalog.plot(plot_id).is_empty():
		return "Dữ liệu hợp đồng bị lỗi."
	if projects.has(plot_id):
		return "Lô đất đã có công trình."
	var p := ConstructionProject.new(bp, inventory, plot_id)
	p.required_furniture = Catalog.contract_furniture(id)
	add_project(plot_id, p)
	contract_state[id] = "active"
	active_contract = id
	contracts_changed.emit()
	notify("Đã nhận hợp đồng: %s. Công trình ở %s." % [c.get("title", id), Catalog.plot_name(plot_id)], "ok")
	return ""


## Nghiệm thu: công trình phải hoàn thành đủ mọi hạng mục. Trả về "" nếu thành công.
func complete_contract(id: String) -> String:
	if contract_status(id) != "active":
		return "Hợp đồng chưa được nhận."
	var c := Catalog.contract(id)
	var p := project_at(str(c.get("plot", "")))
	if p == null:
		return "Không tìm thấy công trình."
	if not p.is_complete():
		return "Công trình chưa hoàn thành: còn thiếu %s." % _missing_stage_text(p)
	var reward := Catalog.contract_reward(id)
	wallet.earn(reward)
	reputation += DataUtil.to_int(c.get("reputation"), 1)
	contract_state[id] = "done"
	active_contract = ""
	contracts_changed.emit()
	notify("Nghiệm thu đạt! Nhận %s, uy tín +%d." % [Money.format(reward), DataUtil.to_int(c.get("reputation"), 1)], "ok")
	return ""


## Huỷ hợp đồng đang làm: công trình dở dang bị dỡ bỏ, vật tư đã dùng không hoàn lại.
func abandon_contract(id: String) -> String:
	if contract_status(id) != "active":
		return "Hợp đồng không ở trạng thái đang làm."
	remove_project(str(Catalog.contract(id).get("plot", "")))
	contract_state.erase(id)
	active_contract = ""
	reputation = maxi(0, reputation - 1)
	contracts_changed.emit()
	notify("Đã huỷ hợp đồng. Uy tín -1.", "warn")
	return ""


static func _missing_stage_text(p: ConstructionProject) -> String:
	var names: Array[String] = []
	for stage in p.stage_order():
		if p.stage_status(stage) != ConstructionProject.Status.DONE:
			names.append(ConstructionProject.stage_name(stage).to_lower())
	return ", ".join(names)


# ─── Thời gian ──────────────────────────────────────────────────────────────

func advance_time(hours: float) -> void:
	time_of_day += hours
	while time_of_day >= 24.0:
		time_of_day -= 24.0
		day += 1


func clock_text() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "Ngày %d — %02d:%02d" % [day, h, m]


# ─── Lưu / tải ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	var saved_projects := {}
	for plot_id: String in projects:
		saved_projects[plot_id] = (projects[plot_id] as ConstructionProject).to_dict()
	return {
		"version": SAVE_VERSION,
		"money": wallet.balance,
		"inventory": inventory.to_dict(),
		"reputation": reputation,
		"contracts": contract_state.duplicate(),
		"active_contract": active_contract,
		"day": day,
		"time": time_of_day,
		"projects": saved_projects,
	}


## Nạp trạng thái đã lưu. Trả về "" nếu thành công, ngược lại là lý do (khi đó trạng thái không đổi).
func from_dict(data: Dictionary) -> String:
	var version := DataUtil.to_int(data.get("version"), -1)
	if version < 1 or version > SAVE_VERSION:
		return "File lưu không đúng định dạng hoặc từ phiên bản mới hơn (%d)." % version
	for plot_id: String in projects.keys():
		remove_project(plot_id)
	wallet.balance = maxi(0, DataUtil.to_int(data.get("money"), 0))
	inventory.load_dict(DataUtil.to_dict(data.get("inventory")))
	reputation = maxi(0, DataUtil.to_int(data.get("reputation"), 0))
	contract_state.clear()
	var saved_contracts := DataUtil.to_dict(data.get("contracts"))
	for id: Variant in saved_contracts:
		var state := str(saved_contracts[id])
		if not Catalog.contract(str(id)).is_empty() and state in ["active", "done"]:
			contract_state[str(id)] = state
	active_contract = str(data.get("active_contract", ""))
	if contract_state.get(active_contract, "") != "active":
		active_contract = ""
	day = maxi(1, DataUtil.to_int(data.get("day"), 1))
	time_of_day = clampf(DataUtil.to_float(data.get("time"), 7.0), 0.0, 23.99)
	var saved_projects := DataUtil.to_dict(data.get("projects"))
	for plot_id: Variant in saved_projects:
		if Catalog.plot(str(plot_id)).is_empty():
			continue
		var p := ConstructionProject.from_dict(DataUtil.to_dict(saved_projects[plot_id]), inventory)
		add_project(str(plot_id), p)
	contracts_changed.emit()
	return ""


func _on_wallet_changed(balance: int) -> void:
	money_changed.emit(balance)


func _on_inventory_changed(item_id: String, count: int) -> void:
	inventory_changed.emit(item_id, count)
