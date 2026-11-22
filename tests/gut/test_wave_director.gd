extends GutTest


func test_initial_wave_and_multiplier() -> void:
	var director: WaveDirector = WaveDirector.new()
	assert_eq(director.wave, 1)
	assert_eq(director.get_multiplier(), 1)
	assert_almost_eq(director.get_enemy_speed_scale(), 1.0, 0.001)


func test_combo_ramps_multiplier_up_to_cap() -> void:
	var director: WaveDirector = WaveDirector.new()
	for _i in range(10):
		director.register_coin_pickup()
	assert_eq(director.get_multiplier(), WaveDirector.MAX_MULTIPLIER)


func test_combo_expires_after_window() -> void:
	var director: WaveDirector = WaveDirector.new()
	director.register_coin_pickup()
	director.register_coin_pickup()
	assert_eq(director.get_multiplier(), 2)
	assert_false(director.tick(1.0))
	assert_true(director.tick(3.0))
	assert_eq(director.get_multiplier(), 1)


func test_reset_combo_clears_count_and_timer() -> void:
	var director: WaveDirector = WaveDirector.new()
	director.register_coin_pickup()
	director.register_coin_pickup()
	assert_eq(director.get_multiplier(), 2)
	director.reset_combo()
	assert_eq(director.combo_count, 0)
	assert_eq(director.combo_time_left, 0.0)
	assert_eq(director.get_multiplier(), 1)


func test_wave_advances_every_four_coins_and_scales_speed() -> void:
	var director: WaveDirector = WaveDirector.new()
	for i in range(3):
		var step: Dictionary = director.register_coin_pickup()
		assert_false(bool(step["wave_advanced"]), "Wave must not advance before coin 4 (index %d)" % i)
	var fourth: Dictionary = director.register_coin_pickup()
	assert_true(bool(fourth["wave_advanced"]))
	assert_eq(int(fourth["wave"]), 2)
	assert_gt(director.get_enemy_speed_scale(), 1.0)
