class_name ShopPanel
extends PanelBase
## Cửa hàng vật liệu: mua theo nhóm, bán lại 70%, "Mua đủ cho công trình".
## Xem docs/05-kinh-te-hop-dong.md.

## Hàm () -> String trả về mã lô đất của công trình đang làm (UIRoot gán).
var current_plot: Callable
## Hàm () -> String trả về mã sơn đang chọn (để tính sơn khi "Mua đủ").
var paint_choice: Callable

var _money: Label
var _buy_all_info: Label
var _buy_all_button: Button
var _rows: Dictionary = {}


func _ready() -> void:
	panel_id = "shop"
	name = "ShopPanel"
	var body := build_frame("Cửa hàng vật liệu xây dựng", Vector2(1000, 660))
	_money = UITheme.label("", 22, UITheme.ACCENT)
	body.add_child(_money)
	var buy_all := HBoxContainer.new()
	_buy_all_info = UITheme.label("", 17, UITheme.TEXT_DIM)
	_buy_all_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_all_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy_all.add_child(_buy_all_info)
	_buy_all_button = UITheme.button("Mua đủ cho công trình", buy_all_for_current)
	buy_all.add_child(_buy_all_button)
	body.add_child(buy_all)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for cat in Catalog.categories():
		var scroll := ScrollContainer.new()
		scroll.name = str(cat["name"])
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in Catalog.items_in_category(str(cat["id"])):
			list.add_child(_item_row(id))
		scroll.add_child(list)
		tabs.add_child(scroll)
	body.add_child(tabs)
	GameState.money_changed.connect(_on_state_changed.unbind(1))
	GameState.inventory_changed.connect(_on_state_changed.unbind(2))


func refresh() -> void:
	_money.text = "Tiền: " + Money.format(GameState.wallet.balance)
	for id: String in _rows:
		(_rows[id]["owned"] as Label).text = "Kho: %d" % GameState.inventory.count(id)
	var plot := _plot()
	if plot.is_empty() or GameState.project_at(plot) == null:
		_buy_all_info.text = "Chưa có công trình nào đang làm. Nhận hợp đồng ở bảng hợp đồng (J)."
		_buy_all_button.disabled = true
		return
	var missing := GameState.missing_for_project(plot, _paint())
	if missing.is_empty():
		_buy_all_info.text = "Kho đã đủ vật tư cho %s." % Catalog.plot_name(plot)
		_buy_all_button.disabled = true
	else:
		_buy_all_info.text = "Công trình ở %s còn thiếu %d loại vật tư — tổng %s (sơn: %s)." % [
			Catalog.plot_name(plot), missing.size(), Money.format(Catalog.cost_of(missing)),
			Catalog.item_name(_paint())]
		_buy_all_button.disabled = false


func buy(id: String, amount: int) -> bool:
	if not GameState.buy(id, amount):
		return false
	GameState.notify("Đã mua %d %s %s (%s)." % [amount, Catalog.item_unit(id), Catalog.item_name(id),
			Money.format(Catalog.price(id) * amount)], "ok")
	refresh()
	return true


func sell(id: String, amount: int) -> bool:
	if not GameState.sell(id, amount):
		GameState.notify("Kho không có %s để bán." % Catalog.item_name(id), "warn")
		return false
	GameState.notify("Đã bán %d %s (+%s)." % [amount, Catalog.item_name(id),
			Money.format(GameState.sell_price(id) * amount)], "info")
	refresh()
	return true


## Mua toàn bộ vật tư còn thiếu cho công trình đang làm.
func buy_all_for_current() -> bool:
	var plot := _plot()
	var missing := GameState.missing_for_project(plot, _paint())
	if missing.is_empty() or not GameState.buy_many(missing):
		return false
	GameState.notify("Đã mua đủ vật tư: %s." % Money.format(Catalog.cost_of(missing)), "ok")
	refresh()
	return true


func _plot() -> String:
	return str(current_plot.call()) if current_plot.is_valid() else GameState.HOME_PLOT


func _paint() -> String:
	return str(paint_choice.call()) if paint_choice.is_valid() else "paint_white"


func _on_state_changed() -> void:
	if visible:
		refresh()


func _item_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UITheme.swatch(Catalog.item_color(id)))
	var name_label := UITheme.label(Catalog.item_name(id), 18)
	name_label.custom_minimum_size = Vector2(230, 0)
	name_label.tooltip_text = Catalog.item_desc(id)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)
	var price := UITheme.label("%s / %s" % [Money.format(Catalog.price(id)), Catalog.item_unit(id)], 16,
			UITheme.TEXT_DIM)
	price.custom_minimum_size = Vector2(210, 0)
	row.add_child(price)
	var owned := UITheme.label("", 16)
	owned.custom_minimum_size = Vector2(100, 0)
	row.add_child(owned)
	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 10000
	qty.value = 100 if id == "brick" else (20 if id == "cement" else 1)
	qty.custom_minimum_size = Vector2(120, 0)
	row.add_child(qty)
	row.add_child(UITheme.button("Mua", func() -> void: buy(id, int(qty.value))))
	row.add_child(UITheme.button("Bán 1", func() -> void: sell(id, 1)))
	_rows[id] = {"owned": owned, "qty": qty}
	return row
