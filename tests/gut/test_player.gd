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


func test_player_stats_resource_overrides_move_speed() -> void:
	var player: Player = Player.new()
	var custom_stats: PlayerStats = PlayerStats.new()
	custom_stats.move_speed = 300.0
	player.stats = custom_stats
	add_child_autofree(player)
	assert_eq(player.compute_velocity(Vector2.LEFT), Vector2(-300.0, 0.0))


func test_dash_transitions_state_and_grants_invulnerability() -> void:
	var player: Player = Player.new()
	var custom_stats: PlayerStats = PlayerStats.new()
	custom_stats.dash_speed = 500.0
	player.stats = custom_stats
	add_child_autofree(player)
	assert_false(player.is_invulnerable())
	var started: bool = player.try_start_dash(Vector2.UP)
	assert_true(started)
	assert_eq(player.state, Player.State.DASH)
	assert_true(player.is_invulnerable())
	assert_eq(player.compute_velocity(Vector2.ZERO), Vector2(0.0, -500.0))


func test_dash_cannot_retrigger_during_cooldown() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	assert_true(player.try_start_dash(Vector2.RIGHT))
	assert_false(player.try_start_dash(Vector2.LEFT))


func test_dash_ends_and_recovers_cooldown_over_time() -> void:
	var player: Player = Player.new()
	var custom_stats: PlayerStats = PlayerStats.new()
	custom_stats.dash_duration = 0.2
	custom_stats.dash_cooldown = 1.0
	player.stats = custom_stats
	add_child_autofree(player)
	assert_true(player.try_start_dash(Vector2.RIGHT))
	player.step_dash_timers(0.25)
	assert_eq(player.state, Player.State.IDLE)
	assert_false(player.is_invulnerable())
	assert_false(player.can_dash())
	player.step_dash_timers(0.8)
	assert_true(player.can_dash())


func test_take_damage_reduces_hp_and_triggers_invulnerability() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	assert_eq(player.current_hp, 3)
	assert_true(player.take_damage(1))
	assert_eq(player.current_hp, 2)
	assert_true(player.is_invulnerable())
	assert_false(player.take_damage(1), "I-frames must block immediate repeat hit")
	player.step_dash_timers(1.1)
	assert_false(player.is_invulnerable())
	assert_true(player.take_damage(1))
	assert_eq(player.current_hp, 1)


func test_dash_blocks_damage() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	assert_true(player.try_start_dash(Vector2.RIGHT))
	assert_false(player.take_damage(1))
	assert_eq(player.current_hp, 3)


func test_zero_hp_emits_died_signal() -> void:
	var player: Player = Player.new()
	add_child_autofree(player)
	watch_signals(player)
	assert_true(player.take_damage(3))
	assert_eq(player.current_hp, 0)
	assert_signal_emitted(player, "died")
