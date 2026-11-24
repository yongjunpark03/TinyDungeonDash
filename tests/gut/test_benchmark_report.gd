extends GutTest


func test_compute_summary_calculates_average_p95_and_sim_fps() -> void:
	var samples: PackedFloat64Array = PackedFloat64Array()
	for i in range(1, 21):
		samples.append(float(i))

	var summary: Dictionary = BenchmarkMetrics.compute_summary(samples)
	assert_eq(int(summary["frames"]), 20)
	assert_almost_eq(float(summary["avg_ms"]), 10.5, 0.001)
	assert_almost_eq(float(summary["min_ms"]), 1.0, 0.001)
	assert_almost_eq(float(summary["max_ms"]), 20.0, 0.001)
	assert_almost_eq(float(summary["p95_ms"]), 19.0, 0.001)
	assert_almost_eq(float(summary["sim_fps"]), 1000.0 / 10.5, 0.05)


func test_format_markdown_report_contains_churn_and_mode_table() -> void:
	var meta: Dictionary = {
		"engine_version": "Godot 4.7.2",
		"display_driver": "headless",
		"warmup_frames": 5,
		"measure_frames": 30,
		"timestamp": "2026-11-24T11:00:00",
	}
	var churn: Dictionary = {
		"batch_size": 1000,
		"cycles": 5,
		"naive_ms": 20.0,
		"pool_ms": 5.0,
		"reused": 5000,
		"speedup": 4.0,
	}
	var rows: Array[Dictionary] = [
		{
			"mode": "MODE 1: Naive 노드",
			"count": 2000,
			"avg_ms": 6.0,
			"p95_ms": 7.5,
			"sim_fps": 166.0,
			"node_count": 2000,
			"pair_checks": -1,
			"naive_pairs": 0,
			"note": "개별 ShaderMaterial",
		},
		{
			"mode": "MODE 4A: MultiMesh + SoA",
			"count": 2000,
			"avg_ms": 1.2,
			"p95_ms": 1.5,
			"sim_fps": 833.0,
			"node_count": 0,
			"pair_checks": -1,
			"naive_pairs": 0,
			"note": "1 Draw Call, 버퍼 93KB",
		},
	]

	var md: String = BenchmarkMetrics.format_markdown_report(meta, churn, rows)
	assert_true(md.contains("# TinyDungeonDash"))
	assert_true(md.contains("ObjectPool"))
	assert_true(md.contains("MODE 1: Naive 노드"))
	assert_true(md.contains("MODE 4A: MultiMesh + SoA"))
	assert_true(md.contains("1 Draw Call"))
