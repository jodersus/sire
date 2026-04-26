class_name SireAIAdapter
extends RefCounted
## Adapter that connects SireAIController to the real game systems.
## Converts TurnManager / Player data to AI-readable format.
## Executes AI decisions back into the game state.

var ai_controller: SireAIController
var turn_manager: TurnManager
var hex_grid: HexGrid
var game_map: GameMap

var _player_id: int = -1
var _player: TurnManager.Player = null

## Create an AI adapter for a specific player.
func _init(
	manager: TurnManager,
	grid: HexGrid,
	map_node: GameMap,
	player_id: int,
	difficulty: int = SireAIController.Difficulty.NORMAL
) -> void:
	turn_manager = manager
	hex_grid = grid
	game_map = map_node
	_player_id = player_id
	
	ai_controller = SireAIController.new(difficulty)
	_setup_callbacks()

## Configure the AI with real game state callbacks.
func _setup_callbacks() -> void:
	ai_controller.setup(
		ai_controller.difficulty,
		_get_tribe_name(),
		_get_game_state,
		_get_units,
		_get_cities,
		_get_enemy_units,
		_get_enemy_cities,
		_get_map_tile,
		_execute_action
	)

## -- STATE QUERY CALLBACKS --

func _get_game_state() -> Dictionary:
	_update_player_ref()
	if _player == null:
		return {"stars": 0, "available_techs": [], "known_techs": [], "turn": turn_manager.turn_number}
	
	var available_techs: Array = []
	for tech_id in _player.tech_tree.available:
		var data := Technologies.get_tech_data(tech_id)
		available_techs.append({
			"name": data.get("name", ""),
			"cost": data.get("cost", 0),
			"id": tech_id,
		})
	
	var known_techs: Array = []
	for tech_id in _player.tech_tree.researched:
		known_techs.append(Technologies.get_tech_name(tech_id))
	
	return {
		"turn": turn_manager.turn_number,
		"stars": _player.resources.stars,
		"owned_cities": _player.cities.size(),
		"owned_units": _player.units.size(),
		"enemy_cities": _count_enemy_cities(),
		"enemy_units": _count_enemy_units(),
		"known_techs": known_techs,
		"available_techs": available_techs,
		"phase": _phase_name(turn_manager.current_phase),
	}

func _get_units() -> Array:
	_update_player_ref()
	if _player == null:
		return []
	
	var result: Array = []
	for unit in _player.units:
		if not unit.is_alive():
			continue
		result.append({
			"id": str(unit.owner_id) + "_" + str(unit.type) + "_" + str(unit.position),
			"type": Units.get_unit_name(unit.type),
			"type_enum": unit.type,
			"coord": unit.position,
			"movement": unit.movimientos_restantes,
			"hp": unit.current_health,
			"max_hp": unit.max_health,
			"attack": unit.attack,
			"defense": unit.defense,
			"rango": unit.rango_ataque,
			"naval": unit.naval,
			"state": unit.state,
		})
	return result

func _get_cities() -> Array:
	_update_player_ref()
	if _player == null:
		return []
	
	var result: Array = []
	for city in _player.cities:
		var is_coastal := _is_city_coastal(city)
		result.append({
			"id": str(city.owner_id) + "_" + city.name,
			"name": city.name,
			"coord": city.position,
			"level": city.level,
			"population": city.population,
			"max_pop": city.get_max_population(),
			"stars_per_turn": city.get_stars_per_turn(),
			"is_coastal": is_coastal,
			"has_port": city.buildings.has(Cities.BuildingType.PUERTO),
			"buildings": city.buildings,
			"training_queue": city.training_queue,
			"under_siege": city.under_siege,
		})
	return result

