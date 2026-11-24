class_name SwarmMultiMesh2D
extends MultiMeshInstance2D

const STRIDE: int = 12
const QUAD_SIZE: Vector2 = Vector2(28.0, 28.0)
const COLLISION_DIAMETER: float = 20.0
const COLLISION_DIAMETER_SQ: float = 400.0
const SPATIAL_CELL_SIZE: float = 48.0
const TINT_A: Color = Color(1.0, 0.88, 0.95, 1.0)
const TINT_B: Color = Color(0.65, 0.92, 1.0, 1.0)
const FLASH_COLOR: Color = Color(1.0, 0.95, 0.45, 1.0)

var bounds: Rect2 = Rect2(56.0, 56.0, 1040.0, 450.0)
var collisions_enabled: bool = false
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var flash_timers: PackedFloat32Array = PackedFloat32Array()
var base_tints: PackedColorArray = PackedColorArray()
var last_pair_checks: int = 0
var last_collisions: int = 0
var _count: int = 0
var _mm_buffer: PackedFloat32Array = PackedFloat32Array()
var _spatial_grid: SpatialGrid2D = SpatialGrid2D.new(SPATIAL_CELL_SIZE)
var _neighbor_buf: Array = []


func _init() -> void:
	_ensure_multimesh()


func setup(sprite_texture: Texture2D, arena_bounds: Rect2) -> void:
	texture = sprite_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bounds = arena_bounds
	_ensure_multimesh()


func set_entity_count(new_count: int) -> void:
	var clamped: int = maxi(0, new_count)
	var old_count: int = _count
	_count = clamped
	positions.resize(_count)
	velocities.resize(_count)
	flash_timers.resize(_count)
	base_tints.resize(_count)
	_mm_buffer.resize(_count * STRIDE)

	for i in range(old_count, _count):
		positions[i] = Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)
		var angle: float = randf_range(0.0, TAU)
		velocities[i] = Vector2.from_angle(angle) * randf_range(110.0, 240.0)
		flash_timers[i] = 0.0
		base_tints[i] = TINT_A if (i % 2 == 0) else TINT_B

	_ensure_multimesh()
	multimesh.instance_count = _count
	if _count == 0:
		_spatial_grid.clear()
		last_pair_checks = 0
		last_collisions = 0
		return
	sync_multimesh_buffer()


func get_entity_count() -> int:
	return _count


func get_buffer_kilobytes() -> int:
	return (_mm_buffer.size() * 4) / 1024


func get_active_cell_count() -> int:
	return _spatial_grid.get_active_cell_count()


func step_simulation(delta: float) -> void:
	if _count <= 0:
		return
	var min_x: float = bounds.position.x
	var max_x: float = bounds.end.x
	var min_y: float = bounds.position.y
	var max_y: float = bounds.end.y

	for i in range(_count):
		var p: Vector2 = positions[i]
		var v: Vector2 = velocities[i]
		p += v * delta
		if p.x < min_x:
			p.x = min_x
			v.x = absf(v.x)
		elif p.x > max_x:
			p.x = max_x
			v.x = -absf(v.x)

		if p.y < min_y:
			p.y = min_y
			v.y = absf(v.y)
		elif p.y > max_y:
			p.y = max_y
			v.y = -absf(v.y)

		positions[i] = p
		velocities[i] = v
		var f: float = flash_timers[i]
		if f > 0.0:
			flash_timers[i] = maxf(0.0, f - delta * 5.0)

	if collisions_enabled:
		_resolve_soa_collisions()
	else:
		last_pair_checks = 0
		last_collisions = 0

	sync_multimesh_buffer()


func sync_multimesh_buffer() -> void:
	if _count <= 0:
		return
	_ensure_multimesh()
	if multimesh.instance_count != _count:
		multimesh.instance_count = _count
	if _mm_buffer.size() != _count * STRIDE:
		_mm_buffer.resize(_count * STRIDE)

	for i in range(_count):
		var base: int = i * STRIDE
		var p: Vector2 = positions[i]
		var sx: float = -1.0 if velocities[i].x < 0.0 else 1.0
		_mm_buffer[base + 0] = sx
		_mm_buffer[base + 1] = 0.0
		_mm_buffer[base + 2] = 0.0
		_mm_buffer[base + 3] = p.x
		_mm_buffer[base + 4] = 0.0
		_mm_buffer[base + 5] = -1.0
		_mm_buffer[base + 6] = 0.0
		_mm_buffer[base + 7] = p.y

		var tint: Color = base_tints[i]
		var f: float = flash_timers[i]
		if f > 0.0:
			tint = tint.lerp(FLASH_COLOR, f)
		_mm_buffer[base + 8] = tint.r
		_mm_buffer[base + 9] = tint.g
		_mm_buffer[base + 10] = tint.b
		_mm_buffer[base + 11] = tint.a

	multimesh.buffer = _mm_buffer


func _ensure_multimesh() -> void:
	if multimesh == null:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = false
		var quad: QuadMesh = QuadMesh.new()
		quad.size = QUAD_SIZE
		mm.mesh = quad
		multimesh = mm


func _resolve_soa_collisions() -> void:
	_spatial_grid.clear()
	for i in range(_count):
		_spatial_grid.insert(i, positions[i])

	var pair_checks: int = 0
	var collisions: int = 0
	for i in range(_count):
		var pos_a: Vector2 = positions[i]
		var vel_a: Vector2 = velocities[i]
		_spatial_grid.query_radius_into(pos_a, COLLISION_DIAMETER + 2.0, _neighbor_buf)
		for cand in _neighbor_buf:
			var j: int = int(cand)
			if j <= i:
				continue
			pair_checks += 1
			var pos_b: Vector2 = positions[j]
			var diff: Vector2 = pos_b - pos_a
			var dist_sq: float = diff.length_squared()
			if dist_sq < COLLISION_DIAMETER_SQ:
				collisions += 1
				var dist: float = sqrt(dist_sq)
				var normal: Vector2 = diff / dist if dist_sq > 0.0001 else Vector2.RIGHT
				var push: Vector2 = normal * (0.5 * (COLLISION_DIAMETER - dist))
				pos_a -= push
				pos_b += push
				positions[i] = pos_a
				positions[j] = pos_b

				var vel_b: Vector2 = velocities[j]
				var rel_along_normal: float = (vel_b - vel_a).dot(normal)
				if rel_along_normal < 0.0:
					var impulse: Vector2 = normal * rel_along_normal
					vel_a += impulse
					vel_b -= impulse
					velocities[i] = vel_a
					velocities[j] = vel_b
				flash_timers[i] = 1.0
				flash_timers[j] = 1.0

	last_pair_checks = pair_checks
	last_collisions = collisions
