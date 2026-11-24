class_name PerfOverlay
extends CanvasLayer

const MAX_SAMPLES: int = 90
const GRAPH_MAX_MS: float = 50.0

var _frame_ms_samples: PackedFloat32Array = PackedFloat32Array()
var _panel: PanelContainer
var _stats_label: Label
var _graph_canvas: Control
var _refresh_accum: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _process(delta: float) -> void:
	if not visible:
		return
	record_frame_ms(delta * 1000.0)
	_refresh_accum += delta
	if _refresh_accum >= 0.1:
		_refresh_accum = 0.0
		_refresh_label()
		if _graph_canvas != null:
			_graph_canvas.queue_redraw()


func record_frame_ms(ms: float) -> void:
	_frame_ms_samples.append(maxf(0.01, ms))
	while _frame_ms_samples.size() > MAX_SAMPLES:
		_frame_ms_samples.remove_at(0)


func clear_samples() -> void:
	_frame_ms_samples.clear()


func get_sample_count() -> int:
	return _frame_ms_samples.size()


func get_average_frame_ms() -> float:
	if _frame_ms_samples.is_empty():
		return 0.0
	var total: float = 0.0
	for s in _frame_ms_samples:
		total += s
	return total / float(_frame_ms_samples.size())


func get_p95_frame_ms() -> float:
	if _frame_ms_samples.is_empty():
		return 0.0
	var sorted: Array[float] = []
	for s in _frame_ms_samples:
		sorted.append(s)
	sorted.sort()
	var idx: int = mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))
	return sorted[idx]


func get_estimated_fps() -> float:
	var avg_ms: float = get_average_frame_ms()
	if avg_ms <= 0.0:
		return 0.0
	return 1000.0 / avg_ms


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(14.0, 14.0)
	_panel.custom_minimum_size = Vector2(316.0, 200.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_stats_label = Label.new()
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_stats_label.add_theme_constant_override("outline_size", 2)
	_stats_label.text = "[PERF MONITOR - F3]\nCollecting..."
	vbox.add_child(_stats_label)

	_graph_canvas = Control.new()
	_graph_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_canvas.custom_minimum_size = Vector2(292.0, 58.0)
	_graph_canvas.draw.connect(_on_graph_draw)
	vbox.add_child(_graph_canvas)


func _refresh_label() -> void:
	if _stats_label == null:
		return
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var proc_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var static_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	_stats_label.text = (
		"[PERF MONITOR - F3]\n"
		+ "FPS: %.0f  (Avg: %.1fms | P95: %.1fms)\n" % [fps, get_average_frame_ms(), get_p95_frame_ms()]
		+ "Process: %.2fms | Physics: %.2fms\n" % [proc_ms, phys_ms]
		+ "Draw Calls: %d | Nodes: %d\n" % [draw_calls, node_count]
		+ "Static RAM: %.1f MB" % static_mb
	)


func _on_graph_draw() -> void:
	if _graph_canvas == null:
		return
	var size: Vector2 = _graph_canvas.size
	_graph_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.12, 0.9))

	var line_60_y: float = size.y * (1.0 - clampf(16.67 / GRAPH_MAX_MS, 0.0, 1.0))
	var line_30_y: float = size.y * (1.0 - clampf(33.33 / GRAPH_MAX_MS, 0.0, 1.0))
	_graph_canvas.draw_line(
		Vector2(0.0, line_60_y), Vector2(size.x, line_60_y), Color(0.25, 0.9, 0.45, 0.55), 1.0
	)
	_graph_canvas.draw_line(
		Vector2(0.0, line_30_y), Vector2(size.x, line_30_y), Color(1.0, 0.85, 0.25, 0.55), 1.0
	)

	var count: int = _frame_ms_samples.size()
	if count == 0:
		return
	var bar_w: float = size.x / float(MAX_SAMPLES)
	var x_start: float = size.x - float(count) * bar_w
	for i in range(count):
		var ms: float = _frame_ms_samples[i]
		var ratio: float = clampf(ms / GRAPH_MAX_MS, 0.02, 1.0)
		var bar_h: float = size.y * ratio
		var col: Color = Color(0.3, 0.95, 0.5, 0.9)
		if ms > 33.33:
			col = Color(1.0, 0.35, 0.35, 0.95)
		elif ms > 16.67:
			col = Color(1.0, 0.82, 0.25, 0.9)
		var rect: Rect2 = Rect2(x_start + float(i) * bar_w, size.y - bar_h, maxf(1.5, bar_w - 0.5), bar_h)
		_graph_canvas.draw_rect(rect, col)
