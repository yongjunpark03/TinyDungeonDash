class_name MagicOrb
extends Area2D

signal player_hit(damage: int)

@export var speed: float = 210.0
@export var damage: int = 1
@export var lifetime: float = 3.2

var direction: Vector2 = Vector2.RIGHT
var dungeon_map: DungeonMap
var release_callback: Callable = Callable()
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


func activate(origin: Vector2, dir: Vector2, map_ref: DungeonMap) -> void:
	position = origin
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	rotation = 0.0
	dungeon_map = map_ref
	_time_left = lifetime
	_consumed = false


func try_hit_player(player: Player) -> bool:
	if _consumed or player == null:
		return false
	_consumed = true
	player_hit.emit(damage)
	_finish()
	return true


func consume() -> void:
	if _consumed:
		return
	_consumed = true
	_finish()


func _finish() -> void:
	if release_callback.is_valid():
		release_callback.call(self)
	elif is_inside_tree():
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		try_hit_player(body as Player)