func _get_enemy_units() -> Array:
	var result: Array = []
	for player in turn_manager.players:
		if player.id == _player_id or not player.is_alive:
			continue
		for unit in player.units:
			if not unit.is_alive():
				continue
			var dist := _distance_to_nearest_player_unit(unit.position)
			result.append({
				"id": str(unit.owner_id) + "_" + str(unit.type) + "_" + str(unit.position),
				"type": Units.get_unit_name(unit.type),
				"coord": unit.position,
				"hp": unit.current_health,
				"defense": unit.defense,
				"attack": unit.attack,
				"is_city": false,
				"distance": dist,
				"owner": player.id,
			})
	return result

func _get_enemy_cities() -> Array:
	var result: Array = []
	for player in turn_manager.players:
		if player.id == _player_id or not player.is_alive:
			continue
		for city in player.cities:
			var dist := _distance_to_nearest_player_city(city.position)
			var defenders := _count_defenders(city)
			result.append({
				"id": str(city.owner_id) + "_" + city.name,
				"name": city.name,
				"coord": city.position,
				"level": city.level,
				"is_city": true,
				"distance": dist,
				"defenders": defenders,
				"owner": player.id,
			})
	return result

func _get_map_tile(coord: Vector2i) -> Dictionary:
	var wrapped := hex_grid.wrap_axialv(coord)
	var terrain_type: String = "pradera"
	
	if game_map != null and game_map.map_generator != null:
		var terrain_enum: MapGenerator.Terrain = game_map.map_generator.get_terrain(wrapped.x, wrapped.y)
		terrain_type = _terrain_enum_to_string(terrain_enum)
	
	var has_enemy := false
	var occupied_by_enemy := false
	for player in turn_manager.players:
		if player.id == _player_id or not player.is_alive:
			continue
		for unit in player.units:
			if unit.is_alive() and unit.position == wrapped:
				has_enemy = true
				occupied_by_enemy = true
				break
		if has_enemy:
			break
	
	var has_city := false
	var is_friendly := false
	if _player != null:
		for city in _player.cities:
			if city.position == wrapped:
				has_city = true
				is_friendly = true
				break
	
	return {
		"terrain": terrain_type,
		"passable": terrain_type != "agua",
		"has_enemy": has_enemy,
		"occupied_by_enemy": occupied_by_enemy,
		"has_city": has_city,
		"is_friendly_territory": is_friendly,
		"unexplored": false,  ## Would need fog-of-war system
		"has_resource": terrain_type in ["bosque", "montana", "agua"],
	}

## -- ACTION EXECUTION --

func _execute_action(action: Dictionary) -> bool:
	_update_player_ref()
	if _player == null:
		return false
	
	var type: int = action.get("type", -1)
	
	match type:
		SireAIDecision.ActionType.TECH_RESEARCH:
			return _execute_research(action)
		SireAIDecision.ActionType.UNIT_MOVE:
			return _execute_unit_move(action)
		SireAIDecision.ActionType.UNIT_ATTACK:
			return _execute_unit_attack(action)
		SireAIDecision.ActionType.UNIT_FOUND_CITY:
			return _execute_found_city(action)
		SireAIDecision.ActionType.UNIT_EXPLORE:
			return _execute_explore(action)
		SireAIDecision.ActionType.CITY_BUILD_UNIT:
			return _execute_build_unit(action)
		SireAIDecision.ActionType.CITY_BUILD_BUILDING:
			return _execute_build_building(action)
		SireAIDecision.ActionType.CITY_GROW:
			return _execute_city_grow(action)
		_:
			return false

func _execute_research(action: Dictionary) -> bool:
	var tech_name: String = action.get("tech", "")
	var tech_id := _find_tech_by_name(tech_name)
	if tech_id == -1:
		return false
	
	if not _player.tech_tree.available.has(tech_id):
		return false
	
	var data := Technologies.get_tech_data(tech_id)
	var cost: int = data.get("cost", 0)
	
	## Apply Solaris discount
	if Tribes.has_ability(_player.tribe_id, "tech_discount"):
		cost = int(Tribes.apply_bonus(_player.tribe_id, "tech_discount", cost))
	
	if _player.resources.stars < cost:
		return false
	
	_player.resources.stars -= cost
	_player.tech_tree.researched.append(tech_id)
	_player.tech_tree.available.erase(tech_id)
	
	## Update available techs
	var new_available := _player.tech_tree._update_available()
	for tech in new_available:
		if not _player.tech_tree.available.has(tech):
			_player.tech_tree.available.append(tech)
	
	return true

