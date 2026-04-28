class_name CityRenderer
extends Node2D

## Renderiza ciudades en el mapa hexagonal.
## Cada ciudad se muestra como un círculo coloreado con el color de la tribu,
## con un número que indica el nivel.

const CITY_RADIUS := 14.0
const Z_INDEX_CITIES := 5

## Referencia al hex grid
var hex_grid: HexGrid

## Mapa: city_id -> Node2D (contenedor visual de la ciudad)
var _city_visuals: Dictionary = {}

## Crea el visual para una ciudad
func spawn_city(city: Cities.City) -> void:
	var city_id := _make_city_id(city)
	if _city_visuals.has(city_id):
		return

	var container := Node2D.new()
	container.name = "City_%s" % city_id
	container.z_index = Z_INDEX_CITIES

	# Fondo circular
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.custom_minimum_size = Vector2(CITY_RADIUS * 2, CITY_RADIUS * 2)
	bg.size = Vector2(CITY_RADIUS * 2, CITY_RADIUS * 2)
	bg.position = Vector2(-CITY_RADIUS, -CITY_RADIUS)

	var tribe_color: Color = Tribes.get_tribe_color(city.tribe_id)
	bg.color = tribe_color

	# Hacer circular con shader o simplemente usar un Panel con corner radius
	# En Godot 4, StyleBoxFlat con corner_radius_all funciona en ColorRect
	var style := StyleBoxFlat.new()
	style.bg_color = tribe_color
	style.corner_radius_top_left = int(CITY_RADIUS)
	style.corner_radius_top_right = int(CITY_RADIUS)
	style.corner_radius_bottom_left = int(CITY_RADIUS)
	style.corner_radius_bottom_right = int(CITY_RADIUS)
	style.border_color = Color("#1a1a1a")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	bg.add_theme_stylebox_override("panel", style)

	# Label con nivel
	var label := Label.new()
	label.name = "LevelLabel"
	label.text = str(city.level)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-CITY_RADIUS, -CITY_RADIUS)
	label.size = Vector2(CITY_RADIUS * 2, CITY_RADIUS * 2)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)

	container.add_child(bg)
	container.add_child(label)

	# Posicionar
	_update_container_position(container, city.position)

	add_child(container)
	_city_visuals[city_id] = container

## Actualiza el nivel visual de una ciudad
func update_city(city: Cities.City) -> void:
	var city_id := _make_city_id(city)
	var container := _city_visuals.get(city_id) as Node2D
	if container == null:
		spawn_city(city)
		return

	var label := container.get_node_or_null("LevelLabel") as Label
	if label:
		label.text = str(city.level)

	# Actualizar color si cambió de propietario
	var bg := container.get_node_or_null("Bg") as ColorRect
	if bg:
		var tribe_color: Color = Tribes.get_tribe_color(city.tribe_id)
		var style := StyleBoxFlat.new()
		style.bg_color = tribe_color
		style.corner_radius_top_left = int(CITY_RADIUS)
		style.corner_radius_top_right = int(CITY_RADIUS)
		style.corner_radius_bottom_left = int(CITY_RADIUS)
		style.corner_radius_bottom_right = int(CITY_RADIUS)
		style.border_color = Color("#1a1a1a")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		bg.add_theme_stylebox_override("panel", style)

## Elimina visual de una ciudad
func remove_city(city: Cities.City) -> void:
	var city_id := _make_city_id(city)
	var container := _city_visuals.get(city_id) as Node2D
	if container != null:
		container.queue_free()
		_city_visuals.erase(city_id)

## Limpia todas las ciudades visuales
func clear_all() -> void:
	for container in _city_visuals.values():
		if is_instance_valid(container):
			container.queue_free()
	_city_visuals.clear()

## Sincroniza desde lista de jugadores
func sync_from_players(players: Array[TurnManager.Player]) -> void:
	clear_all()
	for player in players:
		for city in player.cities:
			spawn_city(city)

func _make_city_id(city: Cities.City) -> String:
	return "%d_%s_%d_%d" % [city.owner_id, city.name, city.position.x, city.position.y]

func _update_container_position(container: Node2D, pos: Vector2i) -> void:
	if hex_grid == null:
		return
	var pixel_pos: Vector2 = hex_grid.axial_to_pixelv(pos)
	container.position = pixel_pos
