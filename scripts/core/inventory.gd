class_name Inventory
extends RefCounted
## Kho đồ: mã vật phẩm → số lượng.

signal changed(item_id: String, count: int)

var _counts: Dictionary[String, int] = {}


func count(item_id: String) -> int:
	return _counts.get(item_id, 0)


func has(item_id: String, amount := 1) -> bool:
	return count(item_id) >= amount


func add(item_id: String, amount := 1) -> void:
	if amount <= 0 or item_id.is_empty():
		return
	_counts[item_id] = count(item_id) + amount
	changed.emit(item_id, _counts[item_id])


## Lấy ra đúng số lượng. Không đủ thì không lấy gì và trả về false (tất cả hoặc không gì cả).
func remove(item_id: String, amount := 1) -> bool:
	if amount <= 0:
		return true
	var have := count(item_id)
	if have < amount:
		return false
	if have == amount:
		_counts.erase(item_id)
	else:
		_counts[item_id] = have - amount
	changed.emit(item_id, count(item_id))
	return true


## Còn thiếu bao nhiêu so với nhu cầu {mã: số lượng}.
func missing_for(needs: Dictionary) -> Dictionary:
	var out := {}
	for item_id: String in needs:
		var lack: int = int(needs[item_id]) - count(item_id)
		if lack > 0:
			out[item_id] = lack
	return out


func item_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_counts.keys())
	ids.sort()
	return ids


func clear() -> void:
	_counts.clear()
	changed.emit("", 0)


func to_dict() -> Dictionary:
	var out := {}
	for item_id in _counts:
		out[item_id] = _counts[item_id]
	return out


## Nạp từ dữ liệu lưu; bỏ qua số lượng âm hoặc sai kiểu.
func load_dict(data: Dictionary) -> void:
	_counts.clear()
	for key: Variant in data:
		var amount := DataUtil.to_int(data[key])
		if amount > 0 and key is String and not (key as String).is_empty():
			_counts[key] = amount
	changed.emit("", 0)
