extends GutTest


func test_add_xp_levels_up_and_scales_threshold() -> void:
	var manager: UpgradeManager = UpgradeManager.new()
	assert_eq(manager.level, 1)
	assert_eq(manager.xp_to_next, 3)

	assert_eq(manager.add_xp(2), 0)
	assert_eq(manager.current_xp, 2)
	assert_eq(manager.add_xp(1), 1)
	assert_eq(manager.level, 2)
	assert_eq(manager.current_xp, 0)
	assert_eq(manager.xp_to_next, 5)


func test_roll_choices_returns_three_distinct_upgrades() -> void:
	var manager: UpgradeManager = UpgradeManager.new()
	var choices: Array[Dictionary] = manager.roll_choices(3)
	assert_eq(choices.size(), 3)
	var seen_ids: Array[String] = []
	for item in choices:
		var uid: String = str(item.get("id", ""))
		assert_false(uid.is_empty())
		assert_false(seen_ids.has(uid), "Rolled upgrade choices must be distinct")
		seen_ids.append(uid)


func test_apply_upgrade_modifies_player_and_manager_stats() -> void:
	var manager: UpgradeManager = UpgradeManager.new()
	var player: Player = Player.new()
	player.current_hp = 2

	assert_true(manager.apply_upgrade("power_slash", player))
	assert_eq(player.damage_bonus, 1)

	assert_true(manager.apply_upgrade("twin_slash", player))
	assert_eq(manager.bonus_pierce, 1)
	assert_gt(manager.slash_scale_bonus, 1.0)

	assert_true(manager.apply_upgrade("vital_heart", player))
	assert_eq(player.get_max_hp(), 4)
	assert_eq(player.current_hp, 3)
	assert_false(manager.apply_upgrade("nonexistent_upgrade", player))
	player.free()


func test_xp_gem_magnet_pulls_and_auto_collects_near_target() -> void:
	var target_node: Node2D = Node2D.new()
	target_node.position = Vector2(100.0, 0.0)
	var gem: XpGem = XpGem.new()
	gem.position = Vector2.ZERO
	gem.target = target_node
	gem.magnet_radius = 150.0
	gem.collect_radius = 20.0
	gem.pull_speed = 300.0
	watch_signals(gem)

	assert_false(gem.step_magnet(0.2))
	assert_gt(gem.position.x, 50.0, "Gem should pull toward target inside magnet_radius")
	assert_true(gem.step_magnet(0.2), "Gem should auto-collect when reaching collect_radius")
	assert_signal_emitted_with_parameters(gem, "collected", [1, gem.position])

	gem.free()
	target_node.free()
