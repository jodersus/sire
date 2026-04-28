extends Node

## GameManager - Orquestador principal de SIRE
## Autoload singleton que conecta: TurnManager, HexGrid, GameMap, AIAdapter, HUD
## - Inicializa partida según config (tribu, bots, tamaño mapa)
## - Gestiona señales entre módulos
## - Procesa input del jugador y lo traduce a acciones de game logic
## - Actualiza HUD en cada cambio de estado

# ---------------------------------------------------------------------------
# REFERENCIAS (descubiertas en la escena actual)
# ---------------------------------------------------------------------------
var turn_manager: TurnManager
var hex_grid: HexGrid
var game_map: GameMap
var hud: CanvasLayer
var unit_renderer: UnitRenderer
var city_renderer: CityRenderer
var map_input: MapInputHandler
var _ai_adapters: Array = []

# ---------------------------------------------------------------------------
# ESTADO
# ---------------------------------------------------------------------------
var _game_initialized: bool = false
var _is_processing_ai: bool = false

# ---------------------------------------------------------------------------
# SEÑALES
# ---------------------------------------------------------------------------
signal game_started
signal turn_changed(player_id: int, player_name: String)
signal phase_changed(phase: int, phase_name: String)
signal resources_updated(stars: int, population: int)
signal event_logged(text: String)
signal game_over(winner_id: int, winner_name: String)

# ---------------------------------------------------------------------------
# CICLO DE VIDA
# ---------------------------------------------------------------------------
func _ready():
	pass

# ---------------------------------------------------------------------------
# INICIALIZACIÓN DE PARTIDA
# ---------------------------------------------------------------------------

## Inicializa una nueva partida según la configuración global (GameConfig)
func initialize_game() -> void:
	if _game_initialized:
		# Reiniciar estado si ya había una partida en curso
		_game_initialized = false
		if turn_manager != null:
			turn_manager.queue_free()
			turn_manager = null
		_ai_adapters.clear()
		if game_map != null:
			var spherical := game_map.get_node_or_null("WorldSphericalRenderer")
			if spherical != null and spherical.has_method("clear_copies"):
				spherical.clear_copies()

	_discover_references()

	if game_map == null:
		push_error("GameManager: GameMap no encontrado en la escena")
		return
	if hex_grid == null:
		push_error("GameManager: HexGrid no encontrado")
		return

	# Configurar tamaño del mapa
	var map_size: int = GameConfig.get_map_size()
	hex_grid.map_width = map_size
	hex_grid.map_height = map_size

	# Configurar generador
	if game_map.map_generator != null:
		game_map.map_generator.map_width = map_size
		game_map.map_generator.map_height = map_size
		game_map.map_generator.hex_grid = hex_grid

	# Generar mapa
	game_map.generate_map()

	# Configurar cámara
	if game_map.camera != null:
		game_map.camera.update_world_limits(hex_grid)

	# Inicializar renderer esférico si existe
	var spherical := game_map.get_node_or_null("WorldSphericalRenderer")
	if spherical != null and spherical.has_method("setup"):
		spherical.setup(game_map.tilemap, hex_grid)

	# Crear TurnManager
	turn_manager = TurnManager.new()
	turn_manager.hex_grid = hex_grid
	add_child(turn_manager)

	# Crear jugadores
	_init_players()

	# Posicionar unidades y ciudades iniciales
	_place_starting_cities_and_units()

	# Sincronizar visuales de unidades y ciudades
	if unit_renderer != null:
		unit_renderer.sync_from_players(turn_manager.players)
	if city_renderer != null:
		city_renderer.sync_from_players(turn_manager.players)

	# Inicializar IA
	_init_ai()

	# Configurar MapInputHandler
	if map_input != null:
		map_input.hex_grid = hex_grid
		map_input.game_map = game_map
		map_input.unit_renderer = unit_renderer
		map_input.city_renderer = city_renderer
		map_input.turn_manager = turn_manager

		# Conectar señales
		if not map_input.unit_selected.is_connected(_on_unit_selected):
			map_input.unit_selected.connect(_on_unit_selected)
		if not map_input.city_selected.is_connected(_on_city_selected):
			map_input.city_selected.connect(_on_city_selected)
		if not map_input.hex_selected.is_connected(_on_hex_selected):
			map_input.hex_selected.connect(_on_hex_selected)
		if not map_input.unit_moved.is_connected(_on_unit_moved):
			map_input.unit_moved.connect(_on_unit_moved)

	# Estado inicial del turno
	turn_manager.current_player = turn_manager.players[0]
	turn_manager.current_player_id = 0
	turn_manager.turn_number = 1

	_game_initialized = true
	game_started.emit()

	# Conectar señales de TurnManager
	if not turn_manager.game_over.is_connected(_on_game_over):
		turn_manager.game_over.connect(_on_game_over)

	_start_turn()
	log_event("Partida iniciada. Turno 1.")

