class_name StageGraph
extends RefCounted
## Đồ thị phụ thuộc có hướng, không chu trình (DAG) giữa các giai đoạn thi công.
## Xem docs/04-thi-cong.md.

var _ids: Array[String] = []
var _requires: Dictionary = {}


func add_stage(id: String, dependencies: Array) -> void:
	if not _ids.has(id):
		_ids.append(id)
	var reqs: Array[String] = []
	for r: Variant in dependencies:
		reqs.append(str(r))
	_requires[id] = reqs


func ids() -> Array[String]:
	return _ids.duplicate()


func requires(id: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_requires.get(id, []))
	return out


## Sắp xếp topo bằng thuật toán Kahn: lặp lại việc lấy ra đỉnh không còn phụ thuộc.
## Trả về mảng rỗng nếu có chu trình hoặc phụ thuộc vào giai đoạn không tồn tại.
func topological_order() -> Array[String]:
	var indegree: Dictionary = {}
	var dependents: Dictionary = {}
	for id in _ids:
		indegree[id] = 0
		dependents[id] = []
	for id in _ids:
		for r: String in _requires[id]:
			if not indegree.has(r):
				return []
			indegree[id] += 1
			dependents[r].append(id)
	var queue: Array[String] = []
	for id in _ids:
		if indegree[id] == 0:
			queue.append(id)
	var order: Array[String] = []
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		order.append(id)
		for dependent: String in dependents[id]:
			indegree[dependent] -= 1
			if indegree[dependent] == 0:
				queue.append(dependent)
	if order.size() != _ids.size():
		return []
	return order


func has_cycle() -> bool:
	return not _ids.is_empty() and topological_order().is_empty()
