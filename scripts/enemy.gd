class_name Enemy
extends Area2D

signal hit_player

@export var speed: float = 160.0
@export var margin: float = 16.0

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	add_to_group("enemies")
	var angle: float = randf_range(0.0, TAU)
	direction = Vector2.from_angle(angle)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	var screen_size: Vector2 = get_viewport_rect().size
	if position.x <= margin or position.x >= screen_size.x - margin:
		direction.x = -direction.x
		position.x = clampf(position.x, margin, screen_size.x - margin)
	if position.y <= margin or position.y >= screen_size.y - margin:
		direction.y = -direction.y
		position.y = clampf(position.y, margin, screen_size.y - margin)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		hit_player.emit()