## Descubre referencias en la escena cargada actualmente
func _discover_references() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return

	# GameMap puede estar en MapContainer/GameMap o directamente GameMap
	game_map = scene.get_node_or_null("MapContainer/GameMap")
	if game_map == null:
		game_map = scene.get_node_or_null("GameMap")

	# HUD
	hud = scene.get_node_or_null("HUD")

	if game_map != null:
		hex_grid = game_map.hex_grid
		unit_renderer = game_map.unit_renderer
		city_renderer = game_map.city_renderer

	# MapInputHandler puede estar en GameMap o como nodo independiente
	map_input = scene.get_node_or_null("GameMap/MapInputHandler")
	if map_input == null:
		map_input = scene.get_node_or_null("MapInputHandler")
	if map_input == null and game_map != null:
		# Crear input handler si no existe
		map_input = MapInputHandler.new()
		map_input.name = "MapInputHandler"
		game_map.add_child(map_input)

# ---------------------------------------------------------------------------
# JUGADORES
# ---------------------------------------------------------------------------

func _init_players() -> void:
	var total_players: int = 1 + GameConfig.bot_count
	var human_tribe_id: int = _tribe_name_to_id(GameConfig.selected_tribe)

	for i in range(total_players):
		var is_human: bool = (i == 0)
		var tribe_id: int = human_tribe_id if is_human else _get_random_tribe_except(human_tribe_id)
		var player_name: String = Tribes.get_tribe_name(tribe_id)
		var difficulty: int = SireAIController.Difficulty.NORMAL

		if not is_human:
			match GameConfig.bot_count:
				1:
					difficulty = SireAIController.Difficulty.HARD
				2:
					difficulty = SireAIController.Difficulty.NORMAL if i == 1 else SireAIController.Difficulty.EASY
				3:
					if i == 1:
						difficulty = SireAIController.Difficulty.NORMAL
					elif i == 2:
						difficulty = SireAIController.Difficulty.HARD
					else:
						difficulty = SireAIController.Difficulty.EASY

		var player := TurnManager.Player.new(i, player_name, tribe_id, is_human, difficulty)
		player.resources = GameResources.create_inventory()
		player.tech_tree = Technologies.create_tech_tree()

		turn_manager.players.append(player)

	turn_manager.player_count = total_players

## Posiciona ciudades capitales y unidades iniciales para cada jugador
func _place_starting_cities_and_units() -> void:
	var map_size: int = GameConfig.get_map_size()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var used_positions: Array[Vector2i] = []

	for player in turn_manager.players:
		var pos := Vector2i.ZERO
		var attempts := 0
		var valid := false

		while not valid and attempts < 100:
			pos = Vector2i(rng.randi() % map_size, rng.randi() % map_size)
			var terrain = game_map.map_generator.get_terrainv(pos)
			if terrain != MapGenerator.Terrain.AGUA and _position_valid(pos, used_positions):
				valid = true
			attempts += 1

		if not valid:
			pos = Vector2i(rng.randi() % map_size, rng.randi() % map_size)

		used_positions.append(pos)

		# Ciudad capital
		var city_name := "Capital " + player.name
		var city := Cities.create_city(city_name, player.id, player.tribe_id, pos)
		player.cities.append(city)

		# Unidad inicial según tribu
		var unit_type := Tribes.get_starting_unit(player.tribe_id)
		var unit := Units.create_unit(unit_type, player.id, player.tribe_id, pos)
		player.units.append(unit)

		# Recursos iniciales
		var starting := GameResources.get_starting_resources()
		player.resources.stars = starting.stars
		player.resources.wood = starting.wood
		player.resources.stone = starting.stone

func _position_valid(pos: Vector2i, used: Array[Vector2i]) -> bool:
	for other in used:
		if hex_grid.distance_wrappedv(pos, other) < 3:
			return false
	return true

# ---------------------------------------------------------------------------
# IA
# ---------------------------------------------------------------------------

func _init_ai() -> void:
	_ai_adapters.clear()
	for player in turn_manager.players:
		if not player.is_human and player.is_alive:
			var adapter := SireAIAdapter.new(
				turn_manager,
				hex_grid,
				game_map,
				player.id,
				player.ai_difficulty
			)
			_ai_adapters.append(adapter)

func _process_ai_turn(player) -> void:
	if _is_processing_ai:
		return
	_is_processing_ai = true

	var adapter = _find_adapter_for_player(player.id)
	if adapter != null:
		adapter.process_ai_turn()
		log_event("IA (%s) completó su turno." % player.name)

	await get_tree().create_timer(0.4).timeout
	_is_processing_ai = false
	_next_player()