func _execute_unit_move(action: Dictionary) -> bool:
	var unit_id: String = action.get("unit_id", "")
	var target: Vector2i = action.get("target_coord", Vector2i.ZERO)
	
	var unit := _find_unit_by_id(unit_id)
	if unit == null:
		return false
	
	## Use pathfinding to get actual path
	var get_terrain := func(c: Vector2i) -> String:
		var t = _get_map_tile(c)
		return t.get("terrain", "pradera")
	
	var is_passable := func(c: Vector2i) -> bool:
		var t = _get_map_tile(c)
		var terrain: String = t.get("terrain", "pradera")
		if terrain == "agua" and not unit.naval:
			return false
		if terrain != "agua" and unit.naval:
			return false
		return not t.get("occupied_by_enemy", false)
	
	var path := ai_controller.pathfinding.find_path(
		unit.position, target, get_terrain, is_passable, unit.movimientos_restantes
	)
	
	if path.size() <= 1:
		return false
	
	## Move along path as far as movement allows
	var moved := false
	for i in range(1, path.size()):
		var step := path[i]
		var terrain: String = get_terrain.call(step)
		var cost: int = Units.get_terrain_movement_cost(unit.type, terrain)
		if cost < 0:
			break
		if not unit.move_to(step, cost):
			break
		moved = true
		if unit.movimientos_restantes <= 0:
			break
	
	return moved

func _execute_unit_attack(action: Dictionary) -> bool:
	var unit_id: String = action.get("unit_id", "")
	var target_id: String = action.get("target_id", "")
	
	var unit := _find_unit_by_id(unit_id)
	if unit == null:
		return false
	
	## Find target
	var target_unit := _find_enemy_unit_by_id(target_id)
	if target_unit != null:
		var dist := hex_grid.distance_wrappedv(unit.position, target_unit.position)
		if dist > unit.rango_ataque:
			return false
		if not unit.attack_target():
			return false
		## Actual combat damage would be handled by a combat system
		## Here we just mark the attack
		return true
	
	## Check if target is a city
	var target_city := _find_enemy_city_by_id(target_id)
	if target_city != null:
		var dist := hex_grid.distance_wrappedv(unit.position, target_city.position)
		if dist > unit.rango_ataque:
			return false
		if not unit.attack_target():
			return false
		return true
	
	return false

func _execute_found_city(action: Dictionary) -> bool:
	var unit_id: String = action.get("unit_id", "")
	var unit := _find_unit_by_id(unit_id)
	if unit == null:
		return false
	if not unit.can_found_city():
		return false
	
	var city_name := "Ciudad " + str(_player.cities.size() + 1)
	var city := Cities.create_city(city_name, _player_id, _player.tribe_id, unit.position)
	_player.cities.append(city)
	
	## Remove the explorer (it becomes the city)
	unit.current_health = 0
	unit.end_turn()
	
	return true

func _execute_explore(action: Dictionary) -> bool:
	var unit_id: String = action.get("unit_id", "")
	var unit := _find_unit_by_id(unit_id)
	if unit == null:
		return false
	
	## Find nearest unexplored or interesting tile
	var best_dir := Vector2i.ZERO
	var best_score := -1
	
	for dir in HexGrid.NEIGHBORS:
		var check := hex_grid.wrap_axialv(unit.position + dir)
		var tile := _get_map_tile(check)
		var score := 0
		if tile.get("unexplored", false):
			score += 10
		if tile.get("has_resource", false):
			score += 5
		if not tile.get("has_enemy", false):
			score += 3
		if score > best_score:
			best_score = score
			best_dir = dir
	
	if best_dir == Vector2i.ZERO:
		best_dir = HexGrid.NEIGHBORS[0]
	
	var target := hex_grid.wrap_axialv(unit.position + best_dir)
	var terrain: String = _get_map_tile(target).get("terrain", "pradera")
	var cost := Units.get_terrain_movement_cost(unit.type, terrain)
	if cost > 0:
		return unit.move_to(target, cost)
	return false

