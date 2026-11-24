extends SceneTree

const WARMUP_FRAMES: int = 5
const MEASURE_FRAMES: int = 30
const FIXED_DELTA: float = 1.0 / 60.0
const REPORT_MD_PATH: String = "res://reports/benchmark_report.md"
const REPORT_JSON_PATH: String = "res://reports/benchmark_results.json"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var churn: Dictionary = _run_churn_benchmark()
	var rows: Array[Dictionary] = _run_arena_scenarios()

	var ver: Dictionary = Engine.get_version_info()
	var meta: Dictionary = {
		"engine_version": "Godot %d.%d.%d" % [int(ver["major"]), int(ver["minor"]), int(ver["patch"])],
		"display_driver": DisplayServer.get_name(),
		"warmup_frames": WARMUP_FRAMES,
		"measure_frames": MEASURE_FRAMES,
		"timestamp": Time.get_datetime_string_from_system(true),
	}

	var json_payload: Dictionary = {
		"meta": meta,
		"churn": churn,
		"scenarios": rows,
	}
	var json_file: FileAccess = FileAccess.open(REPORT_JSON_PATH, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(json_payload, "\t"))
		json_file.close()

	var md_text: String = BenchmarkMetrics.format_markdown_report(meta, churn, rows)
	var md_file: FileAccess = FileAccess.open(REPORT_MD_PATH, FileAccess.WRITE)
	if md_file != null:
		md_file.store_string(md_text)
		md_file.close()

	print("=== CLI BENCHMARK COMPLETE ===")
	print(md_text)
	quit(0)


func _run_churn_benchmark() -> Dictionary:
	var batch_size: int = 1000
	var cycles: int = 5
	var container: Node2D = Node2D.new()
	root.add_child(container)

	var shared_mat: ShaderMaterial = ShaderMaterial.new()
	shared_mat.shader = BenchmarkArena.DISSOLVE_SHADER

	var naive_start_us: int = Time.get_ticks_usec()
	for _c in range(cycles):
		var spawned: Array[StressEntity] = []
		spawned.resize(batch_size)
		for i in range(batch_size):
			var ent: StressEntity = StressEntity.new()
			ent.configure(BenchmarkArena.BAT_TEXTURE, Vector2(100.0, 100.0), Vector2(120.0, 80.0), shared_mat)
			container.add_child(ent)
			spawned[i] = ent
		for i in range(batch_size):
			var ent: StressEntity = spawned[i]
			container.remove_child(ent)
			ent.free()
	var naive_ms: float = float(Time.get_ticks_usec() - naive_start_us) / 1000.0

	var pool: NodePool = NodePool.new()
	pool.setup_factory(_create_stress_entity, container, batch_size)
	var pool_start_us: int = Time.get_ticks_usec()
	for _c in range(cycles):
		var acquired: Array[StressEntity] = []
		acquired.resize(batch_size)
		for i in range(batch_size):
			var ent: StressEntity = pool.acquire() as StressEntity
			ent.configure(BenchmarkArena.BAT_TEXTURE, Vector2(100.0, 100.0), Vector2(120.0, 80.0), shared_mat)
			acquired[i] = ent
		for i in range(batch_size):
			pool.release(acquired[i])
	var pool_ms: float = float(Time.get_ticks_usec() - pool_start_us) / 1000.0
	var reused_total: int = pool.total_reused
	pool.clear_and_free()

	root.remove_child(container)
	container.free()

	var speedup: float = (naive_ms / pool_ms) if pool_ms > 0.0 else 1.0
	return {
		"batch_size": batch_size,
		"cycles": cycles,
		"naive_ms": naive_ms,
		"pool_ms": pool_ms,
		"reused": reused_total,
		"speedup": speedup,
	}


func _create_stress_entity() -> Node:
	return StressEntity.new()


func _run_arena_scenarios() -> Array[Dictionary]:
	var arena: BenchmarkArena = BenchmarkArena.new()
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)

	var rows: Array[Dictionary] = []
	for count_val in [200, 1000, 2000]:
		rows.append(_measure_node_mode(
			arena,
			BenchmarkArena.BenchMode.NAIVE,
			"MODE 1: Naive 노드",
			count_val,
			"개별 ShaderMaterial"
		))
	for count_val in [200, 1000, 2000]:
		rows.append(_measure_node_mode(
			arena,
			BenchmarkArena.BenchMode.POOLED_BATCHED,
			"MODE 2: ObjectPool + 배칭",
			count_val,
			"공유 셰이더 1개"
		))
	for count_val in [200, 1000, 2000]:
		rows.append(_measure_spatial_mode(arena, count_val))
	for count_val in [200, 1000, 2000, 4000, 10000]:
		rows.append(_measure_multimesh_mode(arena, count_val, false))
	for count_val in [200, 1000, 2000, 4000]:
		rows.append(_measure_multimesh_mode(arena, count_val, true))

	arena.set_target_count(0)
	root.remove_child(arena)
	arena.free()
	return rows


