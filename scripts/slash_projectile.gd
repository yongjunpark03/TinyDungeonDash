class_name SlashProjectile
extends Area2D

signal enemy_hit(enemy: Enemy, damage: int, hit_position: Vector2)

@export var speed: float = 420.0
@export var damage: int = 1
@export var lifetime: float = 0.42
@export var knockback_force: float = 240.0
@export var max_pierce: int = 2

var direction: Vector2 = Vector2.RIGHT
var release_callback: Callable = Callable()
var _time_left: float = 0.42
var _hit_count: int = 0
var _hit_enemies: Array[Enemy] = []


func _ready() -> void:
	_time_left = lifetime
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()


func activate(origin: Vector2, dir: Vector2, dmg: int, pierce: int, scale_mult: float) -> void:
	position = origin
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
	damage = dmg
	max_pierce = pierce
	scale = Vector2.ONE * scale_mult
	_time_left = lifetime
	_hit_count = 0
	_hit_enemies.clear()


func try_hit_enemy(enemy: Enemy) -> bool:
	if enemy == null or enemy.is_dying or _hit_enemies.has(enemy) or _hit_count >= max_pierce:
		return false
	if not enemy.take_damage(damage, direction, knockback_force):
		return false
	_hit_enemies.append(enemy)
	_hit_count += 1
	enemy_hit.emit(enemy, damage, enemy.global_position)
	if _hit_count >= max_pierce:
		_finish()
	return true


func _finish() -> void:
	if release_callback.is_valid():
		release_callback.call(self)
	elif is_inside_tree():
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area is Enemy:
		try_hit_enemy(area as Enemy)
