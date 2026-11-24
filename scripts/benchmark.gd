class_name BenchmarkArena
extends Node2D

enum BenchMode { NAIVE, POOLED_BATCHED, SPATIAL_GRID, MULTIMESH_DOD }

const MAX_ENTITIES: int = 10000
const ARENA_BOUNDS: Rect2 = Rect2(56.0, 56.0, 1040.0, 450.0)
const SPATIAL_CELL_SIZE: float = 48.0
const COLLISION_RADIUS: float = 10.0
const COLLISION_DIAMETER: float = 20.0
const COLLISION_DIAMETER_SQ: float = 400.0
const BAT_TEXTURE: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0120.png")
const ORB_TEXTURE: Texture2D = preload("res://assets/custom/magic_orb.png")
const DISSOLVE_SHADER: Shader = preload("res://shaders/dissolve.gdshader")

var mode: BenchMode = BenchMode.NAIVE
var target_count: int = 0
var break_batching: bool = true
var auto_ramp_active: bool = false
var soa_collisions: bool = false
var _ramp_timer: float = 0.0
var _low_fps_strikes: int = 0
var _naive_entities: Array[StressEntity] = []
var _pooled_entities: Array[StressEntity] = []
var _pool: NodePool = NodePool.new()
var _shared_material: ShaderMaterial
var _spatial_grid: SpatialGrid2D = SpatialGrid2D.new(SPATIAL_CELL_SIZE)
var _neighbor_buf: Array = []
var _last_pair_checks: int = 0
var _last_collisions: int = 0
var _status_refresh_timer: float = 0.0
var _swarm_renderer: SwarmMultiMesh2D
var _pool_initialized: bool = false

@onready var entity_layer: Node2D = get_node_or_null("EntityLayer") as Node2D
@onready var mode_label: Label = get_node_or_null("UI/TopRightPanel/MarginContainer/VBoxContainer/ModeLabel") as Label
@onready var status_label: Label = (
	get_node_or_null("UI/TopRightPanel/MarginContainer/VBoxContainer/StatusLabel") as Label
)
@onready var result_banner: Label = get_node_or_null("UI/ResultBanner") as Label
@onready var btn_mode_naive: Button = (
	get_node_or_null("UI/ControlsPanel/MarginContainer/VBoxContainer/ModeRow/BtnModeNaive") as Button
)
@onready var btn_mode_pooled: Button = (
	get_node_or_null("UI/ControlsPanel/MarginContainer/VBoxContainer/ModeRow/BtnModePooled") as Button
)
@onready var btn_mode_spatial: Button = (
	get_node_or_null("UI/ControlsPanel/MarginContainer/VBoxContainer/ModeRow/BtnModeSpatial") as Button
)
@onready var btn_mode_multimesh: Button = (
	get_node_or_null("UI/ControlsPanel/MarginContainer/VBoxContainer/ModeRow/BtnModeMultiMesh") as Button
)
@onready var auto_ramp_button: Button = (
	get_node_or_null("UI/ControlsPanel/MarginContainer/VBoxContainer/ActionRow/AutoRampButton") as Button
)
@onready var batch_toggle_button: Button = (
	get_node_or_null("UI/ControlsPanel/MarginContainer/VBoxContainer/ActionRow/BatchToggleButton") as Button
)
@onready var back_button: Button = (
	get_node_or_null("UI/TopRightPanel/MarginContainer/VBoxContainer/BackButton") as Button
)


func _ready() -> void:
	_ensure_entity_layer()
	_ensure_shared_material()
	_ensure_swarm_renderer()
	_ensure_pool_initialized()
	_set_perf_overlay(true)
	_wire_buttons()
	if status_label != null:
		set_target_count(200)
	_update_status_ui()


func _process(delta: float) -> void:
	if auto_ramp_active:
		_step_auto_ramp(delta)
	if mode == BenchMode.SPATIAL_GRID or mode == BenchMode.MULTIMESH_DOD:
		_status_refresh_timer += delta
		if _status_refresh_timer >= 0.25:
			_status_refresh_timer = 0.0
			_update_status_ui()


