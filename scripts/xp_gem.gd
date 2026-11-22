class_name XpGem
extends Area2D

signal collected(xp_amount: int, gem_position: Vector2)

@export var xp_value: int = 1
@export var magnet_radius: float = 140.0
@export var collect_radius: float = 22.0
@export var pull_speed: float = 360.0

var target: Node2D
var _collected: bool = false


func _ready() -> void:
	add_to_group("xp_gems")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	step_magnet(delta)


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
	if is_inside_tree():
		queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect()