func _execute_build_unit(action: Dictionary) -> bool:
	var city_id: String = action.get("city_id", "")
	var unit_name: String = action.get("unit_type", "")
	var unit_type := _find_unit_type_by_name(unit_name)
	if unit_type == -1:
		return false
	
	var city := _find_city_by_id(city_id)
	if city == null:
		return false
	
	## Check if tech-unlocked
	if not _player.tech_tree.is_unit_unlocked(unit_type):
		return false
	
	## Check naval requirement
	var stats := Units.get_unit_stats(unit_type)
	if stats.get("naval", false) and not city.buildings.has(Cities.BuildingType.PUERTO):
		return false
	
	var cost: int = Units.get_unit_cost(unit_type)
	
	## Apply Forja discount
	if city.buildings.has(Cities.BuildingType.FORJA):
		cost = int(cost * 0.9)
	
	## Apply tribe discount (Sylva wood is handled in city.build_building, not here)
	if Tribes.has_ability(_player.tribe_id, "tech_discount"):
		## Actually Solaris doesn't discount units, this is a placeholder
		pass
	
	if _player.resources.stars < cost:
		return false
	
	if not city.queue_unit(unit_type):
		return false
	
	_player.resources.stars -= cost
	return true

func _execute_build_building(action: Dictionary) -> bool:
	var city_id: String = action.get("city_id", "")
	var building_name: String = action.get("building", "")
	var building := _find_building_type_by_name(building_name)
	if building == -1:
		return false
	
	var city := _find_city_by_id(city_id)
	if city == null:
		return false
	
	## Check if tech-unlocked
	if not _player.tech_tree.is_building_unlocked(building):
		return false
	
	## Check terrain requirements
	var data := Cities.get_building_data(building)
	if data.get("requires_water", false) and not _is_city_coastal(city):
		return false
	
	var resources := {
		"stars": _player.resources.stars,
		"wood": _player.resources.wood,
		"stone": _player.resources.stone,
	}
	
	if not city.can_build_building(building, resources):
		return false
	
	var costs := city.build_building(building)
	_player.resources.stars -= costs.get("stars", 0)
	_player.resources.wood -= costs.get("wood", 0)
	_player.resources.stone -= costs.get("stone", 0)
	
	return true

func _execute_city_grow(action: Dictionary) -> bool:
	var city_id: String = action.get("city_id", "")
	var city := _find_city_by_id(city_id)
	if city == null:
		return false
	
	return city.level_up(_player.resources.stars)

## -- PUBLIC INTERFACE --

## Process the AI turn. Call when it's this player's phase.
func process_ai_turn() -> Array:
	_update_player_ref()
	if _player == null or not _player.is_alive:
		return []
	
	var decisions := ai_controller.process_turn()
	ai_controller.execute_turn()
	return decisions

## Get the AI controller for direct access.
func get_ai_controller() -> SireAIController:
	return ai_controller

## Serialize AI state for save games.
func serialize() -> Dictionary:
	return {
		"player_id": _player_id,
		"ai": ai_controller.serialize(),
	}

func deserialize(data: Dictionary) -> void:
	_player_id = data.get("player_id", -1)
	ai_controller.deserialize(data.get("ai", {}))

## -- INTERNAL HELPERS --

func _update_player_ref() -> void:
	if _player != null and _player.id == _player_id:
		return
	for p in turn_manager.players:
		if p.id == _player_id:
			_player = p
			return
	_player = null

func _get_tribe_name() -> String:
	_update_player_ref()
	if _player == null:
		return ""
	return Tribes.get_tribe_name(_player.tribe_id)

