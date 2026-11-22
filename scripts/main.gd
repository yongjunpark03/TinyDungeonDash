extends Node2D

const HIT_SPARK_TEXTURE: Texture2D = preload("res://assets/custom/hit_spark.png")

@export var coin_scene: PackedScene
@export var enemy_scene: PackedScene
@export var coin_burst_scene: PackedScene
@export var slash_scene: PackedScene
@export var xp_gem_scene: PackedScene
@export var magic_orb_scene: PackedScene
@export var bat_data: EnemyData
@export var slime_data: EnemyData
@export var boss_data: EnemyData
@export var spawn_margin: float = 48.0
@export var game_duration: int = 30

var score: int = 0
var high_score: int = 0
var time_left: int = 0
var kills: int = 0
var is_game_over: bool = false
var coin_sfx: AudioStreamWAV
var gameover_sfx: AudioStreamWAV
var dash_sfx: AudioStreamWAV
var hit_sfx: AudioStreamWAV
var wave_sfx: AudioStreamWAV
var slash_sfx: AudioStreamWAV
var enemy_hit_sfx: AudioStreamWAV
var enemy_kill_sfx: AudioStreamWAV
var xp_sfx: AudioStreamWAV
var levelup_sfx: AudioStreamWAV
var boss_spawn_sfx: AudioStreamWAV
var orb_cast_sfx: AudioStreamWAV
var director: WaveDirector = WaveDirector.new()
var upgrade_manager: UpgradeManager = UpgradeManager.new()
var _spawned_enemies: int = 0
var _active_boss: Enemy

@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var score_label: Label = $HUD/TopMargin/TopBar/LeftStats/ScoreLabel
@onready var time_label: Label = $HUD/TopMargin/TopBar/LeftStats/TimeLabel
@onready var best_label: Label = $HUD/TopMargin/TopBar/LeftStats/BestLabel
@onready var dash_label: Label = $HUD/TopMargin/TopBar/LeftStats/DashLabel
@onready var hp_label: Label = $HUD/TopMargin/TopBar/LeftStats/HpLabel
@onready var wave_label: Label = $HUD/TopMargin/TopBar/RightStats/WaveLabel
@onready var level_label: Label = $HUD/TopMargin/TopBar/RightStats/LevelLabel
@onready var torch_vignette: ColorRect = $HUD/TorchVignette
@onready var boss_bar_panel: PanelContainer = $HUD/BossBarPanel
@onready var boss_name_label: Label = $HUD/BossBarPanel/MarginContainer/VBoxContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $HUD/BossBarPanel/MarginContainer/VBoxContainer/BossHpBar
@onready var pause_overlay: PauseMenu = $HUD/PauseOverlay
@onready var level_up_overlay: LevelUpMenu = $HUD/LevelUpOverlay
@onready var result_overlay: Control = $HUD/ResultOverlay
@onready var result_title_label: Label = (
	$HUD/ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResultTitle
)
@onready var result_summary_label: Label = (
	$HUD/ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResultSummaryLabel
)
@onready var result_best_label: Label = (
	$HUD/ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResultBestLabel
)
@onready var restart_button: Button = (
	$HUD/ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/RestartButton
)
@onready var result_title_button: Button = (
	$HUD/ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/ResultTitleButton
)
@onready var game_timer: Timer = $GameTimer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer


