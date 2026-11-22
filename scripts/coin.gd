class_name Coin
extends Area2D

signal collected(coin_position: Vector2)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collected.emit(global_position)
		queue_free()