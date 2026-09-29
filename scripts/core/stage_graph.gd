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
## Trong các đỉnh đang sẵn sàng, luôn lấy đỉnh **khai báo sớm nhất** (hàng đợi ưu tiên theo thứ tự
## khai báo), nên thứ tự ra đời tự nhiên: "trát → sơn" đi liền nhau thay vì bị "lát nền" chen giữa.
## Trả về mảng rỗng nếu có chu trình hoặc phụ thuộc vào giai đoạn không tồn tại.
func topological_order() -> Array[String]:
	var index: Dictionary = {}
	for i in _ids.size():
		index[_ids[i]] = i
	var indegree := PackedInt32Array()
	indegree.resize(_ids.size())
	var dependents: Array[PackedInt32Array] = []
	dependents.resize(_ids.size())
	for i in _ids.size():
		for r: String in _requires[_ids[i]]:
			if not index.has(r):
				return []
			indegree[i] += 1
			dependents[index[r]].append(i)
	# `ready` luôn được giữ tăng dần (chèn đúng chỗ bằng tìm kiếm nhị phân), phần tử đầu là nhỏ nhất.
	var ready := PackedInt32Array()
	for i in _ids.size():
		if indegree[i] == 0:
			ready.append(i)
	var order: Array[String] = []
	while not ready.is_empty():
		var i := ready[0]
		ready.remove_at(0)
		order.append(_ids[i])
		for d in dependents[i]:
			indegree[d] -= 1
			if indegree[d] == 0:
				ready.insert(ready.bsearch(d), d)
	if order.size() != _ids.size():
		return []
	return order


func has_cycle() -> bool:
	return not _ids.is_empty() and topological_order().is_empty()