func _physics_process(delta: float) -> void:
	if mode == BenchMode.SPATIAL_GRID and not _pooled_entities.is_empty():
		step_spatial_simulation(delta)
	elif mode == BenchMode.MULTIMESH_DOD and _swarm_renderer != null:
		_swarm_renderer.step_simulation(delta)


func get_active_entity_count() -> int:
	if mode == BenchMode.MULTIMESH_DOD:
		return _swarm_renderer.get_entity_count() if _swarm_renderer != null else 0
	if mode == BenchMode.POOLED_BATCHED or mode == BenchMode.SPATIAL_GRID:
		return _pooled_entities.size()
	return _naive_entities.size()


func get_pool_reuse_count() -> int:
	return _pool.total_reused


func get_last_pair_checks() -> int:
	if mode == BenchMode.MULTIMESH_DOD and _swarm_renderer != null:
		return _swarm_renderer.last_pair_checks
	return _last_pair_checks


func get_last_collisions() -> int:
	if mode == BenchMode.MULTIMESH_DOD and _swarm_renderer != null:
		return _swarm_renderer.last_collisions
	return _last_collisions


func get_spatial_cell_count() -> int:
	if mode == BenchMode.MULTIMESH_DOD and _swarm_renderer != null:
		return _swarm_renderer.get_active_cell_count()
	return _spatial_grid.get_active_cell_count()


func set_mode(new_mode: BenchMode) -> void:
	if mode == new_mode:
		return
	auto_ramp_active = false
	_status_refresh_timer = 0.0
	var saved_target: int = target_count
	_clear_active_entities()
	_spatial_grid.clear()
	_last_pair_checks = 0
	_last_collisions = 0
	mode = new_mode
	if _swarm_renderer != null:
		_swarm_renderer.set_entity_count(0)
		_swarm_renderer.visible = mode == BenchMode.MULTIMESH_DOD
	if result_banner != null:
		result_banner.visible = false
	set_target_count(saved_target)


func set_target_count(new_count: int) -> void:
	target_count = clampi(new_count, 0, MAX_ENTITIES)
	if mode == BenchMode.MULTIMESH_DOD:
		_sync_multimesh_count()
	elif mode == BenchMode.POOLED_BATCHED or mode == BenchMode.SPATIAL_GRID:
		_sync_pooled_count()
	else:
		_sync_naive_count()
	_update_status_ui()


func step_spatial_simulation(delta: float) -> void:
	var count: int = _pooled_entities.size()
	_spatial_grid.clear()
	for i in range(count):
		var ent: StressEntity = _pooled_entities[i]
		ent.step_manual(delta)
		_spatial_grid.insert(i, ent.position)

	var pair_checks: int = 0
	var collisions: int = 0
	for i in range(count):
		var ent_a: StressEntity = _pooled_entities[i]
		var pos_a: Vector2 = ent_a.position
		_spatial_grid.query_radius_into(pos_a, COLLISION_DIAMETER + 2.0, _neighbor_buf)
		for cand in _neighbor_buf:
			var j: int = int(cand)
			if j <= i:
				continue
			pair_checks += 1
			var ent_b: StressEntity = _pooled_entities[j]
			var diff: Vector2 = ent_b.position - pos_a
			var dist_sq: float = diff.length_squared()
			if dist_sq < COLLISION_DIAMETER_SQ:
				collisions += 1
				var dist: float = sqrt(dist_sq)
				var normal: Vector2 = diff / dist if dist_sq > 0.0001 else Vector2.RIGHT
				var push: Vector2 = normal * (0.5 * (COLLISION_DIAMETER - dist))
				ent_a.position -= push
				ent_b.position += push
				pos_a = ent_a.position
				var rel_vel: Vector2 = ent_b.velocity - ent_a.velocity
				var rel_along_normal: float = rel_vel.dot(normal)
				if rel_along_normal < 0.0:
					var impulse: Vector2 = normal * rel_along_normal
					ent_a.velocity += impulse
					ent_b.velocity -= impulse
				ent_a.trigger_collision_flash()
				ent_b.trigger_collision_flash()
	_last_pair_checks = pair_checks
	_last_collisions = collisions