func _find_unit_by_id(unit_id: String) -> Units.Unit:
	if _player == null:
		return null
	for unit in _player.units:
		if unit.is_alive():
			var id := str(unit.owner_id) + "_" + str(unit.type) + "_" + str(unit.position)
			if id == unit_id:
				return unit
	return null

func _find_city_by_id(city_id: String) -> Cities.City:
	if _player == null:
		return null
	for city in _player.cities:
		var id := str(city.owner_id) + "_" + city.name
		if id == city_id:
			return city
	return null

func _find_enemy_unit_by_id(unit_id: String) -> Units.Unit:
	for player in turn_manager.players:
		if player.id == _player_id or not player.is_alive:
			continue
		for unit in player.units:
			if unit.is_alive():
				var id := str(unit.owner_id) + "_" + str(unit.type) + "_" + str(unit.position)
				if id == unit_id:
					return unit
	return null

func _find_enemy_city_by_id(city_id: String) -> Cities.City:
	for player in turn_manager.players:
		if player.id == _player_id or not player.is_alive:
			continue
		for city in player.cities:
			var id := str(city.owner_id) + "_" + city.name
			if id == city_id:
				return city
	return null

func _find_tech_by_name(tech_name: String) -> int:
	for tech_id in Technologies.TechID.values():
		var data := Technologies.get_tech_data(tech_id)
		if data.get("name", "") == tech_name:
			return tech_id
	return -1

func _find_unit_type_by_name(unit_name: String) -> int:
	for unit_type in Units.UnitType.values():
		if Units.get_unit_name(unit_type) == unit_name:
			return unit_type
	return -1

func _find_building_type_by_name(building_name: String) -> int:
	for building in Cities.BuildingType.values():
		if Cities.get_building_name(building) == building_name:
			return building
	return -1

func _count_enemy_cities() -> int:
	var count := 0
	for player in turn_manager.players:
		if player.id != _player_id and player.is_alive:
			count += player.cities.size()
	return count

func _count_enemy_units() -> int:
	var count := 0
	for player in turn_manager.players:
		if player.id != _player_id and player.is_alive:
			for unit in player.units:
				if unit.is_alive():
					count += 1
	return count

func _distance_to_nearest_player_unit(coord: Vector2i) -> float:
	if _player == null:
		return 999.0
	var min_dist := 999.0
	for unit in _player.units:
		if unit.is_alive():
			var dist := hex_grid.distance_wrappedv(unit.position, coord)
			if dist < min_dist:
				min_dist = dist
	return min_dist

func _distance_to_nearest_player_city(coord: Vector2i) -> float:
	if _player == null:
		return 999.0
	var min_dist := 999.0
	for city in _player.cities:
		var dist := hex_grid.distance_wrappedv(city.position, coord)
		if dist < min_dist:
			min_dist = dist
	return min_dist

func _count_defenders(city: Cities.City) -> int:
	var count := 0
	for player in turn_manager.players:
		if player.id != city.owner_id:
			continue
		for unit in player.units:
			if unit.is_alive() and unit.position == city.position:
				count += 1
	return count

func _is_city_coastal(city: Cities.City) -> bool:
	for n in hex_grid.get_neighborsv(city.position):
		var t = _get_map_tile(n)
		if t.get("terrain", "") == "agua":
			return true
	return false

func _terrain_enum_to_string(terrain_enum: int) -> String:
	match terrain_enum:
		0: return "pradera"
		1: return "bosque"
		2: return "montana"
		3: return "agua"
		4: return "desierto"
		5: return "nieve"
	return "pradera"

func _phase_name(phase: int) -> String:
	match phase:
		TurnManager.Phase.INCOME: return "income"
		TurnManager.Phase.TECHNOLOGY: return "technology"
		TurnManager.Phase.MOVEMENT: return "movement"
		TurnManager.Phase.COMBAT: return "combat"
		TurnManager.Phase.CONSTRUCTION: return "construction"
	return "unknown"
