extends GutTest


func test_zero_input_returns_zero_velocity() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	assert_eq(player.compute_velocity(Vector2.ZERO), Vector2.ZERO)


func test_cardinal_input_scales_by_move_speed() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	assert_eq(player.compute_velocity(Vector2.RIGHT), Vector2(200.0, 0.0))


func test_diagonal_input_is_normalized() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	var vel: Vector2 = player.compute_velocity(Vector2(1.0, 1.0))
	assert_almost_eq(vel.length(), 200.0, 0.01)


func test_custom_move_speed_is_respected() -> void:
	var player: Player = Player.new()
	player.move_speed = 350.0
	add_child_autofree(player)
	assert_eq(player.compute_velocity(Vector2.DOWN), Vector2(0.0, 350.0))
