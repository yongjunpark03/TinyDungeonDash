class_name BenchmarkMetrics
extends RefCounted


static func compute_summary(samples_ms: PackedFloat64Array) -> Dictionary:
	var n: int = samples_ms.size()
	if n == 0:
		return {
			"frames": 0,
			"avg_ms": 0.0,
			"min_ms": 0.0,
			"max_ms": 0.0,
			"p95_ms": 0.0,
			"sim_fps": 0.0,
		}

	var sorted: Array[float] = []
	sorted.resize(n)
	var sum_ms: float = 0.0
	var min_val: float = samples_ms[0]
	var max_val: float = samples_ms[0]
	for i in range(n):
		var v: float = samples_ms[i]
		sorted[i] = v
		sum_ms += v
		if v < min_val:
			min_val = v
		if v > max_val:
			max_val = v

	sorted.sort()
	var p95_idx: int = clampi(int(ceilf(float(n) * 0.95)) - 1, 0, n - 1)
	var avg_val: float = sum_ms / float(n)
	var fps_val: float = (1000.0 / avg_val) if avg_val > 0.0 else 0.0
	return {
		"frames": n,
		"avg_ms": avg_val,
		"min_ms": min_val,
		"max_ms": max_val,
		"p95_ms": sorted[p95_idx],
		"sim_fps": fps_val,
	}


static func format_markdown_report(
	meta: Dictionary,
	churn: Dictionary,
	rows: Array[Dictionary]
) -> String:
	var lines: Array[String] = []
	lines.append("# TinyDungeonDash — Godot 4.7 엔진 한계 테스트 & 최적화 벤치마크 리포트")
	lines.append("")
	lines.append("- **엔진 버전**: %s" % str(meta.get("engine_version", "Godot 4.7")))
	lines.append("- **실행 모드**: %s" % str(meta.get("display_driver", "headless")))
	lines.append("- **워밍업 / 측정 프레임**: %d / %d frames" % [
		int(meta.get("warmup_frames", 5)),
		int(meta.get("measure_frames", 30)),
	])
	lines.append("- **생성 시각 (UTC)**: %s" % str(meta.get("timestamp", "")))
	lines.append("")

	lines.append("## 1. 스폰/해제 메모리 턴오버 (ObjectPool vs Naive `new()`/`free()`)")
	lines.append("")
	lines.append("| 항목 | Naive 생성/해제 | NodePool 재사용 | 풀 재사용 횟수 | 속도 향상 |")
	lines.append("| --- | ---: | ---: | ---: | ---: |")
	lines.append("| %d개 × %d사이클 (%d회) | %.2f ms | %.2f ms | %d회 | **%.2fx** |" % [
		int(churn.get("batch_size", 1000)),
		int(churn.get("cycles", 5)),
		int(churn.get("batch_size", 1000)) * int(churn.get("cycles", 5)),
		float(churn.get("naive_ms", 0.0)),
		float(churn.get("pool_ms", 0.0)),
		int(churn.get("reused", 0)),
		float(churn.get("speedup", 1.0)),
	])
	lines.append("")

	lines.append("## 2. 아키텍처별 프레임 시뮬레이션 성능 비교")
	lines.append("")
	lines.append("| 모드 | 개체 수 | 평균 (ms) | P95 (ms) | 추정 Sim FPS | 씬 트리 노드 | 쌍 검사 수 (vs O(N²)) | 비고 |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |")

	for row in rows:
		var checks_str: String = "-"
		var pair_checks: int = int(row.get("pair_checks", -1))
		var naive_pairs: int = int(row.get("naive_pairs", 0))
		if pair_checks >= 0 and naive_pairs > 0:
			checks_str = "%d / %d" % [pair_checks, naive_pairs]
		lines.append("| %s | %d | %.3f | %.3f | %.0f | %d | %s | %s |" % [
			str(row.get("mode", "")),
			int(row.get("count", 0)),
			float(row.get("avg_ms", 0.0)),
			float(row.get("p95_ms", 0.0)),
			float(row.get("sim_fps", 0.0)),
			int(row.get("node_count", 0)),
			checks_str,
			str(row.get("note", "")),
		])
	lines.append("")

	lines.append("## 3. 핵심 최적화 요약")
	lines.append("")
	lines.append_array(_build_summary_bullets(churn, rows))
	lines.append("")
	return "\n".join(lines)


static func _build_summary_bullets(churn: Dictionary, rows: Array[Dictionary]) -> Array[String]:
	var bullets: Array[String] = []
	var churn_speedup: float = float(churn.get("speedup", 1.0))
	bullets.append(
		"- **ObjectPool (`NodePool`)**: 반복 스폰/해제 비용을 **%.2fx** 단축했습니다." % churn_speedup
	)

	var m1_2k: float = _find_avg_ms(rows, "MODE 1", 2000)
	var m4_2k: float = _find_avg_ms(rows, "MODE 4A", 2000)
	if m1_2k > 0.0 and m4_2k > 0.0:
		bullets.append(
			"- **MultiMesh2D + SoA (2,000개체 기준)**: 프레임 시뮬레이션 시간 %.3f ms → %.3f ms (**%.2fx** 가속, 씬 트리 노드 0개, 1 Draw Call)." % [
				m1_2k, m4_2k, m1_2k / m4_2k
			]
		)

	for row in rows:
		if str(row.get("mode", "")).begins_with("MODE 3") and int(row.get("count", 0)) == 2000:
			var checks: int = int(row.get("pair_checks", 0))
			var naive: int = int(row.get("naive_pairs", 1))
			var reduction: float = (1.0 - float(checks) / float(maxi(1, naive))) * 100.0
			bullets.append(
				"- **SpatialGrid2D (2,000개체 충돌)**: 쌍 검사를 %d회(O(N²))에서 %d회로 **%.2f%%** 절감했습니다." % [
					naive, checks, reduction
				]
			)
		elif str(row.get("mode", "")).begins_with("MODE 4A") and int(row.get("count", 0)) == 10000:
			bullets.append(
				"- **10,000개체 극한 스트레스 테스트 (`MODE 4A`)**: 평균 **%.3f ms** (추정 **%.0f Sim FPS**, 노드 **0개**)." % [
					float(row.get("avg_ms", 0.0)), float(row.get("sim_fps", 0.0))
				]
			)

	return bullets


static func _find_avg_ms(rows: Array[Dictionary], mode_prefix: String, count_val: int) -> float:
	for row in rows:
		if str(row.get("mode", "")).begins_with(mode_prefix) and int(row.get("count", 0)) == count_val:
			return float(row.get("avg_ms", 0.0))
	return 0.0
