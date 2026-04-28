class_name MapInputHandler
extends Node2D

## Maneja input del mouse en el mapa hexagonal.
## Detecta clicks, selecciona unidades/ciudades, muestra movimientos posibles,
## y delega acciones al GameManager.

enum SelectionMode {
	NONE,
	UNIT_SELECTED,
	CITY_SELECTED,
	HEX_SELECTED,
}

## Referencias (inyectadas desde GameManager)
var hex_grid: HexGrid
var game_map: GameMap
var unit_renderer: UnitRenderer
var city_renderer: CityRenderer
var turn_manager: TurnManager

## Estado actual
var selection_mode: SelectionMode = SelectionMode.NONE
var selected_unit: Units.Unit = null
var selected_city: Cities.City = null
var selected_hex: Vector2i = Vector2i.ZERO
var reachable_hexes: Array[Vector2i] = []

## Nodos visuales para highlights
var _highlight_layer: Node2D
var _movement_overlay: Node2D

## Señales
signal unit_selected(unit: Units.Unit)
signal city_selected(city: Cities.City)
signal hex_selected(coord: Vector2i)
signal unit_moved(unit: Units.Unit, from_pos: Vector2i, to_pos: Vector2i)
signal move_confirmed(unit: Units.Unit, target: Vector2i)
signal action_cancelled

const HIGHLIGHT_COLOR := Color("#FFD54F")
const REACHABLE_COLOR := Color("#4CAF50")
const ENEMY_COLOR := Color("#F44336")
const ATTACK_RANGE_COLOR := Color("#FF9800")

func _ready():
	_setup_highlight_layers()

func _setup_highlight_layers() -> void:
	_highlight_layer = Node2D.new()
	_highlight_layer.name = "HighlightLayer"
	_highlight_layer.z_index = 20
	add_child(_highlight_layer)

	_movement_overlay = Node2D.new()
	_movement_overlay.name = "MovementOverlay"
	_movement_overlay.z_index = 15
	add_child(_movement_overlay)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_left_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_handle_right_click()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			# Drag end could be handled here if needed
			pass

func _handle_left_click() -> void:
	if hex_grid == null or game_map == null:
		return

	var mouse_pos := get_global_mouse_position()
	var hex_coord := hex_grid.pixel_to_axialv(mouse_pos)
	hex_coord = hex_grid.wrap_axialv(hex_coord)

	# Si hay una unidad seleccionada y hacemos click en un hex alcanzable -> mover
	if selection_mode == SelectionMode.UNIT_SELECTED and selected_unit != null:
		if reachable_hexes.has(hex_coord):
			_try_move_unit(selected_unit, hex_coord)
			return

	# Si hay una unidad seleccionada y hacemos click en un enemigo al alcance -> atacar
	if selection_mode == SelectionMode.UNIT_SELECTED and selected_unit != null:
		var enemy := _find_enemy_at(hex_coord)
		if enemy != null and _is_in_attack_range(selected_unit, enemy):
			_try_attack(selected_unit, enemy)
			return

	# Si hay una unidad en el hex -> seleccionarla
	var unit := _find_friendly_unit_at(hex_coord)
	if unit != null:
		_select_unit(unit)
		return

	# Si hay una ciudad en el hex -> seleccionarla
	var city := _find_friendly_city_at(hex_coord)
	if city != null:
		_select_city(city)
		return

	# Click en hex vacío -> seleccionar hex
	_select_hex(hex_coord)

func _handle_right_click() -> void:
	# Cancelar selección
	_clear_selection()
	action_cancelled.emit()

func _select_unit(unit: Units.Unit) -> void:
	selected_unit = unit
	selected_city = null
	selected_hex = unit.position
	selection_mode = SelectionMode.UNIT_SELECTED

	# Calcular hexágonos alcanzables
	_calculate_reachable_hexes(unit)

	# Dibujar highlights
	_draw_unit_highlights(unit)

	unit_selected.emit(unit)

func _select_city(city: Cities.City) -> void:
	selected_unit = null
	selected_city = city
	selected_hex = city.position
	selection_mode = SelectionMode.CITY_SELECTED

	_clear_highlights()
	_draw_city_highlight(city)

	city_selected.emit(city)

func _select_hex(coord: Vector2i) -> void:
	selected_unit = null
	selected_city = null
	selected_hex = coord
	selection_mode = SelectionMode.HEX_SELECTED

	_clear_highlights()
	_draw_hex_highlight(coord)

	hex_selected.emit(coord)

func _clear_selection() -> void:
	selected_unit = null
	selected_city = null
	selected_hex = Vector2i.ZERO
	selection_mode = SelectionMode.NONE
	reachable_hexes.clear()
	_clear_highlights()

func _calculate_reachable_hexes(unit: Units.Unit) -> void:
	reachable_hexes.clear()
	if unit.movimientos_restantes <= 0:
		return

	# BFS limitado por movimientos restantes
	var queue: Array[Dictionary] = [{"pos": unit.position, "cost": 0}]
	var visited: Dictionary = {unit.position: true}
	reachable_hexes.append(unit.position)

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_pos: Vector2i = current.pos
		var current_cost: int = current.cost

		for neighbor in hex_grid.get_neighborsv(current_pos):
			neighbor = hex_grid.wrap_axialv(neighbor)
			if visited.has(neighbor):
				continue

			# Obtener terreno
			var terrain := _get_terrain_at(neighbor)
			var move_cost := Units.get_terrain_movement_cost(unit.type, terrain)

			if move_cost < 0:
				continue  # Impasable

			var new_cost := current_cost + move_cost
			if new_cost > unit.movimientos_restantes:
				continue

			# Verificar si hay unidad enemiga (bloquea paso)
			if _has_enemy_unit_at(neighbor, unit.owner_id):
				continue

			visited[neighbor] = true
			reachable_hexes.append(neighbor)
			queue.append({"pos": neighbor, "cost": new_cost})

