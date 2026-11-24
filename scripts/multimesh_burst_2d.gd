class_name MultiMeshBurst2D
extends MultiMeshInstance2D

const MAX_PARTICLES: int = 256
const STRIDE: int = 12

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var ages: PackedFloat32Array = PackedFloat32Array()
var lifetimes: PackedFloat32Array = PackedFloat32Array()
var base_scales: PackedFloat32Array = PackedFloat32Array()
var colors: PackedColorArray = PackedColorArray()
var _mm_buffer: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _active_count: int = 0
var _dirty: bool = false


func _init() -> void:
	positions.resize(MAX_PARTICLES)
	velocities.resize(MAX_PARTICLES)
	ages.resize(MAX_PARTICLES)
	lifetimes.resize(MAX_PARTICLES)
	base_scales.resize(MAX_PARTICLES)
	colors.resize(MAX_PARTICLES)
	_mm_buffer.resize(MAX_PARTICLES * STRIDE)
	_ensure_multimesh()


func _process(delta: float) -> void:
	step_particles(delta)


func setup(spark_texture: Texture2D, quad_size: Vector2 = Vector2(18.0, 18.0)) -> void:
	texture = spark_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_multimesh(quad_size)
	for i in range(MAX_PARTICLES):
		ages[i] = 1.0
		lifetimes[i] = 0.0
	_zero_buffer()
	multimesh.buffer = _mm_buffer
	_active_count = 0
	_dirty = false


func emit_burst(
	world_pos: Vector2,
	count: int = 5,
	tint: Color = Color(1.0, 0.92, 0.55, 1.0)
) -> void:
	var spawn_n: int = clampi(count, 1, MAX_PARTICLES)
	for _i in range(spawn_n):
		var idx: int = _cursor
		_cursor = (_cursor + 1) % MAX_PARTICLES
		positions[idx] = world_pos
		var angle: float = randf_range(0.0, TAU)
		velocities[idx] = Vector2.from_angle(angle) * randf_range(80.0, 190.0)
		ages[idx] = 0.0
		lifetimes[idx] = randf_range(0.18, 0.28)
		base_scales[idx] = randf_range(1.2, 2.0)
		colors[idx] = tint
	_dirty = true
	_recompute_active_count()


func step_particles(delta: float) -> void:
	if _active_count == 0 and not _dirty:
		return
	var alive: int = 0
	for i in range(MAX_PARTICLES):
		var base: int = i * STRIDE
		var life: float = lifetimes[i]
		var age: float = ages[i] + delta
		ages[i] = age
		if life > 0.0 and age < life:
			alive += 1
			var pos: Vector2 = positions[i] + velocities[i] * delta
			positions[i] = pos
			var t: float = clampf(age / life, 0.0, 1.0)
			var scale_val: float = lerpf(base_scales[i], base_scales[i] * 1.5, t)
			var c: Color = colors[i]
			_mm_buffer[base + 0] = scale_val
			_mm_buffer[base + 1] = 0.0
			_mm_buffer[base + 2] = 0.0
			_mm_buffer[base + 3] = pos.x
			_mm_buffer[base + 4] = 0.0
			_mm_buffer[base + 5] = -scale_val
			_mm_buffer[base + 6] = 0.0
			_mm_buffer[base + 7] = pos.y
			_mm_buffer[base + 8] = c.r
			_mm_buffer[base + 9] = c.g
			_mm_buffer[base + 10] = c.b
			_mm_buffer[base + 11] = c.a * (1.0 - t)
		else:
			lifetimes[i] = 0.0
			_mm_buffer[base + 0] = 0.0
			_mm_buffer[base + 1] = 0.0
			_mm_buffer[base + 2] = 0.0
			_mm_buffer[base + 3] = 0.0
			_mm_buffer[base + 4] = 0.0
			_mm_buffer[base + 5] = 0.0
			_mm_buffer[base + 6] = 0.0
			_mm_buffer[base + 7] = 0.0
			_mm_buffer[base + 8] = 0.0
			_mm_buffer[base + 9] = 0.0
			_mm_buffer[base + 10] = 0.0
			_mm_buffer[base + 11] = 0.0

	multimesh.buffer = _mm_buffer
	_active_count = alive
	_dirty = false


func get_active_count() -> int:
	return _active_count


func _ensure_multimesh(quad_size: Vector2 = Vector2(18.0, 18.0)) -> void:
	if multimesh == null:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = false
		var quad: QuadMesh = QuadMesh.new()
		quad.size = quad_size
		mm.mesh = quad
		mm.instance_count = MAX_PARTICLES
		multimesh = mm
	elif multimesh.mesh is QuadMesh:
		(multimesh.mesh as QuadMesh).size = quad_size


func _zero_buffer() -> void:
	for i in range(_mm_buffer.size()):
		_mm_buffer[i] = 0.0


func _recompute_active_count() -> void:
	var alive: int = 0
	for i in range(MAX_PARTICLES):
		if lifetimes[i] > 0.0 and ages[i] < lifetimes[i]:
			alive += 1
	_active_count = alive
