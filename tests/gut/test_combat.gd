extends GutTest


func test_enemy_take_damage_reduces_hp_and_emits_died_at_zero() -> void:
	var slime_data: EnemyData = load("res://resources/enemy_slime.tres") as EnemyData
	var enemy: Enemy = Enemy.new()
	enemy.data = slime_data
	enemy.current_hp = enemy.get_max_hp()
	watch_signals(enemy)

	assert_eq(enemy.current_hp, 2)
	assert_true(enemy.take_damage(1, Vector2.RIGHT, 200.0))
	assert_eq(enemy.current_hp, 1)
	assert_false(enemy.is_dying)
	assert_signal_emitted_with_parameters(enemy, "damaged", [1, 1])

	assert_true(enemy.take_damage(1, Vector2.RIGHT, 200.0))
	assert_eq(enemy.current_hp, 0)
	assert_true(enemy.is_dying)
	assert_signal_emitted(enemy, "died")
	assert_false(enemy.take_damage(1))
	enemy.free()


func test_slash_projectile_hits_enemy_once_and_respects_pierce() -> void:
	var enemy1: Enemy = Enemy.new()
	enemy1.max_hp = 3
	enemy1.current_hp = 3
	var enemy2: Enemy = Enemy.new()
	enemy2.max_hp = 3
	enemy2.current_hp = 3
	var enemy3: Enemy = Enemy.new()
	enemy3.max_hp = 3
	enemy3.current_hp = 3

	var slash: SlashProjectile = SlashProjectile.new()
	slash.damage = 1
	slash.max_pierce = 2
	slash.direction = Vector2.RIGHT

	assert_true(slash.try_hit_enemy(enemy1))
	assert_false(slash.try_hit_enemy(enemy1), "Same enemy must not be hit twice by one slash")
	assert_true(slash.try_hit_enemy(enemy2))
	assert_false(slash.try_hit_enemy(enemy3), "Slash must stop hitting after max_pierce")

	assert_eq(enemy1.current_hp, 2)
	assert_eq(enemy2.current_hp, 2)
	assert_eq(enemy3.current_hp, 3)

	slash.free()
	enemy1.free()
	enemy2.free()
	enemy3.free()


func test_player_attack_timer_fires_toward_target_direction() -> void:
	var player: Player = Player.new()
	var stats: PlayerStats = PlayerStats.new()
	stats.attack_interval = 0.6
	stats.attack_damage = 2
	player.stats = stats
	player.attack_cooldown_left = 0.2
	watch_signals(player)

	assert_false(player.step_attack_timer(0.1, Vector2.UP))
	assert_true(player.step_attack_timer(0.15, Vector2(0.0, 5.0)))
	assert_signal_emitted_with_parameters(player, "attack_triggered", [Vector2.ZERO, Vector2.DOWN, 2])
	assert_almost_eq(player.attack_cooldown_left, 0.6, 0.001)
	player.free()
