extends CanvasLayer
## HUD durante la partida

const PHASE_BUTTONS = ["Tecnología", "Movimiento", "Combate", "Fin Turno"]

var current_phase: int = 0
var event_log: Array[String] = []
const MAX_LOG_EVENTS = 20

@onready var stars_label: Label = $TopBar/ResourcesContainer/StarsContainer/StarsValue
@onready var population_label: Label = $TopBar/ResourcesContainer/PopContainer/PopValue
@onready var turn_label: Label = $TopBar/TurnContainer/TurnValue
@onready var phase_label: Label = $TopBar/PhaseContainer/PhaseValue
@onready var minimap: ColorRect = $MinimapPanel/MinimapViewport
@onready var action_panel: PanelContainer = $ActionPanel
@onready var action_title: Label = $ActionPanel/ActionContent/ActionTitle
@onready var action_list: VBoxContainer = $ActionPanel/ActionContent/ActionList
@onready var phase_buttons: HBoxContainer = $PhaseBar/PhaseButtons
@onready var event_log_rich: RichTextLabel = $EventLogPanel/EventLogContent
@onready var pause_button: Button = $TopBar/PauseButton

func _ready():
	update_resource_display()
	update_phase_display()
	setup_phase_buttons()
	add_event("Partida iniciada. Turno 1.")
	
	# Ocultar panel de acciones inicialmente
	action_panel.visible = false

func update_resource_display():
	stars_label.text = str(GameConfig.player_stars)
	population_label.text = str(GameConfig.player_population)
	turn_label.text = str(GameConfig.current_turn)

func update_phase_display():
	phase_label.text = GameConfig.PHASES[current_phase]
	
	# Actualizar estilo de botones de fase
	for i in range(phase_buttons.get_child_count()):
		var btn = phase_buttons.get_child(i)
		if i == current_phase - 1:
			btn.add_theme_color_override("font_color", Color("#FFD54F"))
			btn.add_theme_stylebox_override("normal", get_highlight_style())
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")

func get_highlight_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#334155")
	style.border_color = Color("#FFD54F")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func setup_phase_buttons():
	for phase_name in PHASE_BUTTONS:
		var btn = Button.new()
		btn.text = phase_name
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_on_phase_button_pressed.bind(phase_name))
		phase_buttons.add_child(btn)

func _on_phase_button_pressed(phase_name: String):
	match phase_name:
		"Tecnología":
			current_phase = 2
			add_event("Fase de Tecnología seleccionada.")
		"Movimiento":
			current_phase = 3
			add_event("Fase de Movimiento seleccionada.")
		"Combate":
			current_phase = 4
			add_event("Fase de Combate seleccionada.")
		"Fin Turno":
			_end_turn()
	update_phase_display()

func _end_turn():
	GameConfig.current_turn += 1
	current_phase = 1
	update_resource_display()
	update_phase_display()
	add_event("Turno %d iniciado." % GameConfig.current_turn)

func add_event(text: String):
	event_log.append("[Turno %d] %s" % [GameConfig.current_turn, text])
	if event_log.size() > MAX_LOG_EVENTS:
		event_log.pop_front()
	_update_event_log()

func _update_event_log():
	event_log_rich.clear()
	for event in event_log:
		event_log_rich.append_text(event + "\n")
	event_log_rich.scroll_to_line(event_log_rich.get_line_count())

func show_hex_actions(hex_info: Dictionary):
	action_panel.visible = true
	action_title.text = hex_info.get("terrain", "Terreno")
	
	# Limpiar lista de acciones
	for child in action_list.get_children():
		child.queue_free()
	
	# Añadir acciones según el tipo de hex
	var actions = hex_info.get("actions", [])
	if actions.is_empty():
		var label = Label.new()
		label.text = "Sin acciones disponibles"
		label.add_theme_color_override("font_color", Color("#94a3b8"))
		action_list.add_child(label)
	else:
		for action in actions:
			var btn = Button.new()
			btn.text = action
			btn.pressed.connect(_on_action_pressed.bind(action))
			action_list.add_child(btn)

func show_unit_actions(unit_info: Dictionary):
	action_panel.visible = true
	action_title.text = unit_info.get("name", "Unidad")
	
	for child in action_list.get_children():
		child.queue_free()
	
	var actions = unit_info.get("actions", ["Mover", "Atacar", "Descansar"])
	for action in actions:
		var btn = Button.new()
		btn.text = action
		btn.pressed.connect(_on_action_pressed.bind(action))
		action_list.add_child(btn)

func _on_action_pressed(action: String):
	add_event("Acción: %s" % action)

func _on_pause_pressed():
	get_tree().paused = true
	var pause_menu = preload("res://scenes/pause_menu.tscn").instantiate()
	add_child(pause_menu)

func hide_action_panel():
	action_panel.visible = false
