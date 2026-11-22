extends GutTest

const GAME_MANAGER_SCRIPT: GDScript = preload("res://scripts/game_manager.gd")
const TEST_SAVE_PATH: String = "user://test_achievements_step5.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func test_register_kill_increments_counters_and_unlocks_achievements() -> void:
	var gm: Node = GAME_MANAGER_SCRIPT.new()
	gm.set("save_path", TEST_SAVE_PATH)

	var first_unlocks: Array = gm.call("register_kill", false) as Array
	assert_eq(int(gm.get("total_kills")), 1)
	assert_eq(int(gm.get("boss_kills")), 0)
	assert_eq(first_unlocks.size(), 1)

	var boss_unlocks: Array = gm.call("register_kill", true) as Array
	assert_eq(int(gm.get("total_kills")), 2)
	assert_eq(int(gm.get("boss_kills")), 1)
	assert_eq(boss_unlocks.size(), 1)
	gm.free()


func test_unlock_achievement_is_idempotent_and_persists() -> void:
	var gm: Node = GAME_MANAGER_SCRIPT.new()
	gm.set("save_path", TEST_SAVE_PATH)
	watch_signals(gm)

	var title_first: String = str(gm.call("unlock_achievement", "combo_master"))
	assert_false(title_first.is_empty())
	assert_signal_emitted_with_parameters(gm, "achievement_unlocked", ["combo_master", title_first])
	assert_eq(str(gm.call("unlock_achievement", "combo_master")), "")
	assert_eq(str(gm.call("unlock_achievement", "unknown_id")), "")
	gm.free()

	var gm_reloaded: Node = GAME_MANAGER_SCRIPT.new()
	gm_reloaded.set("save_path", TEST_SAVE_PATH)
	gm_reloaded.call("load_high_score")
	var unlocked: Array = gm_reloaded.get("unlocked_achievements") as Array
	assert_true(unlocked.has("combo_master"))
	gm_reloaded.free()


func test_get_achievement_summary_formats_counts() -> void:
	var gm: Node = GAME_MANAGER_SCRIPT.new()
	gm.set("save_path", TEST_SAVE_PATH)
	gm.call("register_kill", false)
	var summary: String = str(gm.call("get_achievement_summary"))
	assert_true(summary.contains("1 / 4"))
	assert_true(summary.contains("1"))
	gm.free()