func _find_adapter_for_player(player_id: int):
	for a in _ai_adapters:
		if a._player_id == player_id:
			return a
	return null

# ---------------------------------------------------------------------------
# GESTIÓN DE TURNOS
# ---------------------------------------------------------------------------

func _start_turn() -> void:
	if turn_manager.current_player == null:
		return

	var player = turn_manager.current_player
	
	# Procesar ingreso del turno
	player.collect_income()
	player.reset_units()
	player.process_training()
	
	turn_changed.emit(player.id, player.name)
	_update_hud()
	log_event("Turno de %s. Estrellas: %d" % [player.name, player.resources.stars])

	if not player.is_human:
		_process_ai_turn(player)

func _next_player() -> void:
	if turn_manager.players.is_empty():
		return

	turn_manager.current_player_id = (turn_manager.current_player_id + 1) % turn_manager.players.size()
	turn_manager.current_player = turn_manager.players[turn_manager.current_player_id]

	if turn_manager.current_player_id == 0:
		turn_manager.turn_number += 1
		log_event("Turno %d iniciado." % turn_manager.turn_number)

	_start_turn()

## Finaliza el turno del jugador humano manualmente
func end_current_turn() -> void:
	if turn_manager == null or turn_manager.current_player == null:
		return
	if not turn_manager.current_player.is_human:
		return
	_next_player()

# ---------------------------------------------------------------------------
# ACCIONES DE JUEGO
# ---------------------------------------------------------------------------

func city_action(action: String) -> void:
	if turn_manager == null or turn_manager.current_player == null:
		return
	var player = turn_manager.current_player
	
	# Obtener ciudad seleccionada desde el input handler
	var selected_city = null
	if map_input != null:
		selected_city = map_input.selected_city
	
	if selected_city == null:
		log_event("Ninguna ciudad seleccionada")
		return
	
	match action:
		"Entrenar unidad":
			_try_train_unit(player, selected_city)
		"Construir":
			_try_build(player, selected_city)
		"Subir nivel":
			_try_upgrade_city(player, selected_city)

func _try_train_unit(player, city) -> void:
	var cost := 3
	if player.resources.spend(GameResources.ResourceType.STARS, cost):
		var unit_type := Units.UnitType.GUERRERO
		var unit := Units.create_unit(unit_type, player.id, player.tribe_id, city.position)
		player.units.append(unit)
		if unit_renderer != null:
			unit_renderer.spawn_unit(unit)
		log_event("Entrenado: %s en %s" % [unit.get_name(), city.name])
		_update_hud()
	else:
		log_event("Estrellas insuficientes para entrenar")

func _try_build(player, city) -> void:
	var cost := 4
	if player.resources.spend(GameResources.ResourceType.STARS, cost):
		if city.buildings.size() < city.get_max_buildings():
			city.buildings.append(Cities.BuildingType.GRANJA)
			log_event("Construido en %s" % city.name)
			_update_hud()
		else:
			log_event("Limite de edificios alcanzado")
			player.resources.add(GameResources.ResourceType.STARS, cost)
	else:
		log_event("Estrellas insuficientes para construir")

func _try_upgrade_city(player, city) -> void:
	var cost := city.level * 5
	if player.resources.spend(GameResources.ResourceType.STARS, cost):
		city.level_up()
		if city_renderer != null:
			city_renderer.update_city(city)
		log_event("%s subio a nivel %d" % [city.name, city.level])
		_update_hud()
	else:
		log_event("Estrellas insuficientes para subir nivel")

func rest_selected_unit() -> void:
	if map_input != null and map_input.selected_unit != null:
		map_input.selected_unit.rest()
		log_event("Unidad descansada")

func open_tech_tree() -> void:
	if turn_manager == null or turn_manager.current_player == null:
		return
	var player = turn_manager.current_player
	log_event("Arbol de tecnologias (proximamente)")
	# TODO: Mostrar panel de tecnologias

# ---------------------------------------------------------------------------
# INPUT DEL JUGADOR
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _game_initialized:
		return
	if turn_manager == null or turn_manager.current_player == null:
		return
	if not turn_manager.current_player.is_human:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				end_current_turn()
			KEY_ESCAPE:
				_toggle_pause()

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		var pause_menu = preload("res://scenes/pause_menu.tscn").instantiate()
		get_tree().current_scene.add_child(pause_menu)

# ---------------------------------------------------------------------------
# CALLBACKS DE MAP INPUT
# ---------------------------------------------------------------------------

func _on_unit_selected(unit: Units.Unit) -> void:
	log_event("Unidad seleccionada: %s (%s)" % [unit.get_name(), Tribes.get_tribe_name(unit.tribe_id)])
	# Actualizar HUD con info de unidad
	if hud != null and hud.has_method("show_unit_actions"):
		var unit_info := _build_unit_info_dict(unit)
		hud.show_unit_actions(unit_info)