func _ready() -> void:
	get_tree().paused = false
	high_score = _get_high_score()
	coin_sfx = SfxFactory.create_tone(880.0, 1320.0, 0.2, 0.7)
	gameover_sfx = SfxFactory.create_tone(330.0, 110.0, 0.45, 0.7)
	dash_sfx = SfxFactory.create_tone(260.0, 620.0, 0.12, 0.55)
	hit_sfx = SfxFactory.create_tone(220.0, 130.0, 0.16, 0.65)
	wave_sfx = SfxFactory.create_tone(523.25, 1046.5, 0.28, 0.65)
	slash_sfx = SfxFactory.create_tone(540.0, 240.0, 0.09, 0.4)
	enemy_hit_sfx = SfxFactory.create_tone(320.0, 480.0, 0.08, 0.5)
	enemy_kill_sfx = SfxFactory.create_tone(440.0, 880.0, 0.16, 0.6)
	xp_sfx = SfxFactory.create_tone(660.0, 990.0, 0.1, 0.45)
	levelup_sfx = SfxFactory.create_tone(440.0, 1180.0, 0.32, 0.7)
	boss_spawn_sfx = SfxFactory.create_tone(180.0, 95.0, 0.42, 0.75)
	orb_cast_sfx = SfxFactory.create_tone(420.0, 210.0, 0.12, 0.45)
	sfx_player.max_polyphony = 6
	time_left = game_duration
	boss_bar_panel.visible = false
	result_overlay.visible = false
	pause_overlay.can_pause = true
	pause_overlay.title_requested.connect(_on_title_pressed)
	level_up_overlay.upgrade_selected.connect(_on_upgrade_selected)
	restart_button.pressed.connect(_on_restart_pressed)
	result_title_button.pressed.connect(_on_title_pressed)
	game_timer.timeout.connect(_on_game_timer_timeout)
	player.dash_started.connect(_on_player_dash_started)
	player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	player.health_changed.connect(_on_player_health_changed)
	player.attack_triggered.connect(_on_player_attack_triggered)
	player.died.connect(_on_player_died)
	dash_label.text = "Dash [Space]: READY"
	_on_player_health_changed(player.current_hp, player.get_max_hp())
	_update_hud()
	_update_wave_label()
	_update_level_label()
	_update_torch_vignette()
	_spawn_coin()
	_spawn_enemy()
	game_timer.start()


func _process(delta: float) -> void:
	_update_torch_vignette()
	if is_game_over:
		return
	player.step_attack_timer(delta, _find_nearest_enemy_direction())
	if director.tick(delta) or director.combo_count > 0:
		_update_wave_label()


