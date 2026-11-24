class_name NodePool
extends RefCounted

var total_created: int = 0
var total_reused: int = 0
var peak_active: int = 0
var _scene: PackedScene
var _factory: Callable = Callable()
var _parent: Node
var _available: Array[Node] = []
var _active: Array[Node] = []


func setup(scene_ref: PackedScene, parent_node: Node, prewarm_count: int = 0) -> void:
	_scene = scene_ref
	_factory = Callable()
	_parent = parent_node
	_prewarm(prewarm_count)


func setup_factory(factory_fn: Callable, parent_node: Node, prewarm_count: int = 0) -> void:
	_scene = null
	_factory = factory_fn
	_parent = parent_node
	_prewarm(prewarm_count)


func acquire() -> Node:
	var node: Node = null
	while not _available.is_empty():
		var candidate: Node = _available.pop_back()
		if is_instance_valid(candidate):
			node = candidate
			total_reused += 1
			break
	if node == null:
		node = _create_new_node()
	if node == null:
		return null
	if _parent != null and node.get_parent() == null:
		_parent.add_child(node)
	_set_node_active(node, true)
	_active.append(node)
	peak_active = maxi(peak_active, _active.size())
	return node


func release(node: Node) -> bool:
	var idx: int = _active.find(node)
	if idx == -1:
		return false
	_active.remove_at(idx)
	if is_instance_valid(node):
		_set_node_active(node, false)
		_available.append(node)
	return true


func release_all() -> void:
	while not _active.is_empty():
		var node: Node = _active[_active.size() - 1]
		release(node)


func clear_and_free() -> void:
	for node in _active:
		if is_instance_valid(node):
			_free_node(node)
	for node in _available:
		if is_instance_valid(node):
			_free_node(node)
	_active.clear()
	_available.clear()


func get_active_count() -> int:
	return _active.size()


func get_available_count() -> int:
	return _available.size()


func get_reuse_ratio() -> float:
	var total_acquires: int = total_created + total_reused
	if total_acquires == 0:
		return 0.0
	return float(total_reused) / float(total_acquires)


func _prewarm(count: int) -> void:
	for _i in range(maxi(0, count)):
		var node: Node = _create_new_node()
		if node == null:
			continue
		if _parent != null and node.get_parent() == null:
			_parent.add_child(node)
		_set_node_active(node, false)
		_available.append(node)


func _create_new_node() -> Node:
	var node: Node = null
	if _scene != null:
		node = _scene.instantiate()
	elif _factory.is_valid():
		node = _factory.call() as Node
	if node != null:
		total_created += 1
	return node


func _set_node_active(node: Node, active: bool) -> void:
	node.set_process(active)
	node.set_physics_process(active)
	if node is CanvasItem:
		(node as CanvasItem).visible = active
	if node is Area2D:
		var area: Area2D = node as Area2D
		area.set_deferred("monitoring", active)
		area.set_deferred("monitorable", active)


func _free_node(node: Node) -> void:
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.free()
