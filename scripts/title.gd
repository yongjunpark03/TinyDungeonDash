extends Node2D

@onready var prev_hero_button: Button = (
	$UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/HeroSelectorRow/PrevHeroButton
)
@onready var hero_preview: TextureRect = (
	$UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/HeroSelectorRow/HeroPreview
)
@onready var next_hero_button: Button = (
	$UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/HeroSelectorRow/NextHeroButton
)
@onready var hero_name_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/HeroNameLabel
@onready var best_score_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/BestScoreLabel
@onready var records_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/RecordsLabel
@onready var last_run_label: Label = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/LastRunLabel
@onready var start_button: Button = $UI/CenterContainer/TitlePanel/MarginContainer/VBoxContainer/StartButton


func _ready() -> void:
	get_tree().paused = false
	prev_hero_button.pressed.connect(_on_prev_hero_pressed)
	next_hero_button.pressed.connect(_on_next_hero_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_refresh_records()
	_refresh_hero_preview()
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


func _refresh_hero_preview() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var tex: Texture2D = gm.call("get_selected_hero_texture") as Texture2D
	if tex != null:
		hero_preview.texture = tex
	var idx: int = int(gm.get("selected_hero_index")) + 1
	var hero_name: String = str(gm.call("get_selected_hero_name"))
	hero_name_label.text = "캐릭터: %s (%d / 6)" % [hero_name, idx]


func _on_prev_hero_pressed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.call("cycle_hero", -1)
		_refresh_hero_preview()


func _on_next_hero_pressed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.call("cycle_hero", 1)
		_refresh_hero_preview()


func _on_start_pressed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.call("start_game")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