func _measure_node_mode(
	arena: BenchmarkArena,
	bench_mode: BenchmarkArena.BenchMode,
	mode_label: String,
	count_val: int,
	note_text: String
) -> Dictionary:
	arena.set_mode(bench_mode)
	arena.set_target_count(count_val)
	var entities: Array[StressEntity] = _collect_visible_entities(arena)
	for _w in range(WARMUP_FRAMES):
		for ent in entities:
			ent._physics_process(FIXED_DELTA)

	var samples: PackedFloat64Array = PackedFloat64Array()
	samples.resize(MEASURE_FRAMES)
	for f in range(MEASURE_FRAMES):
		var t0: int = Time.get_ticks_usec()
		for ent in entities:
			ent._physics_process(FIXED_DELTA)
		samples[f] = float(Time.get_ticks_usec() - t0) / 1000.0

	var summary: Dictionary = BenchmarkMetrics.compute_summary(samples)
	summary["mode"] = mode_label
	summary["count"] = count_val
	summary["node_count"] = entities.size()
	summary["pair_checks"] = -1
	summary["naive_pairs"] = 0
	summary["note"] = note_text
	return summary


func _measure_spatial_mode(arena: BenchmarkArena, count_val: int) -> Dictionary:
	arena.set_mode(BenchmarkArena.BenchMode.SPATIAL_GRID)
	arena.set_target_count(count_val)
	for _w in range(WARMUP_FRAMES):
		arena.step_spatial_simulation(FIXED_DELTA)

	var samples: PackedFloat64Array = PackedFloat64Array()
	samples.resize(MEASURE_FRAMES)
	for f in range(MEASURE_FRAMES):
		var t0: int = Time.get_ticks_usec()
		arena.step_spatial_simulation(FIXED_DELTA)
		samples[f] = float(Time.get_ticks_usec() - t0) / 1000.0

	var summary: Dictionary = BenchmarkMetrics.compute_summary(samples)
	summary["mode"] = "MODE 3: SpatialGrid2D"
	summary["count"] = count_val
	summary["node_count"] = arena.get_active_entity_count()
	summary["pair_checks"] = arena.get_last_pair_checks()
	summary["naive_pairs"] = (count_val * (count_val - 1)) / 2
	summary["note"] = "Area2D 물리 OFF + O(N) 충돌"
	return summary


func _measure_multimesh_mode(
	arena: BenchmarkArena,
	count_val: int,
	enable_collisions: bool
) -> Dictionary:
	arena.set_mode(BenchmarkArena.BenchMode.MULTIMESH_DOD)
	arena.set_soa_collisions(enable_collisions)
	arena.set_target_count(count_val)
	for _w in range(WARMUP_FRAMES):
		arena.step_multimesh_simulation(FIXED_DELTA)

	var samples: PackedFloat64Array = PackedFloat64Array()
	samples.resize(MEASURE_FRAMES)
	for f in range(MEASURE_FRAMES):
		var t0: int = Time.get_ticks_usec()
		arena.step_multimesh_simulation(FIXED_DELTA)
		samples[f] = float(Time.get_ticks_usec() - t0) / 1000.0

	var summary: Dictionary = BenchmarkMetrics.compute_summary(samples)
	var kb: int = (count_val * SwarmMultiMesh2D.STRIDE * 4) / 1024
	if enable_collisions:
		summary["mode"] = "MODE 4B: MultiMesh + SoA 충돌"
		summary["pair_checks"] = arena.get_last_pair_checks()
		summary["naive_pairs"] = (count_val * (count_val - 1)) / 2
		summary["note"] = "1 Draw Call + SoA O(N) 충돌"
	else:
		summary["mode"] = "MODE 4A: MultiMesh + SoA"
		summary["pair_checks"] = -1
		summary["naive_pairs"] = 0
		summary["note"] = "1 Draw Call, 버퍼 %dKB" % kb
	summary["count"] = count_val
	summary["node_count"] = 0
	return summary


func _collect_visible_entities(arena: BenchmarkArena) -> Array[StressEntity]:
	var result: Array[StressEntity] = []
	if arena.entity_layer == null:
		return result
	for child in arena.entity_layer.get_children():
		var ent: StressEntity = child as StressEntity
		if ent != null and ent.visible:
			result.append(ent)
	return result