static func compute_light_uv(world_pos: Vector2, viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return Vector2(
		clampf(world_pos.x / viewport_size.x, 0.0, 1.0),
		clampf(world_pos.y / viewport_size.y, 0.0, 1.0)
	)


func _spawn_coin() -> void:
	if coin_scene == null or is_game_over:
		return
	var coin: Coin = coin_scene.instantiate() as Coin
	coin.position = dungeon_map.get_random_floor_position(player.position, 96.0)
	coin.collected.connect(_on_coin_collected)
	add_child.call_deferred(coin)


func _spawn_enemy() -> void:
	if enemy_scene == null or is_game_over:
		return
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	var chosen_data: EnemyData = bat_data if (_spawned_enemies % 2 == 0) else slime_data
	if chosen_data != null:
		enemy.data = chosen_data
	enemy.dungeon_map = dungeon_map
	enemy.target = player
	enemy.speed_multiplier = director.get_enemy_speed_scale()
	enemy.position = dungeon_map.get_random_floor_position(player.position, 180.0)
	enemy.hit_player.connect(_on_player_hit)
	enemy.died.connect(_on_enemy_died)
	_spawned_enemies += 1
	add_child.call_deferred(enemy)


func _spawn_boss() -> void:
	if enemy_scene == null or is_game_over or _active_boss != null:
		return
	var boss: Enemy = enemy_scene.instantiate() as Enemy
	boss.is_boss = true
	if boss_data != null:
		boss.data = boss_data
	boss.dungeon_map = dungeon_map
	boss.target = player
	boss.speed_multiplier = director.get_enemy_speed_scale()
	boss.position = dungeon_map.get_random_floor_position(player.position, 220.0)
	boss.hit_player.connect(_on_player_hit)
	boss.damaged.connect(_on_boss_damaged)
	boss.cast_orbs.connect(_on_boss_cast_orbs)
	boss.died.connect(_on_boss_died)
	_active_boss = boss
	add_child.call_deferred(boss)
	_play_sfx(boss_spawn_sfx)
	_spawn_floating_text(player.global_position, "BOSS APPEARED!", Color(1.0, 0.4, 0.5, 1.0))
	_update_boss_bar(boss.get_max_hp(), boss.get_max_hp())
	boss_bar_panel.visible = true


func _spawn_coin_burst(burst_position: Vector2) -> void:
	if coin_burst_scene == null:
		return
	var burst: CoinBurst = coin_burst_scene.instantiate() as CoinBurst
	burst.position = burst_position
	add_child.call_deferred(burst)


func _spawn_xp_gem(spawn_pos: Vector2, xp_amount: int) -> void:
	if xp_gem_scene == null or is_game_over:
		return
	var gem: XpGem = xp_gem_scene.instantiate() as XpGem
	gem.position = spawn_pos
	gem.xp_value = xp_amount
	gem.target = player
	gem.collected.connect(_on_xp_gem_collected)
	add_child.call_deferred(gem)


func _on_player_attack_triggered(origin: Vector2, aim_direction: Vector2, damage: int) -> void:
	if slash_scene == null or is_game_over:
		return
	var slash: SlashProjectile = slash_scene.instantiate() as SlashProjectile
	slash.position = origin + aim_direction * 22.0
	slash.direction = aim_direction
	slash.damage = damage
	slash.max_pierce = 2 + upgrade_manager.bonus_pierce
	slash.scale = Vector2.ONE * upgrade_manager.slash_scale_bonus
	slash.enemy_hit.connect(_on_slash_enemy_hit)
	add_child.call_deferred(slash)
	_play_sfx(slash_sfx)


func _on_slash_enemy_hit(_enemy: Enemy, damage: int, hit_pos: Vector2) -> void:
	_play_sfx(enemy_hit_sfx)
	_spawn_hit_spark(hit_pos)
	_spawn_floating_text(hit_pos, "-%d" % damage, Color(1.0, 0.92, 0.45, 1.0))


func _on_enemy_died(enemy_pos: Vector2, score_reward: int) -> void:
	if is_game_over:
		return
	kills += 1
	score += score_reward
	_update_high_score(score)
	high_score = maxi(high_score, _get_high_score())
	_play_sfx(enemy_kill_sfx)
	_spawn_floating_text(enemy_pos, "KILL +%d" % score_reward, Color(0.45, 1.0, 0.65, 1.0))
	_spawn_xp_gem(enemy_pos, maxi(1, score_reward - 1))
	_register_kill_with_manager(false)
	_pulse_score_label()
	_update_hud()
	get_tree().create_timer(1.0).timeout.connect(_spawn_enemy)


func _on_boss_damaged(remaining_hp: int, _damage_taken: int) -> void:
	if _active_boss == null:
		return
	_update_boss_bar(remaining_hp, _active_boss.get_max_hp())


func _on_boss_cast_orbs(origin: Vector2, directions: Array[Vector2]) -> void:
	if magic_orb_scene == null or is_game_over:
		return
	for dir in directions:
		var orb: MagicOrb = magic_orb_scene.instantiate() as MagicOrb
		orb.position = origin
		orb.direction = dir
		orb.dungeon_map = dungeon_map
		orb.player_hit.connect(_on_player_hit)
		add_child.call_deferred(orb)
	_play_sfx(orb_cast_sfx)


func _on_boss_died(boss_pos: Vector2, score_reward: int) -> void:
	_active_boss = null
	boss_bar_panel.visible = false
	if is_game_over:
		return
	kills += 1
	time_left += 6
	score += score_reward
	_update_high_score(score)
	high_score = maxi(high_score, _get_high_score())
	_play_sfx(wave_sfx)
	_spawn_floating_text(boss_pos, "BOSS SLAIN! +%d (+6s)" % score_reward, Color(1.0, 0.88, 0.35, 1.0))
	for i in range(3):
		var offset: Vector2 = Vector2.from_angle(float(i) * TAU / 3.0) * 20.0
		_spawn_xp_gem(boss_pos + offset, 2)
	_register_kill_with_manager(true)
	_pulse_score_label()
	_update_hud()


func _on_xp_gem_collected(xp_amount: int, gem_pos: Vector2) -> void:
	if is_game_over:
		return
	_play_sfx(xp_sfx)
	_spawn_floating_text(gem_pos, "+%d XP" % xp_amount, Color(0.45, 1.0, 0.8, 1.0))
	_gain_xp(xp_amount)


func _gain_xp(xp_amount: int) -> void:
	var gained: int = upgrade_manager.add_xp(xp_amount)
	_update_level_label()
	if upgrade_manager.level >= 3:
		_try_unlock_achievement("veteran_knight")
	if gained > 0 and not is_game_over:
		_play_sfx(levelup_sfx)
		pause_overlay.can_pause = false
		level_up_overlay.present_choices(upgrade_manager.level, upgrade_manager.roll_choices(3))


func _on_upgrade_selected(upgrade_id: String) -> void:
	upgrade_manager.apply_upgrade(upgrade_id, player)
	pause_overlay.can_pause = not is_game_over
	_spawn_floating_text(player.global_position, "UPGRADE!", Color(1.0, 0.9, 0.35, 1.0))
	_update_level_label()


func _on_coin_collected(coin_position: Vector2) -> void:
	if is_game_over:
		return
	var result: Dictionary = director.register_coin_pickup()
	score += int(result["points"])
	_update_high_score(score)
	high_score = maxi(high_score, _get_high_score())
	_play_sfx(coin_sfx)
	_spawn_coin_burst(coin_position)
	_pulse_score_label()
	_spawn_coin()
	if bool(result["wave_advanced"]):
		time_left += 3
		_play_sfx(wave_sfx)
		get_tree().call_group("enemies", "set_speed_multiplier", director.get_enemy_speed_scale())
		_spawn_enemy()
		_pulse_wave_label()
		if director.wave % 2 == 0 and _active_boss == null:
			_spawn_boss()
	_update_hud()
	_update_wave_label()
	if director.get_multiplier() >= WaveDirector.MAX_MULTIPLIER:
		_try_unlock_achievement("combo_master")
	_gain_xp(1)


func _on_player_hit(damage: int) -> void:
	if is_game_over:
		return
	if not player.take_damage(damage):
		return
	director.reset_combo()
	_update_wave_label()
	_shake_camera()
	if player.current_hp > 0:
		_play_sfx(hit_sfx)


func _on_player_died() -> void:
	if not is_game_over:
		_end_game("GAME OVER")


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]


