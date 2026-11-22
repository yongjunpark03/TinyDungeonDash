extends GutTest

const GAME_MANAGER_SCRIPT: GDScript = preload("res://scripts/game_manager.gd")
const MAIN_SCRIPT: GDScript = preload("res://scripts/main.gd")
const TORCH_SHADER: Shader = preload("res://shaders/torch_vignette.gdshader")


func test_create_dungeon_bgm_generates_looping_16bit_wav() -> void:
	var wav: AudioStreamWAV = SfxFactory.create_dungeon_bgm(0.1, 0.15)
	assert_not_null(wav)
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, SfxFactory.MIX_RATE)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(wav.data.size(), 1000)


func test_game_manager_toggle_bgm_flips_state_and_emits_signal() -> void:
	var gm: Node = GAME_MANAGER_SCRIPT.new()
	watch_signals(gm)
	assert_true(bool(gm.get("bgm_enabled")))
	var after_first: bool = bool(gm.call("toggle_bgm"))
	assert_false(after_first)
	assert_signal_emitted_with_parameters(gm, "bgm_toggled", [false])
	var after_second: bool = bool(gm.call("toggle_bgm"))
	assert_true(after_second)
	gm.free()


func test_torch_vignette_shader_and_light_uv_computation() -> void:
	assert_not_null(TORCH_SHADER)
	var center_uv: Vector2 = MAIN_SCRIPT.compute_light_uv(Vector2(576.0, 324.0), Vector2(1152.0, 648.0))
	assert_almost_eq(center_uv.x, 0.5, 0.001)
	assert_almost_eq(center_uv.y, 0.5, 0.001)

	var clamped_uv: Vector2 = MAIN_SCRIPT.compute_light_uv(Vector2(2000.0, -50.0), Vector2(1152.0, 648.0))
	assert_almost_eq(clamped_uv.x, 1.0, 0.001)
	assert_almost_eq(clamped_uv.y, 0.0, 0.001)
