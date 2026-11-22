extends Node2D

@onready var best_score_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/BestScoreLabel
@onready var records_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/RecordsLabel
@onready var last_run_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/LastRunLabel
@onready var start_button: Button = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/StartButton


func _ready() -> void:
	get_tree().paused = false
	start_button.pressed.connect(_on_start_pressed)
	_refresh_records()
	start_button.grab_focus()


func _refresh_records() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	best_score_label.text = "Best Score: %d" % int(gm.get("high_score"))
	records_label.text = str(gm.call("get_achievement_summary"))
	if bool(gm.get("has_played_run")):
		last_run_label.visible = true
		last_run_label.text = "Last Run: %d pts (Wave %d)" % [int(gm.get("last_score")), int(gm.get("last_wave"))]
	else:
		last_run_label.visible = false


func _on_start_pressed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.call("start_game")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
