class_name XpGem
extends Area2D

signal collected(xp_amount: int, gem_position: Vector2)

@export var xp_value: int = 1
@export var magnet_radius: float = 140.0
@export var collect_radius: float = 22.0
@export var pull_speed: float = 360.0

var target: Node2D
var release_callback: Callable = Callable()
var _collected: bool = false


func _ready() -> void:
	add_to_group("xp_gems")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	step_magnet(delta)


func activate(spawn_pos: Vector2, amount: int, target_node: Node2D) -> void:
	position = spawn_pos
	xp_value = amount
	target = target_node
	_collected = false


func step_magnet(delta: float) -> bool:
	if _collected or target == null:
		return false
	var dist: float = global_position.distance_to(target.global_position)
	if dist <= collect_radius:
		return collect()
	if dist <= magnet_radius:
		global_position = global_position.move_toward(target.global_position, pull_speed * delta)
		if global_position.distance_to(target.global_position) <= collect_radius:
			return collect()
	return false


func collect() -> bool:
	if _collected:
		return false
	_collected = true
	collected.emit(xp_value, global_position)
	if release_callback.is_valid():
		release_callback.call(self)
	elif is_inside_tree():
		queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect()
