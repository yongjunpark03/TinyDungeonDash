class_name LevelUpMenu
extends Control

signal upgrade_selected(upgrade_id: String)

const BOX_PATH: String = "CenterContainer/PanelContainer/MarginContainer/VBoxContainer"

var _choices: Array[Dictionary] = []
var _title_label: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title_label = get_node_or_null(BOX_PATH + "/LevelUpTitle") as Label
	var btn_names: Array[String] = ["CardButton1", "CardButton2", "CardButton3"]
	for i in range(btn_names.size()):
		var btn: Button = get_node_or_null(BOX_PATH + "/" + btn_names[i]) as Button
		_buttons.append(btn)
		if btn != null:
			btn.pressed.connect(_on_card_pressed.bind(i))


func present_choices(new_level: int, choices: Array[Dictionary]) -> void:
	_choices = choices
	if _title_label != null:
		_title_label.text = "LEVEL UP! (Lv.%d)" % new_level
	for i in range(_buttons.size()):
		var btn: Button = _buttons[i]
		if btn == null:
			continue
		if i < _choices.size():
			var item: Dictionary = _choices[i]
			btn.visible = true
			btn.text = "%s\n%s" % [str(item.get("title", "")), str(item.get("description", ""))]
		else:
			btn.visible = false
	visible = true
	if get_tree() != null:
		get_tree().paused = true
	if _buttons.size() > 0 and _buttons[0] != null:
		_buttons[0].grab_focus()


func select_choice(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	var chosen_id: String = str(_choices[index].get("id", ""))
	visible = false
	if get_tree() != null:
		get_tree().paused = false
	upgrade_selected.emit(chosen_id)


func _on_card_pressed(index: int) -> void:
	select_choice(index)
