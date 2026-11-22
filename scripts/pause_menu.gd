class_name PauseMenu
extends Control

signal resume_requested
signal title_requested

const BUTTON_BOX_PATH: String = "CenterContainer/PanelContainer/MarginContainer/VBoxContainer"

var can_pause: bool = true
var _resume_button: Button
var _title_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button = get_node_or_null(BUTTON_BOX_PATH + "/ResumeButton") as Button
	_title_button = get_node_or_null(BUTTON_BOX_PATH + "/TitleButton") as Button
	if _resume_button != null:
		_resume_button.pressed.connect(_on_resume_pressed)
	if _title_button != null:
		_title_button.pressed.connect(_on_title_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func set_paused(should_pause: bool) -> void:
	if get_tree() != null:
		get_tree().paused = should_pause
	visible = should_pause
	if should_pause and _resume_button != null:
		_resume_button.grab_focus()


func toggle_pause() -> void:
	if get_tree() == null:
		return
	set_paused(not get_tree().paused)


func _on_resume_pressed() -> void:
	set_paused(false)
	resume_requested.emit()


func _on_title_pressed() -> void:
	set_paused(false)
	title_requested.emit()