func _on_player_dash_started() -> void:
	_play_sfx(dash_sfx)


func _on_dash_cooldown_changed(remaining: float, _duration: float) -> void:
	if remaining <= 0.0:
		dash_label.text = "Dash [Space]: READY"
		dash_label.modulate = Color(0.55, 0.95, 1.0, 1.0)
	else:
		dash_label.text = "Dash [Space]: %.1fs" % remaining
		dash_label.modulate = Color(0.7, 0.7, 0.75, 1.0)


func _on_game_timer_timeout() -> void:
	time_left -= 1
	_update_hud()
	if time_left <= 0:
		_end_game("TIME'S UP!")


func _end_game(title_text: String) -> void:
	is_game_over = true
	pause_overlay.can_pause = false
	pause_overlay.set_paused(false)
	level_up_overlay.visible = false
	game_timer.stop()
	player.set_physics_process(false)
	get_tree().call_group("enemies", "set_physics_process", false)
	get_tree().call_group("enemy_projectiles", "set_physics_process", false)
	_play_sfx(gameover_sfx)
	var is_new_best: bool = _record_run_result(score, director.wave, title_text)
	high_score = maxi(high_score, _get_high_score())
	_update_hud()
	result_title_label.text = title_text
	result_summary_label.text = "Score: %d  |  Wave: %d" % [score, director.wave]
	result_best_label.text = ("NEW BEST! %d" % high_score) if is_new_best else ("Best: %d" % high_score)
	result_overlay.visible = true
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().paused = false
	var gm: Node = _get_game_manager()
	if gm != null:
		gm.call("go_to_title")
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _find_nearest_enemy_direction() -> Vector2:
	var best_dir: Vector2 = player.facing_direction
	var best_dist_sq: float = 420.0 * 420.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dying:
			continue
		var delta_pos: Vector2 = enemy.global_position - player.global_position
		var dist_sq: float = delta_pos.length_squared()
		if dist_sq > 0.0 and dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_dir = delta_pos.normalized()
	return best_dir


