extends GutTest


func test_enemy_data_overrides_speed_and_damage() -> void:
	var enemy: Enemy = Enemy.new()
	var custom_data: EnemyData = EnemyData.new()
	custom_data.speed = 240.0
	custom_data.damage = 2
	enemy.data = custom_data
	add_child_autofree(enemy)
	assert_eq(enemy.get_effective_speed(), 240.0)
	assert_eq(enemy.get_effective_damage(), 2)


func test_chase_behavior_steers_toward_target() -> void:
	var enemy: Enemy = Enemy.new()
	var slime_data: EnemyData = EnemyData.new()
	slime_data.behavior = EnemyData.Behavior.CHASE
	enemy.data = slime_data
	add_child_autofree(enemy)
	var desired: Vector2 = enemy.compute_desired_direction(Vector2(100.0, 100.0), Vector2(200.0, 100.0))
	assert_almost_eq(desired.x, 1.0, 0.001)
	assert_almost_eq(desired.y, 0.0, 0.001)


func test_bounce_behavior_preserves_current_direction() -> void:
	var enemy: Enemy = Enemy.new()
	var bat_data: EnemyData = EnemyData.new()
	bat_data.behavior = EnemyData.Behavior.BOUNCE
	enemy.data = bat_data
	add_child_autofree(enemy)
	enemy.direction = Vector2(0.0, 1.0)
	var desired: Vector2 = enemy.compute_desired_direction(Vector2(100.0, 100.0), Vector2(500.0, 100.0))
	assert_eq(desired, Vector2(0.0, 1.0))


func test_speed_multiplier_scales_effective_speed() -> void:
	var enemy: Enemy = Enemy.new()
	enemy.speed = 100.0
	enemy.set_speed_multiplier(1.5)
	add_child_autofree(enemy)
	assert_almost_eq(enemy.get_effective_speed(), 150.0, 0.001)
