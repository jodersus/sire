extends Node
class_name TurnManager

## TurnManager.gd - Gestor de turnos de Sire
## Fases: ingreso, tecnología, movimiento, combate, construcción
## Turnos por jugador

enum Phase {
	INCOME,        ## Ingreso de recursos
	TECHNOLOGY,    ## Investigación de tecnologías
	MOVEMENT,      ## Movimiento de unidades
	COMBAT,        ## Resolución de combates
	CONSTRUCTION   ## Construcción de edificios y entrenamiento
}

const PHASE_NAMES: Dictionary = {
	Phase.INCOME: "Ingreso",
	Phase.TECHNOLOGY: "Tecnología",
	Phase.MOVEMENT: "Movimiento",
	Phase.COMBAT: "Combate",
	Phase.CONSTRUCTION: "Construcción"
}

## Datos de un jugador en la partida
class Player:
	var id: int
	var name: String
	var tribe_id: Tribes.TribeID
	var resources: GameResources.ResourceInventory
	var tech_tree: Technologies.TechnologyTree
	var cities: Array[Cities.City]
	var units: Array[Units.Unit]
	var is_alive: bool
	var has_surrendered: bool
	var is_human: bool = true
	var ai_difficulty: int = 0
	
	func _init(player_id: int, player_name: String, tribe: Tribes.TribeID, p_human: bool = true, p_difficulty: int = 0):
		id = player_id
		name = player_name
		tribe_id = tribe
		is_human = p_human
		ai_difficulty = p_difficulty
		resources = GameResources.create_inventory()
		tech_tree = Technologies.create_tech_tree()
		cities = []
		units = []
		is_alive = true
		has_surrendered = false
	
	## Añade recursos iniciales
	func setup_starting_resources():
		var starting: Dictionary = GameResources.get_starting_resources()
		resources.stars = starting.stars
		resources.wood = starting.wood
		resources.stone = starting.stone
		resources.fruits = starting.fruits
		resources.fish = starting.fish
	
	## Calcula y recolecta recursos del turno
	func collect_income():
		var tech_bonuses: Dictionary = tech_tree.get_passive_bonuses()
		resources.calculate_production(cities, tech_bonuses)
		resources.collect_production()
	
	## Resetea unidades para nuevo turno
	func reset_units():
		for unit in units:
			if unit.is_alive():
				unit.reset_turn()
	
	## Procesa colas de entrenamiento en ciudades
	func process_training() -> Array[Dictionary]:
		var new_units: Array[Dictionary] = []
		
		for city in cities:
			var completed: Array[Units.UnitType] = city.process_training()
			for unit_type in completed:
				new_units.append({
					"unit_type": unit_type,
					"city": city,
					"position": city.position
				})
		
		return new_units
	
	## Comprueba si el jugador sigue vivo
	func check_alive() -> bool:
		if has_surrendered:
			is_alive = false
			return false
		
		## Un jugador sin ciudades durante 3 turnos pierde
		if cities.is_empty():
			## Nota: implementar contador de turnos sin ciudades
			is_alive = false
			return false
		
		return is_alive

## Estado del gestor de turnos
var current_phase: Phase
var current_player_index: int
var current_player: Player
var current_player_id: int
var players: Array[Player]
var turn_number: int
var phase_completed: bool

## Configuración de partida
var max_turns: int  ## 0 = ilimitado

func _init():
	current_phase = Phase.INCOME
	current_player_index = 0
	current_player = null
	current_player_id = 0
	players = []
	turn_number = 1
	phase_completed = false
	max_turns = 0

## Añade un jugador a la partida
func add_player(player_name: String, tribe_id: Tribes.TribeID) -> Player:
	var player := Player.new(players.size(), player_name, tribe_id)
	players.append(player)
	return player

## Inicializa la partida
func start_game():
	turn_number = 1
	current_phase = Phase.INCOME
	current_player_index = 0
	
	for player in players:
		player.setup_starting_resources()
		## Añadir unidad inicial
		var starting_unit: Units.UnitType = Tribes.get_starting_unit(player.tribe_id)
		## La posición inicial se asigna desde el gestor de mapa
		## Aquí solo preparamos la unidad

## Avanza a la siguiente fase
## Devuelve true si se completó un ciclo de turno completo
func next_phase() -> bool:
	phase_completed = true
	
	match current_phase:
		Phase.INCOME:
			_execute_income_phase()
			current_phase = Phase.TECHNOLOGY
		
		Phase.TECHNOLOGY:
			current_phase = Phase.MOVEMENT
		
		Phase.MOVEMENT:
			current_phase = Phase.COMBAT
		
		Phase.COMBAT:
			current_phase = Phase.CONSTRUCTION
		
		Phase.CONSTRUCTION:
			_execute_construction_phase()
			current_phase = Phase.INCOME
			return _next_player()
	
	return false

