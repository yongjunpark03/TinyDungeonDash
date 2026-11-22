class_name Player
extends CharacterBody2D

@export var move_speed: float = 200.0


func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = compute_velocity(input_dir)
	move_and_slide()


func compute_velocity(input_dir: Vector2) -> Vector2:
	if input_dir == Vector2.ZERO:
		return Vector2.ZERO
	return input_dir.normalized() * move_speed
