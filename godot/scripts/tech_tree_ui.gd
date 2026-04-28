class_name TechTreeUI
extends PanelContainer

## Panel flotante para investigar tecnologías
## Se muestra cuando el jugador presiona el botón de tecnología

var player # TurnManager.Player (referencia débil para no causar ciclos)

@onready var tech_list: VBoxContainer = $Content/TechList
@onready var title_label: Label = $Content/TitleLabel

signal tech_researched(tech_id: int)
signal panel_closed

func setup(p_player) -> void:
	player = p_player
	_refresh_tech_list()

func _refresh_tech_list() -> void:
	for child in tech_list.get_children():
		child.queue_free()

	if player == null or player.tech_tree == null:
		var label = Label.new()
		label.text = "No hay tecnologías disponibles"
		tech_list.add_child(label)
		return

	for tech_id in player.tech_tree.available:
		var data := Technologies.get_tech_data(tech_id)
		var cost: int = data.get("cost", 0)
		var name_str: String = data.get("name", "Desconocido")
		var desc: String = data.get("description", "")

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		var affordable := player.resources.stars >= cost
		var status := "[%d⭐]" % cost if affordable else "[%d⭐] (insuficiente)" % cost
		btn.text = "%s %s" % [name_str, status]
		btn.disabled = not affordable
		btn.pressed.connect(_on_tech_pressed.bind(tech_id, cost))
		tech_list.add_child(btn)

		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_color_override("font_color", Color("#94a3b8"))
		desc_label.add_theme_font_size_override("font_size", 12)
		tech_list.add_child(desc_label)

		var sep := HSeparator.new()
		tech_list.add_child(sep)

func _on_tech_pressed(tech_id: int, cost: int) -> void:
	if player == null or player.tech_tree == null:
		return
	if player.resources.spend(GameResources.ResourceType.STARS, cost):
		player.tech_tree.researched.append(tech_id)
		player.tech_tree.available.erase(tech_id)
		# Actualizar disponibles
		player.tech_tree.available = player.tech_tree._update_available()
		tech_researched.emit(tech_id)
		_refresh_tech_list()

func _on_close_pressed() -> void:
	visible = false
	panel_closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
