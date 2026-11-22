class_name MagicOrb
extends Area2D

signal player_hit(damage: int)

@export var speed: float = 210.0
@export var damage: int = 1
@export var lifetime: float = 3.2

var direction: Vector2 = Vector2.RIGHT
var dungeon_map: DungeonMap
var _time_left: float = 3.2
var _consumed: bool = false


func _ready() -> void:
	add_to_group("enemy_projectiles")
	_time_left = lifetime
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	position += direction * speed * delta
	rotation += delta * 6.0
	_time_left -= delta
	if dungeon_map != null and dungeon_map.is_wall_at_world(position):
		consume()
		return
	if _time_left <= 0.0:
		consume()


func try_hit_player(player: Player) -> bool:
	if _consumed or player == null:
		return false
	_consumed = true
	player_hit.emit(damage)
	if is_inside_tree():
		queue_free()
	return true


func consume() -> void:
	_consumed = true
	if is_inside_tree():
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		try_hit_player(body as Player)
