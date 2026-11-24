class_name Enemy
extends Area2D

signal hit_player(damage: int)
signal damaged(remaining_hp: int, damage_taken: int)
signal died(enemy_position: Vector2, score_reward: int)
signal cast_orbs(origin: Vector2, directions: Array[Vector2])

const BOSS_AURA_TEXTURE: Texture2D = preload("res://assets/custom/boss_crown.png")

@export var data: EnemyData
@export var max_hp: int = 2
@export var speed: float = 160.0
@export var speed_multiplier: float = 1.0
@export var margin: float = 16.0
@export var dungeon_map: DungeonMap
@export var target: Node2D
@export var is_boss: bool = false
@export var boss_fire_interval: float = 2.1

var direction: Vector2 = Vector2.RIGHT
var current_hp: int = 2
var is_dying: bool = false
var boss_cast_cooldown: float = 1.4
var _knockback_velocity: Vector2 = Vector2.ZERO
var _boss_pattern_index: int = 0
var _aura_sprite: Sprite2D

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	current_hp = get_max_hp()
	boss_cast_cooldown = boss_fire_interval * 0.65
	if sprite != null and data != null and data.texture != null:
		sprite.texture = data.texture
	if is_boss:
		scale = Vector2(1.5, 1.5)
		_setup_boss_aura()
	var angle: float = randf_range(0.0, TAU)
	direction = Vector2.from_angle(angle)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	if is_boss:
		step_boss_cast(delta)
		if _aura_sprite != null:
			_aura_sprite.rotation += delta * 2.4
	if get_behavior() == EnemyData.Behavior.CHASE and target != null:
		var desired: Vector2 = compute_desired_direction(global_position, target.global_position)
		if desired != Vector2.ZERO:
			direction = direction.lerp(desired, clampf(delta * 5.0, 0.0, 1.0)).normalized()

	if sprite != null and not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0

	var step: Vector2 = (direction * get_effective_speed() + _knockback_velocity) * delta
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 750.0 * delta)
	if dungeon_map != null:
		var next_x: Vector2 = position + Vector2(step.x, 0.0)
		if _hits_wall(next_x):
			direction.x = -direction.x
		else:
			position.x = next_x.x

		var next_y: Vector2 = position + Vector2(0.0, step.y)
		if _hits_wall(next_y):
			direction.y = -direction.y
		else:
			position.y = next_y.y
		return

	position += step
	var screen_size: Vector2 = get_viewport_rect().size
	if position.x <= margin or position.x >= screen_size.x - margin:
		direction.x = -direction.x
		position.x = clampf(position.x, margin, screen_size.x - margin)
	if position.y <= margin or position.y >= screen_size.y - margin:
		direction.y = -direction.y
		position.y = clampf(position.y, margin, screen_size.y - margin)


func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = multiplier


func get_effective_speed() -> float:
	var base_speed: float = data.speed if data != null else speed
	return base_speed * speed_multiplier


func get_effective_damage() -> int:
	if data != null:
		return data.damage
	return 1


func get_max_hp() -> int:
	if data != null:
		return data.max_hp
	return max_hp


func get_score_value() -> int:
	if data != null:
		return data.score_value
	return 2


func get_behavior() -> EnemyData.Behavior:
	if data != null:
		return data.behavior
	return EnemyData.Behavior.BOUNCE


func compute_desired_direction(current_pos: Vector2, target_pos: Vector2) -> Vector2:
	if get_behavior() == EnemyData.Behavior.CHASE:
		var delta_pos: Vector2 = target_pos - current_pos
		if delta_pos != Vector2.ZERO:
			return delta_pos.normalized()
	return direction


func compute_boss_pattern_directions(aim_dir: Vector2, pattern_index: int) -> Array[Vector2]:
	var base_dir: Vector2 = aim_dir.normalized() if aim_dir != Vector2.ZERO else Vector2.DOWN
	var dirs: Array[Vector2] = []
	if pattern_index % 2 == 0:
		var base_angle: float = base_dir.angle()
		dirs.append(Vector2.from_angle(base_angle - 0.32))
		dirs.append(Vector2.from_angle(base_angle))
		dirs.append(Vector2.from_angle(base_angle + 0.32))
	else:
		for i in range(6):
			dirs.append(Vector2.from_angle(float(i) * TAU / 6.0))
	return dirs


func step_boss_cast(delta: float) -> Array[Vector2]:
	if not is_boss or is_dying or current_hp <= 0:
		return []
	boss_cast_cooldown -= delta
	if boss_cast_cooldown > 0.0:
		return []
	boss_cast_cooldown = boss_fire_interval
	var aim_dir: Vector2 = direction
	if target != null:
		var to_target: Vector2 = target.global_position - global_position
		if to_target != Vector2.ZERO:
			aim_dir = to_target.normalized()
	var dirs: Array[Vector2] = compute_boss_pattern_directions(aim_dir, _boss_pattern_index)
	_boss_pattern_index += 1
	cast_orbs.emit(global_position, dirs)
	return dirs


func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, knockback_force: float = 220.0) -> bool:
	if amount <= 0 or is_dying or current_hp <= 0:
		return false
	current_hp = maxi(0, current_hp - amount)
	if knockback_dir != Vector2.ZERO:
		_knockback_velocity = knockback_dir.normalized() * knockback_force
	_trigger_hit_flash()
	damaged.emit(current_hp, amount)
	if current_hp <= 0:
		_start_death_dissolve()
	return true


func _setup_boss_aura() -> void:
	_aura_sprite = Sprite2D.new()
	_aura_sprite.texture = BOSS_AURA_TEXTURE
	_aura_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura_sprite.scale = Vector2(2.2, 2.2)
	_aura_sprite.modulate = Color(1.0, 0.85, 0.4, 0.75)
	_aura_sprite.z_index = -1
	add_child(_aura_sprite)


func _hits_wall(center_pos: Vector2) -> bool:
	var r: float = 14.0
	var offsets: Array[Vector2] = [
		Vector2(-r, -r),
		Vector2(r, -r),
		Vector2(-r, r),
		Vector2(r, r),
	]
	for offset in offsets:
		if dungeon_map.is_wall_at_world(center_pos + offset):
			return true
	return false


func _trigger_hit_flash() -> void:
	if not is_inside_tree() or sprite == null:
		return
	sprite.self_modulate.b = 0.0
	var tween: Tween = create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.14)


func _set_flash_amount(value: float) -> void:
	if sprite != null:
		sprite.self_modulate.b = 1.0 - clampf(value, 0.0, 1.0)


func _start_death_dissolve() -> void:
	is_dying = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	died.emit(global_position, get_score_value())
	if is_inside_tree() and sprite != null:
		var tween: Tween = create_tween()
		tween.tween_method(_set_dissolve_amount, 0.0, 1.0, 0.26)
		tween.tween_callback(queue_free)


func _set_dissolve_amount(value: float) -> void:
	if sprite != null:
		sprite.self_modulate.a = 1.0 - clampf(value, 0.0, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if is_dying:
		return
	if body is Player:
		hit_player.emit(get_effective_damage())