func step_multimesh_simulation(delta: float) -> void:
	if _swarm_renderer != null:
		_swarm_renderer.step_simulation(delta)


func set_soa_collisions(enabled: bool) -> void:
	soa_collisions = enabled
	if _swarm_renderer != null:
		_swarm_renderer.collisions_enabled = enabled
	_update_status_ui()


func set_break_batching(enabled: bool) -> void:
	break_batching = enabled
	var prev: int = target_count
	_clear_active_entities()
	set_target_count(prev)


func toggle_auto_ramp() -> void:
	auto_ramp_active = not auto_ramp_active
	_ramp_timer = 0.0
	_low_fps_strikes = 0
	if auto_ramp_active:
		if result_banner != null:
			result_banner.visible = false
		if target_count == 0:
			set_target_count(200)
	_update_status_ui()


func _ensure_shared_material() -> void:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = DISSOLVE_SHADER


func _ensure_entity_layer() -> void:
	if entity_layer == null:
		entity_layer = Node2D.new()
		entity_layer.name = "EntityLayer"
		add_child(entity_layer)


func _ensure_swarm_renderer() -> void:
	if _swarm_renderer == null:
		_ensure_entity_layer()
		_swarm_renderer = SwarmMultiMesh2D.new()
		_swarm_renderer.setup(BAT_TEXTURE, ARENA_BOUNDS)
		_swarm_renderer.visible = false
		entity_layer.add_child(_swarm_renderer)


func _ensure_pool_initialized() -> void:
	if not _pool_initialized:
		_ensure_entity_layer()
		_pool.setup_factory(_create_pooled_entity, entity_layer, 0)
		_pool_initialized = true


func _create_pooled_entity() -> Node:
	return StressEntity.new()


func _sync_naive_count() -> void:
	_ensure_entity_layer()
	while _naive_entities.size() > target_count:
		var ent: StressEntity = _naive_entities.pop_back()
		if is_instance_valid(ent):
			if ent.is_inside_tree():
				ent.queue_free()
			else:
				ent.free()
	while _naive_entities.size() < target_count:
		var ent: StressEntity = StressEntity.new()
		var mat: Material = null
		if break_batching:
			var unique_mat: ShaderMaterial = ShaderMaterial.new()
			unique_mat.shader = DISSOLVE_SHADER
			mat = unique_mat
		_configure_entity_random(ent, _naive_entities.size(), mat)
		entity_layer.add_child(ent)
		_naive_entities.append(ent)


func _sync_pooled_count() -> void:
	_ensure_entity_layer()
	_ensure_shared_material()
	_ensure_pool_initialized()
	while _pooled_entities.size() > target_count:
		var ent: StressEntity = _pooled_entities.pop_back()
		if is_instance_valid(ent):
			_pool.release(ent)
	while _pooled_entities.size() < target_count:
		var ent: StressEntity = _pool.acquire() as StressEntity
		if ent == null:
			break
		_configure_entity_random(ent, _pooled_entities.size(), _shared_material)
		ent.set_physics_collision_enabled(mode == BenchMode.POOLED_BATCHED)
		_pooled_entities.append(ent)


func _sync_multimesh_count() -> void:
	_ensure_swarm_renderer()
	_swarm_renderer.visible = true
	_swarm_renderer.collisions_enabled = soa_collisions
	_swarm_renderer.set_entity_count(target_count)


func _configure_entity_random(ent: StressEntity, index_val: int, mat: Material) -> void:
	var tex: Texture2D = BAT_TEXTURE if (index_val % 2 == 0) else ORB_TEXTURE
	var start_pos: Vector2 = Vector2(
		randf_range(ARENA_BOUNDS.position.x, ARENA_BOUNDS.end.x),
		randf_range(ARENA_BOUNDS.position.y, ARENA_BOUNDS.end.y)
	)
	var angle: float = randf_range(0.0, TAU)
	var vel: Vector2 = Vector2.from_angle(angle) * randf_range(110.0, 240.0)
	ent.bounds = ARENA_BOUNDS
	ent.configure(tex, start_pos, vel, mat)


