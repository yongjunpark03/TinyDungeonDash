extends Node

signal high_score_changed(new_high_score: int)
signal bgm_toggled(enabled: bool)
signal achievement_unlocked(achievement_id: String, title: String)
signal hero_changed(hero_index: int, hero_name: String)

const DEFAULT_SAVE_PATH: String = "user://high_score.cfg"
const TITLE_SCENE_PATH: String = "res://scenes/title.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const ACHIEVEMENT_DEFS: Array[Dictionary] = [
	{"id": "first_blood", "title": "첫 사냥꾼 (First Blood)"},
	{"id": "boss_slayer", "title": "네크로 슬레이어 (Boss Slayer)"},
	{"id": "combo_master", "title": "콤보 마스터 (Combo x4)"},
	{"id": "veteran_knight", "title": "고대 기사 (Lv.3 달성)"},
]
const HERO_DEFS: Array[Dictionary] = [
	{"id": "paladin", "name": "발키리 성기사", "path": "res://assets/custom/heroes/hero_0.png"},
	{"id": "rogue", "name": "그림자 도적", "path": "res://assets/custom/heroes/hero_1.png"},
	{"id": "mage", "name": "별빛 마법사", "path": "res://assets/custom/heroes/hero_2.png"},
	{"id": "ranger", "name": "숲의 레인저", "path": "res://assets/custom/heroes/hero_3.png"},
	{"id": "cleric", "name": "태양 성직자", "path": "res://assets/custom/heroes/hero_4.png"},
	{"id": "berserker", "name": "드래곤 광전사", "path": "res://assets/custom/heroes/hero_5.png"},
	{"id": "alchemist", "name": "던전 연금술사", "path": "res://assets/custom/heroes/hero_6.png"},
	{"id": "necromancer", "name": "소울 네크로맨서", "path": "res://assets/custom/heroes/hero_7.png"},
]

var save_path: String = DEFAULT_SAVE_PATH
var high_score: int = 0
var last_score: int = 0
var last_wave: int = 1
var last_end_reason: String = ""
var has_played_run: bool = false
var bgm_enabled: bool = true
var total_kills: int = 0
var boss_kills: int = 0
var selected_hero_index: int = 0
var unlocked_achievements: Array[String] = []
var _keepalive_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_high_score()
	_ensure_audio_keepalive()
	_ensure_bgm_player()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_M:
		toggle_bgm()


func load_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(save_path) != OK:
		high_score = 0
		total_kills = 0
		boss_kills = 0
		selected_hero_index = 0
		unlocked_achievements.clear()
		return high_score
	high_score = int(config.get_value("records", "high_score", 0))
	total_kills = int(config.get_value("records", "total_kills", 0))
	boss_kills = int(config.get_value("records", "boss_kills", 0))
	selected_hero_index = clampi(
		int(config.get_value("records", "selected_hero_index", 0)),
		0,
		HERO_DEFS.size() - 1
	)
	unlocked_achievements.clear()
	var saved_ach: Array = config.get_value("records", "achievements", []) as Array
	for item in saved_ach:
		unlocked_achievements.append(str(item))
	return high_score


func save_high_score(new_score: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("records", "high_score", new_score)
	config.set_value("records", "total_kills", total_kills)
	config.set_value("records", "boss_kills", boss_kills)
	config.set_value("records", "selected_hero_index", selected_hero_index)
	config.set_value("records", "achievements", unlocked_achievements)
	config.save(save_path)


func update_high_score(score: int) -> bool:
	if score > high_score:
		high_score = score
		save_high_score(high_score)
		high_score_changed.emit(high_score)
		return true
	return false


func record_run_result(score: int, wave: int, reason: String) -> bool:
	last_score = score
	last_wave = wave
	last_end_reason = reason
	has_played_run = true
	return update_high_score(score)


func unlock_achievement(achievement_id: String) -> String:
	if unlocked_achievements.has(achievement_id):
		return ""
	var matched_title: String = ""
	for entry in ACHIEVEMENT_DEFS:
		if str(entry.get("id", "")) == achievement_id:
			matched_title = str(entry.get("title", ""))
			break
	if matched_title.is_empty():
		return ""
	unlocked_achievements.append(achievement_id)
	save_high_score(high_score)
	achievement_unlocked.emit(achievement_id, matched_title)
	return matched_title


func register_kill(is_boss_enemy: bool = false) -> Array[String]:
	total_kills += 1
	if is_boss_enemy:
		boss_kills += 1
	var newly_unlocked: Array[String] = []
	var first_title: String = unlock_achievement("first_blood")
	if not first_title.is_empty():
		newly_unlocked.append(first_title)
	if is_boss_enemy:
		var boss_title: String = unlock_achievement("boss_slayer")
		if not boss_title.is_empty():
			newly_unlocked.append(boss_title)
	save_high_score(high_score)
	return newly_unlocked


func get_achievement_summary() -> String:
	return "업적: %d / %d  |  누적 처치: %d (보스 %d)" % [
		unlocked_achievements.size(),
		ACHIEVEMENT_DEFS.size(),
		total_kills,
		boss_kills,
	]


func set_selected_hero(index: int) -> void:
	var count: int = HERO_DEFS.size()
	selected_hero_index = ((index % count) + count) % count
	save_high_score(high_score)
	hero_changed.emit(selected_hero_index, get_selected_hero_name())


func cycle_hero(step: int) -> int:
	set_selected_hero(selected_hero_index + step)
	return selected_hero_index


func get_selected_hero_name() -> String:
	return str(HERO_DEFS[selected_hero_index].get("name", "발키리 성기사"))


func get_selected_hero_texture() -> Texture2D:
	var tex_path: String = str(HERO_DEFS[selected_hero_index].get("path", ""))
	return load(tex_path) as Texture2D


func set_bgm_enabled(enabled: bool) -> void:
	bgm_enabled = enabled
	if _bgm_player != null:
		_bgm_player.stream_paused = not bgm_enabled
	bgm_toggled.emit(bgm_enabled)


func toggle_bgm() -> bool:
	set_bgm_enabled(not bgm_enabled)
	return bgm_enabled


func start_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _ensure_audio_keepalive() -> void:
	if _keepalive_player != null:
		return
	_keepalive_player = AudioStreamPlayer.new()
	_keepalive_player.stream = SfxFactory.create_keepalive()
	add_child(_keepalive_player)
	_keepalive_player.play()


func _ensure_bgm_player() -> void:
	if _bgm_player != null:
		return
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = SfxFactory.create_dungeon_bgm()
	add_child(_bgm_player)
	_bgm_player.play()
	_bgm_player.stream_paused = not bgm_enabled
