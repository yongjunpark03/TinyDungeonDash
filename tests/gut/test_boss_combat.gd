extends GutTest


func test_boss_fan_and_nova_patterns_produce_expected_directions() -> void:
	var boss: Enemy = Enemy.new()
	var fan_dirs: Array[Vector2] = boss.compute_boss_pattern_directions(Vector2.RIGHT, 0)
	assert_eq(fan_dirs.size(), 3)
	assert_almost_eq(fan_dirs[1].x, 1.0, 0.001)
	assert_almost_eq(fan_dirs[1].y, 0.0, 0.001)

	var nova_dirs: Array[Vector2] = boss.compute_boss_pattern_directions(Vector2.RIGHT, 1)
	assert_eq(nova_dirs.size(), 6)
	boss.free()


func test_boss_step_cast_alternates_patterns_on_cooldown() -> void:
	var boss: Enemy = Enemy.new()
	boss.is_boss = true
	boss.boss_fire_interval = 2.0
	boss.boss_cast_cooldown = 0.5
	watch_signals(boss)

	assert_eq(boss.step_boss_cast(0.25).size(), 0)
	var first_cast: Array[Vector2] = boss.step_boss_cast(0.3)
	assert_eq(first_cast.size(), 3)
	assert_signal_emitted(boss, "cast_orbs")

	var second_cast: Array[Vector2] = boss.step_boss_cast(2.05)
	assert_eq(second_cast.size(), 6)
	boss.free()


func test_magic_orb_hits_player_once_and_emits_damage() -> void:
	var player: Player = Player.new()
	var orb: MagicOrb = MagicOrb.new()
	orb.damage = 2
	watch_signals(orb)

	assert_true(orb.try_hit_player(player))
	assert_signal_emitted_with_parameters(orb, "player_hit", [2])
	assert_false(orb.try_hit_player(player), "Consumed magic orb must not hit twice")

	orb.free()
	player.free()
