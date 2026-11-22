class_name TouchControls
extends Control

signal move_vector_changed(new_vector: Vector2)
signal dash_pressed

const DEFAULT_JOY_CENTER: Vector2 = Vector2(156.0, 510.0)
const JOY_RADIUS: float = 68.0
const KNOB_RADIUS: float = 28.0
const DEADZONE: float = 0.14
const DASH_CENTER: Vector2 = Vector2(996.0, 510.0)
const DASH_RADIUS: float = 58.0

var move_vector: Vector2 = Vector2.ZERO
var dash_cooldown_ratio: float = 0.0
var _joy_touch_index: int = -1
var _joy_center: Vector2 = DEFAULT_JOY_CENTER
var _knob_pos: Vector2 = DEFAULT_JOY_CENTER
var _dash_pressed_visual: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or (get_tree() != null and get_tree().paused):
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		handle_touch_point(touch.index, _to_canvas_pos(touch.position), touch.pressed)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		handle_drag_point(drag.index, _to_canvas_pos(drag.position))


func _draw() -> void:
	var joy_base: Color = Color(0.08, 0.12, 0.22, 0.48)
	var joy_ring: Color = Color(0.45, 0.88, 1.0, 0.72)
	var knob_col: Color = Color(0.55, 0.95, 1.0, 0.85)
	draw_circle(_joy_center, JOY_RADIUS, joy_base)
	draw_arc(_joy_center, JOY_RADIUS, 0.0, TAU, 40, joy_ring, 3.0)
	draw_circle(_knob_pos, KNOB_RADIUS, knob_col)

	var dash_ready: bool = dash_cooldown_ratio <= 0.01
	var dash_fill: Color = Color(0.15, 0.45, 0.65, 0.78) if dash_ready else Color(0.18, 0.2, 0.25, 0.5)
	if _dash_pressed_visual:
		dash_fill = Color(0.35, 0.78, 0.95, 0.9)
	var dash_ring: Color = Color(0.55, 0.95, 1.0, 0.9) if dash_ready else Color(0.5, 0.55, 0.6, 0.5)
	draw_circle(DASH_CENTER, DASH_RADIUS, dash_fill)
	draw_arc(DASH_CENTER, DASH_RADIUS, 0.0, TAU, 40, dash_ring, 3.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var text_size: int = 20
		var text_pos: Vector2 = DASH_CENTER + Vector2(-28.0, 7.0)
		draw_string(font, text_pos, "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color.WHITE)


static func compute_joystick_output(center: Vector2, touch_pos: Vector2, max_radius: float) -> Vector2:
	var delta: Vector2 = touch_pos - center
	var dist: Vector2 = delta
	var len_val: float = dist.length()
	if max_radius <= 0.0 or len_val <= max_radius * DEADZONE:
		return Vector2.ZERO
	var strength: float = clampf(len_val / max_radius, 0.0, 1.0)
	return delta.normalized() * strength


func handle_touch_point(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if pos.distance_to(DASH_CENTER) <= DASH_RADIUS * 1.25:
			_dash_pressed_visual = true
			dash_pressed.emit()
			queue_redraw()
			return
		if _joy_touch_index == -1 and pos.x < 540.0 and pos.y > 200.0:
			_joy_touch_index = index
			_joy_center = DEFAULT_JOY_CENTER
			_update_joy_from_pos(pos)
		return

	_dash_pressed_visual = false
	if index == _joy_touch_index:
		reset_touch_state()
	else:
		queue_redraw()


func handle_drag_point(index: int, pos: Vector2) -> void:
	if index == _joy_touch_index:
		_update_joy_from_pos(pos)


func reset_touch_state() -> void:
	_joy_touch_index = -1
	_dash_pressed_visual = false
	_joy_center = DEFAULT_JOY_CENTER
	_knob_pos = DEFAULT_JOY_CENTER
	if move_vector != Vector2.ZERO:
		move_vector = Vector2.ZERO
		move_vector_changed.emit(move_vector)
	queue_redraw()


func _update_joy_from_pos(pos: Vector2) -> void:
	var delta: Vector2 = pos - _joy_center
	if delta.length() > JOY_RADIUS:
		_knob_pos = _joy_center + delta.normalized() * JOY_RADIUS
	else:
		_knob_pos = pos
	var next_vec: Vector2 = compute_joystick_output(_joy_center, pos, JOY_RADIUS)
	if next_vec != move_vector:
		move_vector = next_vec
		move_vector_changed.emit(move_vector)
	queue_redraw()


func _to_canvas_pos(raw_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return raw_pos
	return get_global_transform_with_canvas().affine_inverse() * raw_pos
