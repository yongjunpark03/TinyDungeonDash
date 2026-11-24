extends GutTest


func test_perf_overlay_records_rolling_average_and_p95() -> void:
	var overlay: PerfOverlay = PerfOverlay.new()
	add_child_autofree(overlay)
	for _i in range(18):
		overlay.record_frame_ms(10.0)
	for _i in range(2):
		overlay.record_frame_ms(40.0)
	assert_eq(overlay.get_sample_count(), 20)
	assert_almost_eq(overlay.get_average_frame_ms(), 13.0, 0.01)
	assert_almost_eq(overlay.get_p95_frame_ms(), 40.0, 0.01)
	assert_gt(overlay.get_estimated_fps(), 70.0)


func test_benchmark_arena_spawns_and_clears_exact_naive_entities() -> void:
	var arena: BenchmarkArena = BenchmarkArena.new()
	add_child_autofree(arena)
	arena.set_target_count(25)
	assert_eq(arena.get_active_entity_count(), 25)
	arena.set_target_count(10)
	assert_eq(arena.get_active_entity_count(), 10)
	arena.set_target_count(0)
	assert_eq(arena.get_active_entity_count(), 0)


func test_benchmark_scene_loads_cleanly() -> void:
	var packed: PackedScene = load("res://scenes/benchmark.tscn") as PackedScene
	assert_not_null(packed)
	var instance: Node = packed.instantiate()
	assert_not_null(instance)
	instance.free()