func _spawn_hit_spark(world_pos: Vector2) -> void:
	var spark: Sprite2D = Sprite2D.new()
	spark.texture = HIT_SPARK_TEXTURE
	spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spark.global_position = world_pos
	spark.scale = Vector2(2.0, 2.0)
	add_child(spark)
	var tween: Tween = spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(3.2, 3.2), 0.16)
	tween.tween_property(spark, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(spark.queue_free)


func _spawn_floating_text(world_pos: Vector2, text_value: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.global_position = world_pos + Vector2(-24.0, -32.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 26.0, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(label.queue_free)


func _update_boss_bar(current_hp: int, max_hp: int) -> void:
	var title: String = boss_data.display_name if boss_data != null else "Necro Lord"
	boss_name_label.text = "BOSS: %s (%d / %d)" % [title, maxi(0, current_hp), max_hp]
	boss_hp_bar.max_value = float(max_hp)
	boss_hp_bar.value = float(maxi(0, current_hp))


func _update_torch_vignette() -> void:
	if torch_vignette == null or player == null:
		return
	var mat: ShaderMaterial = torch_vignette.material as ShaderMaterial
	if mat == null:
		return
	var light_uv: Vector2 = compute_light_uv(player.global_position, get_viewport_rect().size)
	mat.set_shader_parameter("light_uv", light_uv)


func _play_sfx(stream: AudioStreamWAV) -> void:
	sfx_player.stream = stream
	sfx_player.play()


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_high_score() -> int:
	var gm: Node = _get_game_manager()
	if gm != null:
		return int(gm.get("high_score"))
	return high_score


func _update_high_score(new_score: int) -> bool:
	var gm: Node = _get_game_manager()
	if gm != null:
		return bool(gm.call("update_high_score", new_score))
	if new_score > high_score:
		high_score = new_score
		return true
	return false


func _record_run_result(final_score: int, final_wave: int, reason: String) -> bool:
	var gm: Node = _get_game_manager()
	if gm != null:
		return bool(gm.call("record_run_result", final_score, final_wave, reason))
	return _update_high_score(final_score)


func _register_kill_with_manager(is_boss_enemy: bool) -> void:
	var gm: Node = _get_game_manager()
	if gm == null:
		return
	var unlocked: Array = gm.call("register_kill", is_boss_enemy) as Array
	for title_val in unlocked:
		var toast_pos: Vector2 = player.global_position + Vector2(0.0, -24.0)
		_spawn_floating_text(toast_pos, "★ 업적: %s" % str(title_val), Color(1.0, 0.85, 0.25, 1.0))


func _try_unlock_achievement(achievement_id: String) -> void:
	var gm: Node = _get_game_manager()
	if gm == null:
		return
	var title: String = str(gm.call("unlock_achievement", achievement_id))
	if not title.is_empty():
		var toast_pos: Vector2 = player.global_position + Vector2(0.0, -24.0)
		_spawn_floating_text(toast_pos, "★ 업적: %s" % title, Color(1.0, 0.85, 0.25, 1.0))


func _pulse_score_label() -> void:
	var tween: Tween = create_tween()
	score_label.scale = Vector2(1.25, 1.25)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.15)


func _pulse_wave_label() -> void:
	var tween: Tween = create_tween()
	wave_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(wave_label, "scale", Vector2.ONE, 0.2)


func _shake_camera() -> void:
	var tween: Tween = create_tween()
	for _i in range(6):
		var shake_offset: Vector2 = Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		tween.tween_property(camera, "offset", shake_offset, 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


func _update_hud() -> void:
	score_label.text = "Score: %d" % score
	time_label.text = "Time: %d" % time_left
	best_label.text = "Best: %d" % high_score


func _update_wave_label() -> void:
	var mult: int = director.get_multiplier()
	if mult > 1 or director.combo_count > 0:
		wave_label.text = "Wave %d | Combo x%d (%.1fs)" % [director.wave, mult, director.combo_time_left]
	else:
		wave_label.text = "Wave %d | Combo x1" % director.wave


func _update_level_label() -> void:
	level_label.text = "Lv.%d | XP %d / %d" % [
		upgrade_manager.level,
		upgrade_manager.current_xp,
		upgrade_manager.xp_to_next,
	]