func _on_city_selected(city: Cities.City) -> void:
	log_event("Ciudad seleccionada: %s (Nivel %d)" % [city.name, city.level])
	if hud != null and hud.has_method("show_city_actions"):
		var city_info := _build_city_info_dict(city)
		hud.show_city_actions(city_info)

func _on_hex_selected(coord: Vector2i) -> void:
	# Click en hex vacío - ocultar panel de acciones
	if hud != null and hud.has_method("hide_action_panel"):
		hud.hide_action_panel()

func _on_unit_moved(unit: Units.Unit, _from: Vector2i, _to: Vector2i) -> void:
	log_event("Movimiento: %s a %s" % [unit.get_name(), str(_to)])
	_update_hud()

func _build_unit_info_dict(unit: Units.Unit) -> Dictionary:
	return {
		"name": unit.get_name(),
		"tribe": Tribes.get_tribe_name(unit.tribe_id),
		"hp": unit.current_health,
		"max_hp": unit.max_health,
		"attack": unit.attack,
		"defense": unit.defense,
		"movement": unit.movimientos_restantes,
		"max_movement": unit.movement,
		"rango": unit.rango_ataque,
		"actions": ["Mover", "Atacar", "Descansar"] if unit.movimientos_restantes > 0 else ["Descansar"],
	}

func _build_city_info_dict(city: Cities.City) -> Dictionary:
	return {
		"name": city.name,
		"level": city.level,
		"population": city.population,
		"max_pop": city.get_max_population(),
		"stars_per_turn": city.get_stars_per_turn(),
		"buildings": city.buildings.size(),
		"actions": ["Entrenar unidad", "Construir", "Subir nivel"],
	}

# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func _update_hud() -> void:
	if hud == null:
		return
	var player = turn_manager.current_player
	if player == null:
		return

	GameConfig.current_turn = turn_manager.turn_number
	GameConfig.player_stars = player.resources.stars
	GameConfig.player_population = _count_population(player)

	if hud.has_method("update_resource_display"):
		hud.update_resource_display()
	if hud.has_method("update_phase_display"):
		hud.update_phase_display()

func log_event(text: String) -> void:
	event_logged.emit(text)
	if hud != null and hud.has_method("add_event"):
		hud.add_event(text)

func _count_population(player) -> int:
	var pop := 0
	for city in player.cities:
		pop += city.population
	return pop

# ---------------------------------------------------------------------------
# UTILIDADES
# ---------------------------------------------------------------------------

func _tribe_name_to_id(name: String) -> int:
	for tid in Tribes.TribeID.values():
		if Tribes.get_tribe_name(tid) == name:
			return tid
	return Tribes.TribeID.SOLARIS

func _get_random_tribe_except(except_id: int) -> int:
	var tribes = Tribes.get_all_tribe_ids()
	var options := tribes.filter(func(t): return t != except_id)
	if options.is_empty():
		return Tribes.TribeID.SOLARIS
	return options[randi() % options.size()]

# ---------------------------------------------------------------------------
# FIN DE PARTIDA
# ---------------------------------------------------------------------------

func _on_game_over(winner_id: int, victory_type: String) -> void:
	var winner_name := ""
	for player in turn_manager.players:
		if player.id == winner_id:
			winner_name = player.name
			break

	# Mostrar pantalla de victoria/derrota
	var game_over_screen := get_tree().current_scene.get_node_or_null("GameOverScreen")
	if game_over_screen == null:
		game_over_screen = get_tree().current_scene.get_node_or_null("UI/GameOverScreen")

	if game_over_screen != null and game_over_screen.has_method("show_victory"):
		var current_player := turn_manager.get_current_player()
		var is_human_winner := false
		for player in turn_manager.players:
			if player.id == winner_id and player.is_human:
				is_human_winner = true
				break

		var score := _calculate_winner_score(winner_id)
		if is_human_winner:
			game_over_screen.show_victory(winner_name, turn_manager.turn_number, score)
		else:
			game_over_screen.show_defeat(winner_name, turn_manager.turn_number)
	else:
		# Fallback: log en eventos
		if victory_type == "dominacion":
			log_event("Victoria por dominación: %s" % winner_name)
		else:
			log_event("Victoria por puntuación: %s" % winner_name)

func _calculate_winner_score(player_id: int) -> int:
	for player in turn_manager.players:
		if player.id == player_id:
			return _calculate_player_score(player)
	return 0

func _calculate_player_score(player) -> int:
	var score := 0
	for city in player.cities:
		score += city.level * 20
	for unit in player.units:
		if unit.is_alive():
			score += Units.get_unit_cost(unit.type)
	for tech_id in player.tech_tree.researched:
		score += Technologies.get_tech_cost(tech_id)
	score += player.resources.stars
	return score
