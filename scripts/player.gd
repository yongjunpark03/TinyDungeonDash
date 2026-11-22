class_name Player
extends CharacterBody2D

signal state_changed(new_state: State)
signal dash_started
signal dash_cooldown_changed(remaining: float, duration: float)
signal health_changed(current_hp: int, max_hp: int)
signal attack_triggered(origin: Vector2, aim_direction: Vector2, damage: int)
signal died

enum State { IDLE, MOVE, DASH }

@export var stats: PlayerStats
@export var move_speed: float = 200.0

var state: State = State.IDLE
var facing_direction: Vector2 = Vector2.RIGHT
var dash_direction: Vector2 = Vector2.RIGHT
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var current_hp: int = 3
var hit_invuln_left: float = 0.0
var attack_cooldown_left: float = 0.0
var damage_bonus: int = 0
var bonus_max_hp: int = 0
var move_speed_multiplier: float = 1.0
var dash_cooldown_multiplier: float = 1.0
var attack_interval_multiplier: float = 1.0
var external_move_input: Vector2 = Vector2.ZERO
var _walk_time: float = 0.0
var _ghost_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	current_hp = get_max_hp()
	attack_cooldown_left = _effective_attack_interval() * 0.5
	health_changed.emit(current_hp, get_max_hp())


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if external_move_input != Vector2.ZERO:
		input_dir = external_move_input
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir.normalized()
	if Input.is_action_just_pressed("ui_accept"):
		try_start_dash(input_dir)
	step_dash_timers(delta)
	if state != State.DASH:
		_set_state(State.MOVE if input_dir != Vector2.ZERO else State.IDLE)

	velocity = compute_velocity(input_dir)
	move_and_slide()
	var screen_size: Vector2 = get_viewport_rect().size
	var margin: Vector2 = Vector2(24.0, 24.0)
	position = position.clamp(margin, screen_size - margin)
	_update_visuals(delta, input_dir)


func compute_velocity(input_dir: Vector2) -> Vector2:
	if state == State.DASH:
		return dash_direction * _effective_dash_speed()
	if input_dir == Vector2.ZERO:
		return Vector2.ZERO
	return input_dir.normalized() * _effective_move_speed()


func is_invulnerable() -> bool:
	return state == State.DASH or hit_invuln_left > 0.0


func get_max_hp() -> int:
	var base_hp: int = stats.max_hp if stats != null else 3
	return base_hp + bonus_max_hp


func grant_max_hp(amount: int) -> void:
	if amount <= 0:
		return
	bonus_max_hp += amount
	current_hp = mini(get_max_hp(), current_hp + amount)
	health_changed.emit(current_hp, get_max_hp())


func take_damage(amount: int) -> bool:
	if amount <= 0 or is_invulnerable() or current_hp <= 0:
		return false
	current_hp = maxi(0, current_hp - amount)
	hit_invuln_left = _effective_hit_invuln_duration()
	_trigger_hit_flash()
	health_changed.emit(current_hp, get_max_hp())
	if current_hp <= 0:
		died.emit()
	return true


func can_dash() -> bool:
	return state != State.DASH and dash_cooldown_left <= 0.0


func try_start_dash(input_dir: Vector2) -> bool:
	if not can_dash():
		return false
	dash_direction = input_dir.normalized() if input_dir != Vector2.ZERO else facing_direction
	dash_time_left = _effective_dash_duration()
	dash_cooldown_left = _effective_dash_cooldown()
	_ghost_timer = 0.0
	_set_state(State.DASH)
	dash_started.emit()
	dash_cooldown_changed.emit(dash_cooldown_left, _effective_dash_cooldown())
	return true


func step_dash_timers(delta: float) -> void:
	if state == State.DASH:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			dash_time_left = 0.0
			_set_state(State.IDLE)
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
		dash_cooldown_changed.emit(dash_cooldown_left, _effective_dash_cooldown())
	if hit_invuln_left > 0.0:
		hit_invuln_left = maxf(0.0, hit_invuln_left - delta)


func step_attack_timer(delta: float, target_direction: Vector2 = Vector2.ZERO) -> bool:
	if current_hp <= 0:
		return false
	attack_cooldown_left -= delta
	if attack_cooldown_left <= 0.0:
		trigger_attack(target_direction)
		return true
	return false


func trigger_attack(target_direction: Vector2 = Vector2.ZERO) -> Vector2:
	var aim: Vector2 = target_direction.normalized() if target_direction != Vector2.ZERO else facing_direction
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	attack_cooldown_left = _effective_attack_interval()
	attack_triggered.emit(global_position, aim, _effective_attack_damage())
	return aim


func _effective_move_speed() -> float:
	var base_speed: float = stats.move_speed if stats != null else move_speed
	return base_speed * move_speed_multiplier


func _effective_dash_speed() -> float:
	if stats != null:
		return stats.dash_speed
	return 520.0


func _effective_dash_duration() -> float:
	if stats != null:
		return stats.dash_duration
	return 0.16


func _effective_dash_cooldown() -> float:
	var base_cd: float = stats.dash_cooldown if stats != null else 1.2
	return base_cd * dash_cooldown_multiplier


func _effective_hit_invuln_duration() -> float:
	if stats != null:
		return stats.hit_invuln_duration
	return 1.0


func _effective_attack_interval() -> float:
	var base_interval: float = stats.attack_interval if stats != null else 0.75
	return base_interval * attack_interval_multiplier


func _effective_attack_damage() -> int:
	var base_damage: int = stats.attack_damage if stats != null else 1
	return base_damage + damage_bonus


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _trigger_hit_flash() -> void:
	if sprite == null:
		return
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_amount", 1.0)
	var tween: Tween = create_tween()
	tween.tween_method(_set_hit_flash_amount, 1.0, 0.0, 0.18)


func _set_hit_flash_amount(value: float) -> void:
	if sprite == null:
		return
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_amount", value)


func _update_visuals(delta: float, input_dir: Vector2) -> void:
	if sprite == null:
		return
	if not is_zero_approx(input_dir.x):
		sprite.flip_h = input_dir.x < 0.0
	if state == State.DASH:
		sprite.modulate = Color(0.55, 0.95, 1.0, 0.85)
		sprite.position = Vector2.ZERO
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_spawn_dash_ghost()
			_ghost_timer = 0.04
		return

	if hit_invuln_left > 0.0:
		var blink_on: bool = int(hit_invuln_left * 14.0) % 2 == 0
		sprite.modulate = Color(1.0, 0.45, 0.45, 0.7) if blink_on else Color.WHITE
	else:
		sprite.modulate = Color.WHITE

	if state == State.MOVE:
		_walk_time += delta * 14.0
		sprite.position = Vector2(0.0, -absf(sin(_walk_time)) * 3.0)
	else:
		_walk_time = 0.0
		sprite.position = Vector2.ZERO


func _spawn_dash_ghost() -> void:
	if sprite == null or sprite.texture == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.texture_filter = sprite.texture_filter
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.modulate = Color(0.45, 0.9, 1.0, 0.55)
	parent_node.add_child(ghost)
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)
