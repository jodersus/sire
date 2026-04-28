extends CanvasLayer
class_name GameOverScreen

## Pantalla de fin de partida (victoria o derrota)

var _winner_name: String = ""
var _victory_type: String = ""

@onready var title_label: Label = $Panel/Content/TitleLabel
@onready var subtitle_label: Label = $Panel/Content/SubtitleLabel
@onready var stats_label: Label = $Panel/Content/StatsLabel
@onready var restart_btn: Button = $Panel/Content/ButtonContainer/RestartButton
@onready var menu_btn: Button = $Panel/Content/ButtonContainer/MenuButton

func _ready():
	visible = false
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)

func show_victory(winner_name: String, turn_count: int, score: int) -> void:
	_winner_name = winner_name
	_victory_type = "victory"
	title_label.text = "Victoria"
	title_label.add_theme_color_override("font_color", Color("#FFD54F"))
	subtitle_label.text = "%s ha conquistado el mundo" % winner_name
	stats_label.text = "Turnos: %d  |  Puntuación: %d" % [turn_count, score]
	visible = true
	get_tree().paused = true

func show_defeat(defeated_by: String, turn_count: int) -> void:
	_winner_name = defeated_by
	_victory_type = "defeat"
	title_label.text = "Derrota"
	title_label.add_theme_color_override("font_color", Color("#F44336"))
	subtitle_label.text = "Has sido derrotado por %s" % defeated_by
	stats_label.text = "Turnos sobrevividos: %d" % turn_count
	visible = true
	get_tree().paused = true

func _on_restart() -> void:
	get_tree().paused = false
	visible = false
	# Reiniciar partida
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("initialize_game"):
		gm.initialize_game()

func _on_menu() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