func _try_move_unit(unit: Units.Unit, target: Vector2i) -> void:
	# Obtener terreno del destino
	var terrain := _get_terrain_at(target)
	var move_cost := Units.get_terrain_movement_cost(unit.type, terrain)

	if move_cost < 0:
		return

	var from_pos := unit.position
	var success := unit.move_to(target, move_cost)

	if success:
		# Actualizar visual
		if unit_renderer != null:
			unit_renderer.move_unit(unit)

		unit_moved.emit(unit, from_pos, target)

		# Recalcular alcanzables si quedan movimientos
		if unit.movimientos_restantes > 0:
			_calculate_reachable_hexes(unit)
			_draw_unit_highlights(unit)
		else:
			_clear_highlights()
			selection_mode = SelectionMode.HEX_SELECTED
			selected_hex = target
	else:
		# Movimiento fallido
		pass

func _try_attack(attacker: Units.Unit, defender) -> void:
	# TODO: Implementar combate visual
	# Por ahora solo marcar como atacado
	attacker.attack_target()
	_clear_selection()

func _find_friendly_unit_at(coord: Vector2i) -> Units.Unit:
	if turn_manager == null:
		return null

	var current_player := turn_manager.get_current_player()
	if current_player == null:
		return null

	for unit in current_player.units:
		if unit.is_alive() and unit.position == coord:
			return unit
	return null

func _find_enemy_at(coord: Vector2i):
	if turn_manager == null:
		return null

	var current_player := turn_manager.get_current_player()
	if current_player == null:
		return null

	for player in turn_manager.players:
		if player.id == current_player.id or not player.is_alive:
			continue
		for unit in player.units:
			if unit.is_alive() and unit.position == coord:
				return unit
		for city in player.cities:
			if city.position == coord:
				return city
	return null

func _find_friendly_city_at(coord: Vector2i) -> Cities.City:
	if turn_manager == null:
		return null

	var current_player := turn_manager.get_current_player()
	if current_player == null:
		return null

	for city in current_player.cities:
		if city.position == coord:
			return city
	return null

func _has_enemy_unit_at(coord: Vector2i, owner_id: int) -> bool:
	if turn_manager == null:
		return false

	for player in turn_manager.players:
		if player.id == owner_id or not player.is_alive:
			continue
		for unit in player.units:
			if unit.is_alive() and unit.position == coord:
				return true
	return false

func _is_in_attack_range(attacker: Units.Unit, target) -> bool:
	var target_pos: Vector2i
	if target is Units.Unit:
		target_pos = target.position
	elif target is Cities.City:
		target_pos = target.position
	else:
		return false

	var dist := hex_grid.distance_wrappedv(attacker.position, target_pos)
	return dist <= attacker.rango_ataque

func _get_terrain_at(coord: Vector2i) -> String:
	if game_map != null and game_map.map_generator != null:
		var terrain_enum := game_map.map_generator.get_terrain(coord.x, coord.y)
		return _terrain_enum_to_string(terrain_enum)
	return "pradera"

func _terrain_enum_to_string(terrain_enum: int) -> String:
	match terrain_enum:
		0: return "pradera"
		1: return "bosque"
		2: return "montaña"
		3: return "agua"
		4: return "desierto"
		5: return "nieve"
	return "pradera"

# --- VISUAL HIGHLIGHTS ---

func _draw_unit_highlights(unit: Units.Unit) -> void:
	_clear_highlights()

	# Dibujar hexágonos alcanzables
	for hex in reachable_hexes:
		if hex == unit.position:
			continue
		var color := REACHABLE_COLOR
		color.a = 0.4
		_draw_hex_overlay(hex, color)

	# Dibujar rango de ataque
	if unit.rango_ataque > 1:
		var attack_hexes := hex_grid.get_hexes_in_rangev(unit.position, unit.rango_ataque)
		for hex in attack_hexes:
			if hex == unit.position:
				continue
			if not reachable_hexes.has(hex):
				var color := ATTACK_RANGE_COLOR
				color.a = 0.25
				_draw_hex_overlay(hex, color)

	# Dibujar selección actual
	var sel_color := HIGHLIGHT_COLOR
	sel_color.a = 0.6
	_draw_hex_overlay(unit.position, sel_color, true)

func _draw_city_highlight(city: Cities.City) -> void:
	_clear_highlights()
	var color := HIGHLIGHT_COLOR
	color.a = 0.5
	_draw_hex_overlay(city.position, color, true)

func _draw_hex_highlight(coord: Vector2i) -> void:
	_clear_highlights()
	var color := Color("#90CAF9")
	color.a = 0.4
	_draw_hex_overlay(coord, color)

func _draw_hex_overlay(coord: Vector2i, color: Color, with_border: bool = false) -> void:
	if hex_grid == null:
		return

	var polygon := _get_hex_polygon(coord)
	var overlay := Polygon2D.new()
	overlay.polygon = polygon
	overlay.color = color
	_movement_overlay.add_child(overlay)

	if with_border:
		var border := Line2D.new()
		border.points = PackedVector2Array(polygon)
		border.closed = true
		border.width = 2.0
		border.default_color = Color.WHITE
		_movement_overlay.add_child(border)

func _get_hex_polygon(coord: Vector2i) -> PackedVector2Array:
	var center := hex_grid.axial_to_pixelv(coord)
	var size := hex_grid.hex_size * 0.95  # Ligeramente más pequeño que el hex real
	var points := PackedVector2Array()
	for i in range(6):
		var angle := i * PI / 3.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points

func _clear_highlights() -> void:
	for child in _movement_overlay.get_children():
		child.queue_free()
