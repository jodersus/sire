extends Control
## Pantalla de configuración de partida

const TRIBES = [
	{"name": "Solaris", "color": Color("#F4D03F"), "ability": "-20% coste tecnologías", "unit": "Explorador"},
	{"name": "Umbra", "color": Color("#2C3E50"), "ability": "+1 visión", "unit": "Explorador"},
	{"name": "Sylva", "color": Color("#27AE60"), "ability": "-30% coste madera", "unit": "Explorador"},
	{"name": "Ferrum", "color": Color("#922B21"), "ability": "+1 ataque", "unit": "Guerrero"},
	{"name": "Maris", "color": Color("#3498DB"), "ability": "Bono naval", "unit": "Barco"},
	{"name": "Equus", "color": Color("#E67E22"), "ability": "+1 movimiento caballería", "unit": "Jinete"},
	{"name": "Nomad", "color": Color("#8E44AD"), "ability": "+25% crecimiento ciudades", "unit": "Explorador"}
]

const MAP_SIZES = [
	{"name": "Pequeño", "size": "11x11", "description": "Rápido, intenso"},
	{"name": "Mediano", "size": "15x15", "description": "Equilibrado"},
	{"name": "Grande", "size": "19x19", "description": "Épico, estratégico"}
]

var selected_tribe: int = 0
var selected_bots: int = 2
var selected_map: int = 1

@onready var tribe_name: Label = $MainContainer/ContentContainer/TribeSection/TribeInfo/TribeName
@onready var tribe_ability: Label = $MainContainer/ContentContainer/TribeSection/TribeInfo/TribeAbility
@onready var tribe_unit: Label = $MainContainer/ContentContainer/TribeSection/TribeInfo/TribeUnit
@onready var tribe_preview: ColorRect = $MainContainer/ContentContainer/TribeSection/TribePreview/PreviewColor
@onready var tribe_icon: Label = $MainContainer/ContentContainer/TribeSection/TribePreview/PreviewIcon
@onready var bots_value: Label = $MainContainer/ContentContainer/SettingsSection/BotsRow/BotsValue
@onready var map_name: Label = $MainContainer/ContentContainer/SettingsSection/MapRow/MapName
@onready var map_size: Label = $MainContainer/ContentContainer/SettingsSection/MapRow/MapSize
@onready var map_desc: Label = $MainContainer/ContentContainer/SettingsSection/MapRow/MapDesc

func _ready():
	update_tribe_display()
	update_bots_display()
	update_map_display()

func update_tribe_display():
	var tribe = TRIBES[selected_tribe]
	tribe_name.text = tribe.name
	tribe_name.add_theme_color_override("font_color", tribe.color)
	tribe_ability.text = "Habilidad: " + tribe.ability
	tribe_unit.text = "Unidad inicial: " + tribe.unit
	tribe_preview.color = tribe.color
	tribe_icon.text = tribe.name[0]

func update_bots_display():
	bots_value.text = str(selected_bots)

func update_map_display():
	var map = MAP_SIZES[selected_map]
	map_name.text = map.name
	map_size.text = map.size
	map_desc.text = map.description

func _on_prev_tribe_pressed():
	selected_tribe = (selected_tribe - 1 + TRIBES.size()) % TRIBES.size()
	update_tribe_display()

func _on_next_tribe_pressed():
	selected_tribe = (selected_tribe + 1) % TRIBES.size()
	update_tribe_display()

func _on_bots_decrease_pressed():
	selected_bots = max(1, selected_bots - 1)
	update_bots_display()

func _on_bots_increase_pressed():
	selected_bots = min(3, selected_bots + 1)
	update_bots_display()

func _on_prev_map_pressed():
	selected_map = (selected_map - 1 + MAP_SIZES.size()) % MAP_SIZES.size()
	update_map_display()

func _on_next_map_pressed():
	selected_map = (selected_map + 1) % MAP_SIZES.size()
	update_map_display()

func _on_start_pressed():
	# Guardar configuración y comenzar
	GameConfig.selected_tribe = TRIBES[selected_tribe].name
	GameConfig.bot_count = selected_bots
	GameConfig.map_size_index = selected_map
	get_tree().change_scene_to_file("res://scenes/game_screen.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
