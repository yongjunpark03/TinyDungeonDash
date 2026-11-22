class_name EnemyData
extends Resource

enum Behavior { BOUNCE, CHASE }

@export var display_name: String = "Enemy"
@export var behavior: Behavior = Behavior.BOUNCE
@export var speed: float = 160.0
@export var damage: int = 1
@export var max_hp: int = 2
@export var score_value: int = 2
@export var texture: Texture2D