## Ejecuta la fase de ingreso para el jugador actual
func _execute_income_phase():
	var player: Player = get_current_player()
	if not player.is_alive:
		return
	
	player.collect_income()
	player.reset_units()

## Ejecuta la fase de construcción para el jugador actual
func _execute_construction_phase():
	var player: Player = get_current_player()
	if not player.is_alive:
		return
	
	## Procesar entrenamiento de unidades
	var new_units: Array[Dictionary] = player.process_training()
	
	## Notificar nuevas unidades (el caller debe añadirlas al mapa)
	## Se devuelven vía señal o retorno
	emit_signal("units_trained", new_units)

## Avanza al siguiente jugador
## Devuelve true si se completó un turno completo (todos los jugadores)
func _next_player() -> bool:
	current_player_index += 1
	
	if current_player_index >= players.size():
		current_player_index = 0
		turn_number += 1
		
		## Comprobar fin de partida
		_check_game_end()
		return true  ## Nuevo turno completo
	
	_update_current_player()
	return false

func _update_current_player():
	if players.is_empty():
		current_player = null
		current_player_id = -1
		return
	current_player = players[current_player_index]
	current_player_id = current_player.id

## Salta al siguiente jugador vivo
func skip_to_next_alive_player():
	var original_index: int = current_player_index
	
	while true:
		current_player_index += 1
		if current_player_index >= players.size():
			current_player_index = 0
			turn_number += 1
		
		if players[current_player_index].is_alive:
			break
		
		## Evitar bucle infinito si todos están muertos
		if current_player_index == original_index:
			break
	
	_update_current_player()

## Devuelve el jugador actual
func get_current_player() -> Player:
	if players.is_empty():
		return null
	return players[current_player_index]

## Devuelve la fase actual como string
func get_current_phase_name() -> String:
	return PHASE_NAMES.get(current_phase, "Desconocido")

## Comprueba si un jugador puede actuar en la fase actual
func can_player_act(player_id: int) -> bool:
	var player: Player = get_current_player()
	if player == null:
		return false
	return player.id == player_id and player.is_alive

## Finaliza manualmente la fase actual (jugador pasa)
func end_phase_early():
	phase_completed = true

## Comprueba condiciones de victoria/derrota
func _check_game_end():
	var alive_players: Array[Player] = []
	
	for player in players:
		if player.check_alive():
			alive_players.append(player)
	
	## Victoria por dominación: solo queda un jugador
	if alive_players.size() == 1:
		emit_signal("game_over", alive_players[0].id, "dominacion")
	
	## Victoria por turnos máximos: mayor puntuación
	if max_turns > 0 and turn_number > max_turns:
		var winner: Player = _calculate_score_winner()
		emit_signal("game_over", winner.id, "puntuacion")

## Calcula el ganador por puntuación
func _calculate_score_winner() -> Player:
	var best_player: Player = players[0]
	var best_score: int = _calculate_score(players[0])
	
	for player in players:
		var score: int = _calculate_score(player)
		if score > best_score:
			best_score = score
			best_player = player
	
	return best_player

## Calcula la puntuación de un jugador
func _calculate_score(player: Player) -> int:
	var score: int = 0
	
	## Ciudades: 20 puntos por nivel
	for city in player.cities:
		score += city.level * 20
	
	## Unidades: coste en estrellas
	for unit in player.units:
		if unit.is_alive():
			score += Units.get_unit_cost(unit.type)
	
	## Tecnologías: coste total
	for tech_id in player.tech_tree.researched:
		score += Technologies.get_tech_cost(tech_id)
	
	## Recursos actuales
	score += player.resources.stars
	score += player.resources.wood
	score += player.resources.stone
	
	return score

## Devuelve la lista de jugadores vivos
func get_alive_players() -> Array[Player]:
	var alive: Array[Player] = []
	for player in players:
		if player.is_alive:
			alive.append(player)
	return alive

## Devuelve el número de jugadores
func get_player_count() -> int:
	return players.size()

## Devuelve el número de jugadores vivos
func get_alive_player_count() -> int:
	return get_alive_players().size()

## Señales para comunicación con el gestor de juego
signal units_trained(new_units: Array[Dictionary])
signal game_over(winner_id: int, victory_type: String)
signal phase_changed(new_phase: Phase)
signal player_turn_started(player_id: int, turn_number: int)