func _clear_active_entities() -> void:
	while not _naive_entities.is_empty():
		var ent: StressEntity = _naive_entities.pop_back()
		if is_instance_valid(ent):
			if ent.is_inside_tree():
				ent.queue_free()
			else:
				ent.free()
	while not _pooled_entities.is_empty():
		var ent: StressEntity = _pooled_entities.pop_back()
		if is_instance_valid(ent):
			_pool.release(ent)
	if _swarm_renderer != null:
		_swarm_renderer.set_entity_count(0)
		_swarm_renderer.visible = false


func _step_auto_ramp(delta: float) -> void:
	_ramp_timer += delta
	if _ramp_timer < 0.6:
		return
	_ramp_timer = 0.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	if fps > 0.0 and fps < 30.0 and get_active_entity_count() >= 200:
		_low_fps_strikes += 1
	else:
		_low_fps_strikes = 0

	var ramp_cap: int = 10000 if mode == BenchMode.MULTIMESH_DOD else 5000
	var ramp_step: int = 500 if mode == BenchMode.MULTIMESH_DOD else 200
	if _low_fps_strikes >= 2 or target_count >= ramp_cap:
		auto_ramp_active = false
		var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if result_banner != null:
			result_banner.visible = true
			result_banner.text = "측정 완료! 개체 %d개 | FPS: %.0f | Draw Calls: %d" % [
				get_active_entity_count(), fps, draw_calls
			]
		_update_status_ui()
		return

	set_target_count(target_count + ramp_step)


func _wire_buttons() -> void:
	var row_path: String = "UI/ControlsPanel/MarginContainer/VBoxContainer/CountRow"
	var presets: Dictionary = {
		"Btn0": 0,
		"Btn200": 200,
		"Btn500": 500,
		"Btn1000": 1000,
		"Btn2000": 2000,
		"Btn4000": 4000,
		"Btn10000": 10000,
	}
	for btn_name in presets:
		var btn: Button = get_node_or_null("%s/%s" % [row_path, btn_name]) as Button
		if btn != null:
			var count_val: int = int(presets[btn_name])
			btn.pressed.connect(_on_preset_pressed.bind(count_val))
	var plus_btn: Button = get_node_or_null(row_path + "/BtnPlus500") as Button
	if plus_btn != null:
		plus_btn.pressed.connect(_on_plus_pressed)
	if btn_mode_naive != null:
		btn_mode_naive.pressed.connect(_on_mode_naive_pressed)
	if btn_mode_pooled != null:
		btn_mode_pooled.pressed.connect(_on_mode_pooled_pressed)
	if btn_mode_spatial != null:
		btn_mode_spatial.pressed.connect(_on_mode_spatial_pressed)
	if btn_mode_multimesh != null:
		btn_mode_multimesh.pressed.connect(_on_mode_multimesh_pressed)
	if auto_ramp_button != null:
		auto_ramp_button.pressed.connect(toggle_auto_ramp)
	if batch_toggle_button != null:
		batch_toggle_button.pressed.connect(_on_batch_toggle_pressed)
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)


func _on_mode_naive_pressed() -> void:
	set_mode(BenchMode.NAIVE)


func _on_mode_pooled_pressed() -> void:
	set_mode(BenchMode.POOLED_BATCHED)


func _on_mode_spatial_pressed() -> void:
	set_mode(BenchMode.SPATIAL_GRID)


func _on_mode_multimesh_pressed() -> void:
	set_mode(BenchMode.MULTIMESH_DOD)


func _on_preset_pressed(count_val: int) -> void:
	auto_ramp_active = false
	set_target_count(count_val)


func _on_plus_pressed() -> void:
	auto_ramp_active = false
	set_target_count(target_count + 500)


