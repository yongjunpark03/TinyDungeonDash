class_name SpatialGrid2D
extends RefCounted

const DEFAULT_CELL_SIZE: float = 64.0
const COORD_BIAS: int = 32768
const COORD_SHIFT: int = 16

var cell_size: float = DEFAULT_CELL_SIZE
var last_query_checks: int = 0
var _inv_cell_size: float = 1.0 / DEFAULT_CELL_SIZE
var _cells: Dictionary = {}
var _used_keys: Array[int] = []
var _item_count: int = 0


func _init(p_cell_size: float = DEFAULT_CELL_SIZE) -> void:
	set_cell_size(p_cell_size)


func set_cell_size(new_size: float) -> void:
	cell_size = maxf(8.0, new_size)
	_inv_cell_size = 1.0 / cell_size
	reset_storage()


func clear() -> void:
	for key in _used_keys:
		var bucket: Array = _cells[key] as Array
		bucket.clear()
	_used_keys.clear()
	_item_count = 0
	last_query_checks = 0


func reset_storage() -> void:
	_cells.clear()
	_used_keys.clear()
	_item_count = 0
	last_query_checks = 0


func insert(item: Variant, pos: Vector2) -> void:
	var cx: int = int(floorf(pos.x * _inv_cell_size))
	var cy: int = int(floorf(pos.y * _inv_cell_size))
	var key: int = _pack_key(cx, cy)
	var existing: Variant = _cells.get(key, null)
	var bucket: Array
	if existing == null:
		bucket = []
		_cells[key] = bucket
	else:
		bucket = existing as Array
	if bucket.is_empty():
		_used_keys.append(key)
	bucket.append(item)
	_item_count += 1


func query_radius_into(center: Vector2, radius: float, out_items: Array) -> int:
	out_items.clear()
	var r: float = maxf(0.0, radius)
	var min_cx: int = int(floorf((center.x - r) * _inv_cell_size))
	var max_cx: int = int(floorf((center.x + r) * _inv_cell_size))
	var min_cy: int = int(floorf((center.y - r) * _inv_cell_size))
	var max_cy: int = int(floorf((center.y + r) * _inv_cell_size))
	var checks: int = 0
	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			var bucket: Variant = _cells.get(_pack_key(cx, cy), null)
			if bucket == null:
				continue
			var arr: Array = bucket as Array
			if arr.is_empty():
				continue
			checks += 1
			for item in arr:
				out_items.append(item)
	last_query_checks = checks
	return out_items.size()


func query_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	query_radius_into(center, radius, result)
	return result


func find_nearest_node2d(center: Vector2, max_radius: float, predicate: Callable = Callable()) -> Node2D:
	if _item_count <= 0:
		last_query_checks = 0
		return null
	var r: float = maxf(0.0, max_radius)
	var max_ring: int = int(ceilf(r * _inv_cell_size))
	var cx0: int = int(floorf(center.x * _inv_cell_size))
	var cy0: int = int(floorf(center.y * _inv_cell_size))
	var state: Dictionary = {
		"best_node": null,
		"best_dist_sq": r * r,
		"checks": 0,
	}

	for ring in range(0, max_ring + 1):
		if ring == 0:
			_scan_cell_for_nearest(cx0, cy0, center, predicate, state)
		else:
			for cx in range(cx0 - ring, cx0 + ring + 1):
				_scan_cell_for_nearest(cx, cy0 - ring, center, predicate, state)
				_scan_cell_for_nearest(cx, cy0 + ring, center, predicate, state)
			for cy in range(cy0 - ring + 1, cy0 + ring):
				_scan_cell_for_nearest(cx0 - ring, cy, center, predicate, state)
				_scan_cell_for_nearest(cx0 + ring, cy, center, predicate, state)
		if state["best_node"] != null and ring > 0:
			var min_outer_dist: float = float(ring) * cell_size
			if float(state["best_dist_sq"]) <= min_outer_dist * min_outer_dist:
				break

	last_query_checks = int(state["checks"])
	return state["best_node"] as Node2D


func get_item_count() -> int:
	return _item_count


func get_active_cell_count() -> int:
	return _used_keys.size()


func _scan_cell_for_nearest(
	cx: int,
	cy: int,
	center: Vector2,
	predicate: Callable,
	state: Dictionary
) -> void:
	var bucket: Variant = _cells.get(_pack_key(cx, cy), null)
	if bucket == null:
		return
	var arr: Array = bucket as Array
	if arr.is_empty():
		return
	for item in arr:
		var node: Node2D = item as Node2D
		if node == null or not is_instance_valid(node):
			continue
		state["checks"] = int(state["checks"]) + 1
		if predicate.is_valid() and not bool(predicate.call(node)):
			continue
		var dist_sq: float = (node.global_position - center).length_squared()
		if dist_sq < float(state["best_dist_sq"]):
			state["best_dist_sq"] = dist_sq
			state["best_node"] = node


func _pack_key(cx: int, cy: int) -> int:
	return ((cx + COORD_BIAS) << COORD_SHIFT) | ((cy + COORD_BIAS) & 0xFFFF)
