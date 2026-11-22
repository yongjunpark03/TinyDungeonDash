extends GutTest

const GAME_MANAGER_SCRIPT: GDScript = preload("res://scripts/game_manager.gd")
const TEST_SAVE_PATH: String = "user://test_game_manager_step5.cfg"


func after_each() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func test_update_high_score_only_increases_and_persists() -> void:
	var gm: Node = GAME_MANAGER_SCRIPT.new()
	gm.set("save_path", TEST_SAVE_PATH)
	gm.set("high_score", 0)
	assert_true(bool(gm.call("update_high_score", 150)))
	assert_eq(int(gm.get("high_score")), 150)
	assert_false(bool(gm.call("update_high_score", 100)))
	assert_eq(int(gm.get("high_score")), 150)
	gm.free()

	var gm_reloaded: Node = GAME_MANAGER_SCRIPT.new()
	gm_reloaded.set("save_path", TEST_SAVE_PATH)
	assert_eq(int(gm_reloaded.call("load_high_score")), 150)
	gm_reloaded.free()


func test_record_run_result_tracks_last_run_and_new_best() -> void:
	var gm: Node = GAME_MANAGER_SCRIPT.new()
	gm.set("save_path", TEST_SAVE_PATH)
	gm.set("high_score", 0)
	assert_true(bool(gm.call("record_run_result", 200, 3, "TIME'S UP!")))
	assert_true(bool(gm.get("has_played_run")))
	assert_eq(int(gm.get("last_score")), 200)
	assert_eq(int(gm.get("last_wave")), 3)
	assert_eq(str(gm.get("last_end_reason")), "TIME'S UP!")

	assert_false(bool(gm.call("record_run_result", 120, 2, "GAME OVER")))
	assert_eq(int(gm.get("high_score")), 200)
	assert_eq(int(gm.get("last_score")), 120)
	assert_eq(int(gm.get("last_wave")), 2)
	gm.free()


func test_pause_menu_toggles_tree_pause() -> void:
	var pause_menu: PauseMenu = PauseMenu.new()
	add_child_autofree(pause_menu)
	assert_false(pause_menu.visible)
	assert_false(get_tree().paused)
	pause_menu.toggle_pause()
	assert_true(pause_menu.visible)
	assert_true(get_tree().paused)
	pause_menu.set_paused(false)
	assert_false(pause_menu.visible)
	assert_false(get_tree().paused)
