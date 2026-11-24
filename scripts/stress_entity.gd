class_name StressEntity
extends Area2D

var velocity: Vector2 = Vector2(160.0, 120.0)
var bounds: Rect2 = Rect2(48.0, 48.0, 1056.0, 552.0)
var _sprite: Sprite2D
var _collision: CollisionShape2D


func _physics_process(delta: float) -> void:
	step_manual(delta)


func step_manual(delta: float) -> void:
	position += velocity * delta
	if position.x < bounds.position.x:
		position.x = bounds.position.x
		velocity.x = absf(velocity.x)
	elif position.x > bounds.end.x:
		position.x = bounds.end.x
		velocity.x = -absf(velocity.x)

	if position.y < bounds.position.y:
		position.y = bounds.position.y
		velocity.y = absf(velocity.y)
	elif position.y > bounds.end.y:
		position.y = bounds.end.y
		velocity.y = -absf(velocity.y)

	if _sprite != null and _sprite.self_modulate.b < 1.0:
		_sprite.self_modulate.b = minf(1.0, _sprite.self_modulate.b + delta * 6.0)


func set_physics_collision_enabled(enabled: bool) -> void:
	monitoring = enabled
	monitorable = enabled
	set_physics_process(enabled)
	if _collision != null:
		_collision.disabled = not enabled
	if enabled and _sprite != null:
		_sprite.self_modulate = Color.WHITE


func trigger_collision_flash() -> void:
	if _sprite != null:
		_sprite.self_modulate.b = 0.0


func configure(
	tex: Texture2D,
	start_pos: Vector2,
	start_vel: Vector2,
	shared_or_unique_material: Material = null
) -> void:
	position = start_pos
	velocity = start_vel
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.scale = Vector2(1.8, 1.8)
		add_child(_sprite)
	_sprite.texture = tex
	_sprite.material = shared_or_unique_material
	_sprite.self_modulate = Color.WHITE
	if _collision == null:
		_collision = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 10.0
		_collision.shape = circle
		add_child(_collision)
