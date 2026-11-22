extends GutTest


func test_korean_custom_font_is_configured_and_loads() -> void:
	var font_path: String = str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	assert_eq(font_path, "res://assets/fonts/NanumGothic.ttf")
	var font_res: Font = load(font_path) as Font
	assert_not_null(font_res)


func test_compute_joystick_output_deadzone_and_clamping() -> void:
	var center: Vector2 = TouchControls.DEFAULT_JOY_CENTER
	var tiny_vec: Vector2 = TouchControls.compute_joystick_output(center, center + Vector2(3.0, 0.0), 68.0)
	assert_eq(tiny_vec, Vector2.ZERO)

	var full_vec: Vector2 = TouchControls.compute_joystick_output(center, center + Vector2(200.0, 0.0), 68.0)
	assert_almost_eq(full_vec.x, 1.0, 0.001)
	assert_almost_eq(full_vec.y, 0.0, 0.001)


func test_multitouch_joystick_and_dash_button_work_simultaneously() -> void:
	var controls: TouchControls = TouchControls.new()
	watch_signals(controls)

	controls.handle_touch_point(0, TouchControls.DEFAULT_JOY_CENTER + Vector2(50.0, 0.0), true)
	assert_gt(controls.move_vector.x, 0.5)
	assert_signal_emitted(controls, "move_vector_changed")

	controls.handle_touch_point(1, TouchControls.DASH_CENTER, true)
	assert_signal_emitted(controls, "dash_pressed")
	assert_gt(controls.move_vector.x, 0.5, "Tapping Dash must keep active joystick movement")

	controls.handle_touch_point(0, TouchControls.DEFAULT_JOY_CENTER, false)
	assert_eq(controls.move_vector, Vector2.ZERO)
	controls.free()
