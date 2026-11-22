extends Node2D

const SAVE_PATH: String = "user://high_score.cfg"

@export var coin_scene: PackedScene
@export var enemy_scene: PackedScene
@export var coin_burst_scene: PackedScene
@export var spawn_margin: float = 48.0
@export var game_duration: int = 20

var score: int = 0
var high_score: int = 0
var time_left: int = 0
var is_game_over: bool = false
var coin_sfx: AudioStreamWAV
var gameover_sfx: AudioStreamWAV

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var score_label: Label = $HUD/ScoreLabel
@onready var time_label: Label = $HUD/TimeLabel
@onready var best_label: Label = $HUD/BestLabel
@onready var restart_button: Button = $HUD/RestartButton
@onready var game_timer: Timer = $GameTimer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer


func _ready() -> void:
	high_score = _load_high_score()
	coin_sfx = SfxFactory.create_tone(880.0, 1320.0, 0.2, 0.7)
	gameover_sfx = SfxFactory.create_tone(330.0, 110.0, 0.45, 0.7)
	sfx_player.max_polyphony = 4
	_start_audio_keepalive()
	time_left = game_duration
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	game_timer.timeout.connect(_on_game_timer_timeout)
	_update_hud()
	_spawn_coin()
	_spawn_enemy()
	game_timer.start()


func _spawn_coin() -> void:
	if coin_scene == null or is_game_over:
		return
	var coin: Coin = coin_scene.instantiate() as Coin
	coin.position = _random_screen_position()
	coin.collected.connect(_on_coin_collected)
	add_child.call_deferred(coin)


func _spawn_enemy() -> void:
	if enemy_scene == null or is_game_over:
		return
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	var spawn_pos: Vector2 = _random_screen_position()
	for _attempt in range(10):
		if spawn_pos.distance_to(player.position) >= 180.0:
			break
		spawn_pos = _random_screen_position()
	enemy.position = spawn_pos
	enemy.hit_player.connect(_on_player_hit)
	add_child.call_deferred(enemy)


func _spawn_coin_burst(burst_position: Vector2) -> void:
	if coin_burst_scene == null:
		return
	var burst: CoinBurst = coin_burst_scene.instantiate() as CoinBurst
	burst.position = burst_position
	add_child.call_deferred(burst)


func _random_screen_position() -> Vector2:
	var screen_size: Vector2 = get_viewport_rect().size
	return Vector2(
		randf_range(spawn_margin, screen_size.x - spawn_margin),
		randf_range(spawn_margin, screen_size.y - spawn_margin)
	)


func _on_coin_collected(coin_position: Vector2) -> void:
	if is_game_over:
		return
	score += 1
	if score > high_score:
		high_score = score
		_save_high_score(high_score)
	_play_sfx(coin_sfx)
	_update_hud()
	_spawn_coin_burst(coin_position)
	_pulse_score_label()
	_spawn_coin()
	if score % 3 == 0:
		_spawn_enemy()


func _on_player_hit() -> void:
	if is_game_over:
		return
	_shake_camera()
	_end_game("Game Over! Final Score: %d" % score)


func _on_game_timer_timeout() -> void:
	time_left -= 1
	_update_hud()
	if time_left <= 0:
		_end_game("Time's Up! Final Score: %d" % score)


func _end_game(message: String) -> void:
	is_game_over = true
	game_timer.stop()
	player.set_physics_process(false)
	get_tree().call_group("enemies", "set_physics_process", false)
	_play_sfx(gameover_sfx)
	time_label.text = message
	restart_button.visible = true


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _play_sfx(stream: AudioStreamWAV) -> void:
	sfx_player.stream = stream
	sfx_player.play()


func _start_audio_keepalive() -> void:
	var keepalive: AudioStreamPlayer = AudioStreamPlayer.new()
	keepalive.stream = SfxFactory.create_keepalive()
	keepalive.volume_db = -40.0
	add_child(keepalive)
	keepalive.play()


func _load_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("records", "high_score", 0))


func _save_high_score(new_score: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("records", "high_score", new_score)
	config.save(SAVE_PATH)


func _pulse_score_label() -> void:
	var tween: Tween = create_tween()
	score_label.scale = Vector2(1.25, 1.25)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.15)


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