func _on_batch_toggle_pressed() -> void:
	if mode == BenchMode.MULTIMESH_DOD:
		set_soa_collisions(not soa_collisions)
	else:
		set_break_batching(not break_batching)


func _on_back_pressed() -> void:
	auto_ramp_active = false
	_clear_active_entities()
	_spatial_grid.clear()
	_pool.clear_and_free()
	_set_perf_overlay(false)
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("go_to_title"):
		gm.call("go_to_title")
	elif is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _set_perf_overlay(should_show: bool) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("set_perf_overlay_visible"):
		gm.call("set_perf_overlay_visible", should_show)


func _update_status_ui() -> void:
	if mode_label != null:
		if mode == BenchMode.MULTIMESH_DOD:
			mode_label.text = "MODE 4: MultiMesh2D + SoA (1 Draw Call)"
		elif mode == BenchMode.SPATIAL_GRID:
			mode_label.text = "MODE 3: SpatialGrid2D (O(N) 충돌)"
		elif mode == BenchMode.POOLED_BATCHED:
			mode_label.text = "MODE 2: ObjectPool + 공유 셰이더 배칭"
		else:
			mode_label.text = "MODE 1: Naive SceneTree 노드 (기준선)"
	if status_label != null:
		if mode == BenchMode.MULTIMESH_DOD and _swarm_renderer != null:
			if soa_collisions:
				status_label.text = "활성: %d | 셀: %d | 검사: %d | 충돌: %d" % [
					_swarm_renderer.get_entity_count(),
					_swarm_renderer.get_active_cell_count(),
					_swarm_renderer.last_pair_checks,
					_swarm_renderer.last_collisions,
				]
			else:
				status_label.text = "활성: %d | 노드: 0 | 버퍼: %dKB (1 Draw Call)" % [
					_swarm_renderer.get_entity_count(),
					_swarm_renderer.get_buffer_kilobytes(),
				]
		elif mode == BenchMode.SPATIAL_GRID:
			var n: int = _pooled_entities.size()
			var naive_pairs: int = (n * (n - 1)) / 2
			status_label.text = "활성: %d | 셀: %d | 검사: %d (vs O(N²) %d)" % [
				n, _spatial_grid.get_active_cell_count(), _last_pair_checks, naive_pairs
			]
		elif mode == BenchMode.POOLED_BATCHED:
			status_label.text = "활성: %d | 풀 대기: %d | 재사용: %d회" % [
				_pooled_entities.size(), _pool.get_available_count(), _pool.total_reused
			]
		else:
			var shader_state: String = "ON" if break_batching else "OFF"
			status_label.text = "활성 개체: %d | 개별 셰이더: %s" % [_naive_entities.size(), shader_state]
	if btn_mode_naive != null:
		btn_mode_naive.disabled = mode == BenchMode.NAIVE
	if btn_mode_pooled != null:
		btn_mode_pooled.disabled = mode == BenchMode.POOLED_BATCHED
	if btn_mode_spatial != null:
		btn_mode_spatial.disabled = mode == BenchMode.SPATIAL_GRID
	if btn_mode_multimesh != null:
		btn_mode_multimesh.disabled = mode == BenchMode.MULTIMESH_DOD
	if auto_ramp_button != null:
		auto_ramp_button.text = "⏹ 자동 측정 중지" if auto_ramp_active else "🔥 한계 자동 측정 (30 FPS 컷)"
	if batch_toggle_button != null:
		if mode == BenchMode.MULTIMESH_DOD:
			batch_toggle_button.disabled = false
			batch_toggle_button.text = "SoA 충돌: ON (SpatialGrid)" if soa_collisions else "SoA 충돌: OFF (순수 1만)"
		else:
			batch_toggle_button.disabled = mode != BenchMode.NAIVE
			var state_text: String = "ON (배칭 깨짐)" if break_batching else "OFF (공유 배칭)"
			batch_toggle_button.text = "개별 셰이더: %s" % state_text
