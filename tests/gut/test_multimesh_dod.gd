extends GutTest


func test_swarm_multimesh_buffer_layout_matches_godot_rendering_server() -> void:
	var swarm: SwarmMultiMesh2D = SwarmMultiMesh2D.new()
	add_child_autofree(swarm)
	swarm.setup(BenchmarkArena.BAT_TEXTURE, BenchmarkArena.ARENA_BOUNDS)
	swarm.set_entity_count(10)

	swarm.positions[0] = Vector2(215.5, 142.25)
	swarm.velocities[0] = Vector2(-120.0, 50.0)
	swarm.base_tints[0] = Color(0.25, 0.5, 0.75, 1.0)
	swarm.flash_timers[0] = 0.0
	swarm.sync_multimesh_buffer()

	var buf: PackedFloat32Array = swarm.multimesh.buffer
	assert_eq(swarm.multimesh.instance_count, 10)
	assert_eq(buf.size(), 120)
	assert_almost_eq(buf[0], -1.0, 0.01)
	assert_almost_eq(buf[3], 215.5, 0.01)
	assert_almost_eq(buf[5], -1.0, 0.01)
	assert_almost_eq(buf[7], 142.25, 0.01)
	assert_almost_eq(buf[8], 0.25, 0.01)
	assert_almost_eq(buf[9], 0.5, 0.01)
	assert_almost_eq(buf[10], 0.75, 0.01)
	assert_almost_eq(buf[11], 1.0, 0.01)

	if DisplayServer.get_name() != "headless":
		var xf: Transform2D = swarm.multimesh.get_instance_transform_2d(0)
		var col: Color = swarm.multimesh.get_instance_color(0)
		assert_almost_eq(xf.origin.x, 215.5, 0.01)
		assert_almost_eq(xf.origin.y, 142.25, 0.01)
		assert_almost_eq(xf.x.x, -1.0, 0.01)
		assert_almost_eq(xf.y.y, -1.0, 0.01)
		assert_almost_eq(col.r, 0.25, 0.01)
		assert_almost_eq(col.g, 0.5, 0.01)
		assert_almost_eq(col.b, 0.75, 0.01)


func test_swarm_multimesh_scales_to_10000_with_zero_child_nodes() -> void:
	var swarm: SwarmMultiMesh2D = SwarmMultiMesh2D.new()
	add_child_autofree(swarm)
	swarm.setup(BenchmarkArena.BAT_TEXTURE, BenchmarkArena.ARENA_BOUNDS)
	swarm.set_entity_count(10000)
	swarm.step_simulation(0.016)

	assert_eq(swarm.get_entity_count(), 10000)
	assert_eq(swarm.get_child_count(), 0)
	assert_eq(swarm.multimesh.instance_count, 10000)
	assert_gt(swarm.get_buffer_kilobytes(), 0)

	var safe_rect: Rect2 = swarm.bounds.grow(1.0)
	for idx in [0, 2500, 5000, 9999]:
		assert_true(safe_rect.has_point(swarm.positions[idx]), "Sample %d should stay in bounds" % idx)


func test_multimesh_burst_2d_emits_and_expires_without_spawning_nodes() -> void:
	var burst: MultiMeshBurst2D = MultiMeshBurst2D.new()
	add_child_autofree(burst)
	burst.setup(BenchmarkArena.ORB_TEXTURE)

	burst.emit_burst(Vector2(100.0, 120.0), 6)
	assert_eq(burst.get_active_count(), 6)
	assert_eq(burst.get_child_count(), 0)

	burst.step_particles(0.05)
	assert_eq(burst.get_active_count(), 6)

	burst.step_particles(0.5)
	assert_eq(burst.get_active_count(), 0)


func test_benchmark_arena_multimesh_mode_switches_and_toggles_soa_collisions() -> void:
	var arena: BenchmarkArena = BenchmarkArena.new()
	add_child_autofree(arena)
	arena.set_mode(BenchmarkArena.BenchMode.MULTIMESH_DOD)
	arena.set_target_count(400)
	assert_eq(arena.get_active_entity_count(), 400)

	arena.set_soa_collisions(true)
	arena.step_multimesh_simulation(0.016)
	assert_gt(arena.get_spatial_cell_count(), 0)
	assert_lt(arena.get_last_pair_checks(), (400 * 399) / 2)

	arena.set_mode(BenchmarkArena.BenchMode.NAIVE)
	arena.set_target_count(5)
	assert_eq(arena.get_active_entity_count(), 5)
