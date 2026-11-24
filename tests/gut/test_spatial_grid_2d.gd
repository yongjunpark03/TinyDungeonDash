extends GutTest


func test_spatial_grid_insert_and_radius_query_finds_only_local_candidates() -> void:
	var grid: SpatialGrid2D = SpatialGrid2D.new(64.0)
	grid.insert(0, Vector2(10.0, 10.0))
	grid.insert(1, Vector2(25.0, 20.0))
	grid.insert(2, Vector2(500.0, 500.0))

	assert_eq(grid.get_item_count(), 3)
	assert_eq(grid.get_active_cell_count(), 2)

	var found: Array = grid.query_radius(Vector2(15.0, 15.0), 32.0)
	assert_true(0 in found, "Local item 0 should be returned")
	assert_true(1 in found, "Local item 1 should be returned")
	assert_false(2 in found, "Distant item 2 should be culled by spatial grid")

	grid.clear()
	assert_eq(grid.get_item_count(), 0)
	assert_eq(grid.get_active_cell_count(), 0)

	grid.insert(99, Vector2(12.0, 12.0))
	assert_eq(grid.get_item_count(), 1)
	assert_eq(grid.get_active_cell_count(), 1)
	assert_true(99 in grid.query_radius(Vector2(10.0, 10.0), 16.0))


func test_find_nearest_node2d_matches_brute_force_across_cell_boundaries() -> void:
	var grid: SpatialGrid2D = SpatialGrid2D.new(64.0)
	var nodes: Array[Node2D] = []
	for i in range(38):
		var n: Node2D = Node2D.new()
		add_child_autofree(n)
		n.position = Vector2(float((i * 73) % 580), float((i * 137) % 380))
		nodes.append(n)
		grid.insert(n, n.position)

	var edge_left: Node2D = Node2D.new()
	add_child_autofree(edge_left)
	edge_left.position = Vector2(63.5, 63.5)
	nodes.append(edge_left)
	grid.insert(edge_left, edge_left.position)

	var edge_right: Node2D = Node2D.new()
	add_child_autofree(edge_right)
	edge_right.position = Vector2(64.5, 64.5)
	nodes.append(edge_right)
	grid.insert(edge_right, edge_right.position)

	var queries: Array[Vector2] = [
		Vector2(63.9, 63.9),
		Vector2(64.1, 64.1),
		Vector2(0.0, 0.0),
		Vector2(300.0, 200.0),
		Vector2(575.0, 375.0),
		Vector2(191.9, 128.1),
		Vector2(420.0, 64.0),
		Vector2(128.0, 256.0),
		Vector2(-10.0, 50.0),
		Vector2(512.0, 320.0),
	]
	var max_r: float = 420.0
	for q in queries:
		var best_brute: Node2D = null
		var best_dist_sq: float = max_r * max_r
		for candidate in nodes:
			var d_sq: float = (candidate.global_position - q).length_squared()
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best_brute = candidate
		var grid_best: Node2D = grid.find_nearest_node2d(q, max_r)
		assert_eq(grid_best, best_brute, "Grid nearest should match brute force at %s" % str(q))


func test_spatial_grid_pair_checks_dramatically_below_quadratic() -> void:
	var grid: SpatialGrid2D = SpatialGrid2D.new(48.0)
	var positions: Array[Vector2] = []
	var idx: int = 0
	for row in range(16):
		for col in range(25):
			var px: float = BenchmarkArena.ARENA_BOUNDS.position.x + 20.0 + float(col) * 41.0 + float(idx % 5)
			var py: float = BenchmarkArena.ARENA_BOUNDS.position.y + 18.0 + float(row) * 26.0 + float(idx % 3)
			var pos: Vector2 = Vector2(px, py)
			positions.append(pos)
			grid.insert(idx, pos)
			idx += 1

	var buf: Array = []
	var pair_checks: int = 0
	for i in range(positions.size()):
		grid.query_radius_into(positions[i], 22.0, buf)
		for cand in buf:
			var j: int = int(cand)
			if j > i:
				pair_checks += 1

	assert_lt(pair_checks, 10000, "SpatialGrid2D should slash 79,800 quadratic checks to local neighborhood")


func test_benchmark_arena_spatial_grid_mode_resolves_collisions_and_switches_cleanly() -> void:
	var arena: BenchmarkArena = BenchmarkArena.new()
	add_child_autofree(arena)
	arena.set_mode(BenchmarkArena.BenchMode.SPATIAL_GRID)
	arena.set_target_count(60)
	arena.step_spatial_simulation(0.016)

	assert_eq(arena.get_active_entity_count(), 60)
	assert_gt(arena.get_spatial_cell_count(), 0)
	assert_lt(arena.get_last_pair_checks(), (60 * 59) / 2)

	var layer: Node2D = arena.get_node_or_null("EntityLayer") as Node2D
	assert_not_null(layer)
	for child in layer.get_children():
		var ent: StressEntity = child as StressEntity
		if ent != null and ent.visible:
			assert_false(ent.monitoring, "Physics Area2D monitoring should be off in SPATIAL_GRID mode")

	arena.set_mode(BenchmarkArena.BenchMode.POOLED_BATCHED)
	assert_eq(arena.get_active_entity_count(), 60)
	var active_found: int = 0
	for child in layer.get_children():
		var ent: StressEntity = child as StressEntity
		if ent != null and ent.visible:
			active_found += 1
			assert_true(ent.monitoring, "Physics Area2D monitoring should re-enable in POOLED_BATCHED mode")
	assert_eq(active_found, 60)
