class_name SireAIController
extends RefCounted
## Main AI controller for Sire. Orchestrates decision-making across turn phases.
## Supports Easy, Normal, Hard difficulty.
## No UI dependencies. Fully testable via injected state callbacks.

## Difficulty levels
enum Difficulty {
	EASY,
	NORMAL,
	HARD,
}

## Turn phases
enum Phase {
	INCOME,
	TECHNOLOGY,
	MOVEMENT,
	COMBAT,
	CONSTRUCTION,
}

## Signals (for game integration, but not required for testing)
signal decision_made(action: Dictionary)
signal phase_completed(phase: Phase)
signal turn_completed(turn_number: int)

## Configuration
var difficulty: int = Difficulty.NORMAL
var tribe_name: String = ""

## Subsystems
var pathfinding: SirePathfinding
var decision_engine: SireAIDecision
var strategy_manager: SireAIStrategies

## State interface (injected, no direct game node references)
## These callables allow the AI to query game state without coupling.
var get_game_state: Callable  ## () -> Dictionary (full game state)
var get_units: Callable       ## () -> Array[Dictionary] (AI's units)
var get_cities: Callable      ## () -> Array[Dictionary] (AI's cities)
var get_enemy_units: Callable ## () -> Array[Dictionary] (visible enemies)
var get_enemy_cities: Callable ## () -> Array[Dictionary] (visible enemy cities)
var get_map_tile: Callable    ## (coord: Vector2i) -> Dictionary (terrain info)
var execute_action: Callable  ## (action: Dictionary) -> bool

## Internal state
var _current_turn: int = 0
var _current_phase: int = Phase.INCOME
var _decisions_this_turn: Array = []
var _forgotten_units: Array = []  ## Easy difficulty: units the AI "forgets"
var _rng := RandomNumberGenerator.new()

## Tracking for hard difficulty
var _unit_last_positions: Dictionary = {}  ## unit_id -> Vector2i
var _city_production_queue: Dictionary = {}  ## city_id -> planned builds
var _attack_plans: Array = []  ## planned multi-turn attacks

func _init(ai_difficulty: int = Difficulty.NORMAL):
	difficulty = ai_difficulty
	_rng.randomize()
	pathfinding = SirePathfinding.new()
	strategy_manager = SireAIStrategies.new(SireAIStrategies.StrategyType.BALANCED)
	decision_engine = SireAIDecision.new(strategy_manager.get_weights())

## Setup the AI with state query callbacks.
## All callables are optional; if null, the AI operates in limited/test mode.
func setup(
	ai_difficulty: int,
	ai_tribe: String,
	game_state_cb: Callable = Callable(),
	units_cb: Callable = Callable(),
	cities_cb: Callable = Callable(),
	enemy_units_cb: Callable = Callable(),
	enemy_cities_cb: Callable = Callable(),
	map_tile_cb: Callable = Callable(),
	execute_cb: Callable = Callable()
) -> void:
	difficulty = ai_difficulty
	tribe_name = ai_tribe
	get_game_state = game_state_cb
	get_units = units_cb
	get_cities = cities_cb
	get_enemy_units = enemy_units_cb
	get_enemy_cities = enemy_cities_cb
	get_map_tile = map_tile_cb
	execute_action = execute_cb
	
	## Configure subsystems per difficulty
	_setup_for_difficulty()

## Configure behavior based on difficulty.
func _setup_for_difficulty() -> void:
	match difficulty:
		Difficulty.EASY:
			strategy_manager.set_strategy(SireAIStrategies.StrategyType.BALANCED)
			## Easy AI forgets ~30% of units each turn
			_forgotten_units = []
			
		Difficulty.NORMAL:
			strategy_manager.set_strategy(SireAIStrategies.StrategyType.BALANCED)
			
		Difficulty.HARD:
			## Hard AI starts with expansion, adapts dynamically
			strategy_manager.set_strategy(SireAIStrategies.StrategyType.EXPANSION)

## Process a complete turn. Returns array of all decisions made.
func process_turn() -> Array:
	_decisions_this_turn = []
	_current_turn += 1
	
	var state := _query_game_state()
	
	## Update strategy based on context (Normal and Hard)
	if difficulty >= Difficulty.NORMAL:
		strategy_manager.adapt(state)
		decision_engine.set_weights(strategy_manager.get_weights())
	
	decision_engine.context = state
	
	## Process each phase
	for phase in [Phase.TECHNOLOGY, Phase.MOVEMENT, Phase.CONSTRUCTION]:
		_current_phase = phase
		var phase_decisions := process_phase(phase)
		_decisions_this_turn.append_array(phase_decisions)
		phase_completed.emit(phase)
	
	## Easy: randomly forget some units for next turn
	if difficulty == Difficulty.EASY:
		_randomly_forget_units()
	
	## Hard: update tracking
	if difficulty == Difficulty.HARD:
		_update_tracking()
	
	turn_completed.emit(_current_turn)
	return _decisions_this_turn

## Process a single phase. Returns decisions for that phase.
func process_phase(phase: int) -> Array:
	match phase:
		Phase.TECHNOLOGY:
			return _process_technology_phase()
		Phase.MOVEMENT:
			return _process_movement_phase()
		Phase.COMBAT:
			return []  ## Combat is automatic resolution
		Phase.CONSTRUCTION:
			return _process_construction_phase()
		_:
			return []

## -- TECHNOLOGY PHASE --

func _process_technology_phase() -> Array:
	if get_game_state.is_null():
		return []
	
	var state: Dictionary = get_game_state.call()
	var available_techs: Array = state.get("available_techs", [])
	var stars: int = state.get("stars", 0)
	
	if available_techs.is_empty():
		return []
	
	match difficulty:
		Difficulty.EASY:
			return _pick_random_tech(available_techs, stars)
		Difficulty.NORMAL, Difficulty.HARD:
			return _score_and_pick_tech(available_techs, stars)
	
	return []

func _pick_random_tech(available_techs: Array, stars: int) -> Array:
	var affordable := available_techs.filter(func(t): return t.get("cost", 99) <= stars)
	if affordable.is_empty():
		return []
	
	var tech = affordable[_rng.randi() % affordable.size()]
	var action := SireAIDecision.make_action(SireAIDecision.ActionType.TECH_RESEARCH, {
		"tech": tech.get("name", ""),
		"cost": tech.get("cost", 0),
	})
	return [action]

func _score_and_pick_tech(available_techs: Array, stars: int) -> Array:
	var actions: Array = []
	for tech in available_techs:
		if tech.get("cost", 99) > stars:
			continue
		actions.append(SireAIDecision.make_action(SireAIDecision.ActionType.TECH_RESEARCH, {
			"tech": tech.get("name", ""),
			"cost": tech.get("cost", 0),
			"has_coastal_city": _has_coastal_city(),
		}))
	
	if actions.is_empty():
		return []
	
	var best := decision_engine.choose_best_action(actions)
	return [best] if not best.is_empty() else []

## -- MOVEMENT PHASE --

func _process_movement_phase() -> Array:
	if get_units.is_null():
		return []
	
	var units: Array = get_units.call()
	var decisions: Array = []
	
	## Easy: forget some units
	if difficulty == Difficulty.EASY:
		units = _filter_forgotten_units(units)
	
	for unit in units:
		var unit_decisions := _process_unit(unit)
		decisions.append_array(unit_decisions)
	
	return decisions

func _process_unit(unit: Dictionary) -> Array:
	var unit_id: String = unit.get("id", "")
	var unit_type: String = unit.get("type", "")
	var coord: Vector2i = unit.get("coord", Vector2i.ZERO)
	var movement: float = unit.get("movement", 1)
	var hp: float = unit.get("hp", 10)
	var attack: float = unit.get("attack", 1)
	
	## Generate possible actions for this unit
	var actions: Array = []
	
	## 1. Explore (always an option)
	actions.append(_make_explore_action(unit))
	
	## 2. Found city (if explorer and valid location)
	if unit_type == "Explorador" and _can_found_city_here(coord):
		actions.append(_make_found_city_action(unit))
	
	## 3. Attack nearby enemies
	var nearby_enemies := _get_nearby_enemies(coord, movement + 2)
	for enemy in nearby_enemies:
		actions.append(_make_attack_action(unit, enemy))
	
	## 4. Move toward objectives
	var move_actions := _generate_move_actions(unit)
	actions.append_array(move_actions)
	
	## 5. Defensive reposition
	if hp <= unit.get("max_hp", 10) * 0.4:
		actions.append(_make_retreat_action(unit))
	
	if actions.is_empty():
		return []
	
	match difficulty:
		Difficulty.EASY:
			return _pick_random_action(actions)
		Difficulty.NORMAL:
			return _pick_best_action(actions)
		Difficulty.HARD:
			return _pick_optimal_action(actions, unit)
	
	return []

func _make_explore_action(unit: Dictionary) -> Dictionary:
	var coord: Vector2i = unit.get("coord", Vector2i.ZERO)
	var unexplored_direction := _find_unexplored_direction(coord)
	
	return SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_EXPLORE, {
		"unit_id": unit.get("id", ""),
		"unit_type": unit.get("type", ""),
		"new_tiles_revealed": unexplored_direction.get("new_tiles", 1),
		"distance_from_base": unexplored_direction.get("dist", 0.0),
		"target_tile": unexplored_direction.get("tile", {}),
	})

func _make_found_city_action(unit: Dictionary) -> Dictionary:
	var coord: Vector2i = unit.get("coord", Vector2i.ZERO)
	var tile := _get_tile_info(coord)
	
	return SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_FOUND_CITY, {
		"unit_id": unit.get("id", ""),
		"target_tile": tile,
		"nearest_city_dist": _distance_to_nearest_city(coord),
	})

func _make_attack_action(unit: Dictionary, enemy: Dictionary) -> Dictionary:
	var unit_atk: float = unit.get("attack", 1)
	var unit_hp: float = unit.get("hp", 10)
	var enemy_def: float = enemy.get("defense", 1)
	var enemy_hp: float = enemy.get("hp", 10)
	var enemy_coord: Vector2i = enemy.get("coord", Vector2i.ZERO)
	
	var terrain := _get_tile_info(enemy_coord)
	var estimate := SireAIDecision.estimate_combat(
		{"attack": unit_atk, "hp": unit_hp},
		{"defense": enemy_def, "hp": enemy_hp},
		terrain
	)
	
	return SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_ATTACK, {
		"unit_id": unit.get("id", ""),
		"target_id": enemy.get("id", ""),
		"target_coord": enemy_coord,
		"advantage_ratio": estimate.ratio,
		"expected_damage": estimate.expected_damage,
		"risk": estimate.risk,
		"target_is_city": enemy.get("is_city", false),
		"is_flank": _is_flanking_position(unit.get("coord", Vector2i.ZERO), enemy_coord),
		"unit_hp": unit_hp,
	})

func _generate_move_actions(unit: Dictionary) -> Array:
	var actions: Array = []
	var coord: Vector2i = unit.get("coord", Vector2i.ZERO)
	var movement: float = unit.get("movement", 1)
	
	## Get reachable tiles
	var is_passable := Callable()
	if not get_map_tile.is_null():
		is_passable = func(c):
			var t = get_map_tile.call(c)
			return t.get("passable", true) and not t.get("occupied_by_enemy", false)
	
	var get_terrain := Callable()
	if not get_map_tile.is_null():
		get_terrain = func(c):
			var t = get_map_tile.call(c)
			return t.get("terrain", "pradera")
	else:
		get_terrain = func(c): return "pradera"
	
	var reachable := pathfinding.get_reachable(coord, movement, get_terrain, is_passable)
	
	## Filter interesting destinations
	for tile_coord in reachable:
		if tile_coord == coord:
			continue
		
		var tile := _get_tile_info(tile_coord)
		var purpose := ""
		
		## Determine purpose based on destination
		if tile.get("has_enemy", false):
			purpose = "approach_enemy"
		elif tile.get("has_resource", false):
			purpose = "explore"
		elif tile.get("is_friendly_territory", false) and tile.get("near_city", false):
			purpose = "reinforce"
		elif tile.get("unexplored", false):
			purpose = "explore"
		else:
			purpose = "explore"
		
		## Hard: check for flanking positions
		if difficulty == Difficulty.HARD:
			var nearby_enemies := _get_nearby_enemies(tile_coord, 3)
			for enemy in nearby_enemies:
				if _is_flanking_position(tile_coord, enemy.get("coord", Vector2i.ZERO)):
					purpose = "flank"
					break
		
		actions.append(SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_MOVE, {
			"unit_id": unit.get("id", ""),
			"target_tile": tile,
			"target_coord": tile_coord,
			"purpose": purpose,
			"advantage_ratio": _estimate_local_advantage(tile_coord),
		}))
	
	return actions

func _make_retreat_action(unit: Dictionary) -> Dictionary:
	var coord: Vector2i = unit.get("coord", Vector2i.ZERO)
	var nearest_city: Dictionary = _find_nearest_friendly_city(coord)
	var retreat_tile: Vector2i = nearest_city.get("coord", coord) if not nearest_city.is_empty() else coord
	
	return SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_MOVE, {
		"unit_id": unit.get("id", ""),
		"target_coord": retreat_tile,
		"target_tile": _get_tile_info(retreat_tile),
		"purpose": "retreat",
	})

## -- CONSTRUCTION PHASE --

func _process_construction_phase() -> Array:
	if get_cities.is_null():
		return []
	
	var cities: Array = get_cities.call()
	var decisions: Array = []
	
	for city in cities:
		var city_decisions := _process_city(city)
		decisions.append_array(city_decisions)
	
	return decisions

func _process_city(city: Dictionary) -> Array:
	var city_id: String = city.get("id", "")
	var city_level: int = city.get("level", 1)
	var city_pop: int = city.get("population", 1)
	var stars: int = _get_stars()
	
	var actions: Array = []
	
	## 1. Build units
	var available_units := _get_available_unit_types()
	for unit_type in available_units:
		var cost := _get_unit_cost(unit_type)
		actions.append(SireAIDecision.make_action(SireAIDecision.ActionType.CITY_BUILD_UNIT, {
			"city_id": city_id,
			"unit_type": unit_type,
			"cost": cost,
			"city_level": city_level,
		}))
	
	## 2. Build buildings
	var available_buildings := _get_available_buildings(city)
	for building in available_buildings:
		var cost := _get_building_cost(building)
		actions.append(SireAIDecision.make_action(SireAIDecision.ActionType.CITY_BUILD_BUILDING, {
			"city_id": city_id,
			"building": building,
			"cost": cost,
			"city_level": city_level,
			"city_is_coastal": city.get("is_coastal", false),
			"city_has_port": city.get("has_port", false),
		}))
	
	## 3. Grow city (if affordable)
	var grow_cost := _get_growth_cost(city_level)
	actions.append(SireAIDecision.make_action(SireAIDecision.ActionType.CITY_GROW, {
		"city_id": city_id,
		"city_level": city_level,
		"city_pop": city_pop,
		"cost": grow_cost,
	}))
	
	if actions.is_empty():
		return []
	
	match difficulty:
		Difficulty.EASY:
			return _pick_random_action(actions)
		Difficulty.NORMAL:
			return _pick_best_action(actions)
		Difficulty.HARD:
			return _pick_optimal_action(actions, city)
	
	return []

## -- DECISION SELECTION PER DIFFICULTY --

func _pick_random_action(actions: Array) -> Array:
	if actions.is_empty():
		return []
	var idx := _rng.randi() % actions.size()
	return [actions[idx]]

func _pick_best_action(actions: Array) -> Array:
	var best := decision_engine.choose_best_action(actions)
	return [best] if not best.is_empty() else []

func _pick_optimal_action(actions: Array, context_source: Dictionary) -> Array:
	## Hard: consider multi-turn planning and economy
	var ranked := decision_engine.rank_actions(actions)
	
	## Hard AI plans ahead: if top action is expensive, check if we can afford
	## next turn's planned actions too
	if not ranked.is_empty():
		var top: Dictionary = ranked[0]
		var cost: int = top.action.get("cost", 0)
		var stars := _get_stars()
		
		## If we have planned production, factor it in
		var planned_spending := 0
		for plan in _city_production_queue.values():
			planned_spending += plan.get("cost", 0)
		
		## If we can't afford everything, prefer cheaper but still good options
		if cost + planned_spending > stars and ranked.size() > 1:
			## Find the best action we can afford without compromising next turn
			for entry in ranked:
				var entry_cost: int = entry.action.get("cost", 0)
				if entry_cost + planned_spending <= stars and entry.score >= top.score * 0.7:
					return [entry.action]
		
		return [top.action]
	
	return []

## -- EASY DIFFICULTY: FORGETTING UNITS --

func _randomly_forget_units() -> void:
	if get_units.is_null():
		return
	var units: Array = get_units.call()
	_forgotten_units = []
	for unit in units:
		if _rng.randf() < 0.3:  ## 30% chance to forget each unit
			_forgotten_units.append(unit.get("id", ""))

func _filter_forgotten_units(units: Array) -> Array:
	return units.filter(func(u): return not (u.get("id", "") in _forgotten_units))

## -- HARD DIFFICULTY: TRACKING --

func _update_tracking() -> void:
	if not get_units.is_null():
		var units: Array = get_units.call()
		for unit in units:
			_unit_last_positions[unit.get("id", "")] = unit.get("coord", Vector2i.ZERO)
	
	## Clear old attack plans that are no longer relevant
	_attack_plans = _attack_plans.filter(func(plan):
		var target_alive := false
		if not get_enemy_units.is_null():
			for enemy in get_enemy_units.call():
				if enemy.get("id", "") == plan.get("target_id", ""):
					target_alive = true
					break
		return target_alive
	)

## -- HELPER METHODS --

func _query_game_state() -> Dictionary:
	if not get_game_state.is_null():
		return get_game_state.call()
	
	## Fallback: assemble from individual queries
	var state := {
		"turn": _current_turn,
		"stars": 0,
		"owned_cities": 0,
		"owned_units": 0,
		"enemy_cities": 0,
		"enemy_units": 0,
		"known_techs": [],
		"available_techs": [],
		"phase": _phase_name(_current_phase),
	}
	
	if not get_cities.is_null():
		var cities = get_cities.call()
		state.owned_cities = cities.size()
	
	if not get_units.is_null():
		var units = get_units.call()
		state.owned_units = units.size()
	
	if not get_enemy_cities.is_null():
		var e_cities = get_enemy_cities.call()
		state.enemy_cities = e_cities.size()
		state.enemy_cities_nearby = e_cities.filter(func(c): return c.get("distance", 99) <= 5).size()
	
	if not get_enemy_units.is_null():
		var e_units = get_enemy_units.call()
		state.enemy_units = e_units.size()
		state.enemy_units_nearby = e_units.filter(func(u): return u.get("distance", 99) <= 5).size()
		state.enemy_at_border = state.enemy_units_nearby > 0
		state.weak_enemies_spotted = e_units.filter(func(u): return u.get("hp", 10) <= 3).size()
		state.undefended_enemy_cities = e_units.filter(func(u): return u.get("is_city", false) and u.get("defenders", 0) == 0).size()
	
	return state

func _get_tile_info(coord: Vector2i) -> Dictionary:
	if not get_map_tile.is_null():
		return get_map_tile.call(coord)
	return {"terrain": "pradera", "passable": true}

func _get_nearby_enemies(coord: Vector2i, range_dist: float) -> Array:
	if get_enemy_units.is_null():
		return []
	var enemies: Array = get_enemy_units.call()
	var nearby: Array = []
	for enemy in enemies:
		var e_coord: Vector2i = enemy.get("coord", Vector2i.ZERO)
		var dist := pathfinding.wrapped_distance(coord, e_coord)
		if dist <= range_dist:
			enemy["distance"] = dist
			nearby.append(enemy)
	return nearby

func _can_found_city_here(coord: Vector2i) -> bool:
	var tile := _get_tile_info(coord)
	if tile.get("terrain", "") == "agua":
		return false
	if tile.get("has_city", false):
		return false
	return true

func _distance_to_nearest_city(coord: Vector2i) -> float:
	if get_cities.is_null():
		return 99.0
	var cities: Array = get_cities.call()
	var min_dist := 999.0
	for city in cities:
		var c_coord: Vector2i = city.get("coord", Vector2i.ZERO)
		var dist := pathfinding.wrapped_distance(coord, c_coord)
		if dist < min_dist:
			min_dist = dist
	return min_dist

func _find_nearest_friendly_city(coord: Vector2i) -> Dictionary:
	if get_cities.is_null():
		return {}
	var cities: Array = get_cities.call()
	var nearest: Dictionary = {}
	var min_dist := 999.0
	for city in cities:
		var c_coord: Vector2i = city.get("coord", Vector2i.ZERO)
		var dist := pathfinding.wrapped_distance(coord, c_coord)
		if dist < min_dist:
			min_dist = dist
			nearest = city
	return nearest

func _find_unexplored_direction(coord: Vector2i) -> Dictionary:
	## Simple heuristic: prefer directions with fewer known tiles
	var directions := [
		Vector2i(+1, 0), Vector2i(-1, 0), Vector2i(0, +1),
		Vector2i(0, -1), Vector2i(+1, -1), Vector2i(-1, +1)
	]
	
	var best_dir: Vector2i = directions[0]
	var best_score := -1
	
	for dir in directions:
		var check_coord := pathfinding.wrap_coordinate(coord + dir * 3)
		var tile := _get_tile_info(check_coord)
		var score := 0
		if tile.get("unexplored", false):
			score += 10
		if tile.get("has_resource", false):
			score += 5
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return {
		"new_tiles": max(best_score / 10, 1),
		"dist": 3.0,
		"tile": _get_tile_info(pathfinding.wrap_coordinate(coord + best_dir)),
	}

func _is_flanking_position(attacker: Vector2i, target: Vector2i) -> bool:
	## A flank is when the attacker is not in the direct line from target to
	## the target's nearest friendly city or main force
	## Simplified: any position that is not the closest hex to target is a potential flank
	var dist := pathfinding.axial_distance(attacker, target)
	return dist >= 2 and dist <= 3

func _estimate_local_advantage(coord: Vector2i) -> float:
	var nearby_friendly := 0
	var nearby_enemy := 0
	
	if not get_units.is_null():
		for unit in get_units.call():
			var u_coord: Vector2i = unit.get("coord", Vector2i.ZERO)
			if pathfinding.wrapped_distance(coord, u_coord) <= 2:
				nearby_friendly += 1
	
	if not get_enemy_units.is_null():
		for enemy in get_enemy_units.call():
			var e_coord: Vector2i = enemy.get("coord", Vector2i.ZERO)
			if pathfinding.wrapped_distance(coord, e_coord) <= 2:
				nearby_enemy += 1
	
	if nearby_enemy == 0:
		return 999.0  ## No enemies, full advantage
	return float(nearby_friendly) / nearby_enemy

func _has_coastal_city() -> bool:
	if get_cities.is_null():
		return false
	var cities: Array = get_cities.call()
	for city in cities:
		if city.get("is_coastal", false):
			return true
	return false

func _get_stars() -> int:
	if not get_game_state.is_null():
		return get_game_state.call().get("stars", 0)
	return 0

func _get_available_unit_types() -> Array:
	## Would query technology tree in real implementation
	## Return all basic units + unlocked tech units
	var base := ["Explorador", "Guerrero", "Arquero"]
	if not get_game_state.is_null():
		var techs: Array = get_game_state.call().get("known_techs", [])
		if "Equitación" in techs:
			base.append("Jinete")
		if "Herrería" in techs:
			base.append("Caballero")
		if "Navegación" in techs:
			base.append("Barco")
		if "Construcción" in techs:
			base.append("Buque de Guerra")
		if "Matemáticas" in techs:
			base.append("Catapulta")
		if "Herrería" in techs and "Construcción" in techs:
			base.append("Gigante")
	return base

func _get_unit_cost(unit_type: String) -> int:
	var costs := {
		"Explorador": 2,
		"Guerrero": 3,
		"Arquero": 3,
		"Jinete": 5,
		"Caballero": 8,
		"Barco": 5,
		"Buque de Guerra": 8,
		"Catapulta": 8,
		"Gigante": 20,
	}
	return costs.get(unit_type, 5)

func _get_available_buildings(city: Dictionary) -> Array:
	var available := ["Mina", "Aserradero"]
	var techs: Array = []
	if not get_game_state.is_null():
		techs = get_game_state.call().get("known_techs", [])
	
	if "Navegación" in techs and city.get("is_coastal", false):
		available.append("Puerto")
	if "Herrería" in techs:
		available.append("Forja")
	if "Construcción" in techs:
		available.append("Muralla")
		available.append("Templo")
	if "Organización" in techs:
		available.append("Templo")
	if "Agricultura" in techs:
		available.append("Parque")
	
	return available

func _get_building_cost(building: String) -> int:
	var costs := {
		"Puerto": 5,
		"Mina": 4,
		"Aserradero": 3,
		"Forja": 5,
		"Muralla": 6,
		"Templo": 4,
		"Parque": 3,
	}
	return costs.get(building, 4)

func _get_growth_cost(city_level: int) -> int:
	return city_level * 3 + 2

func _phase_name(phase: int) -> String:
	match phase:
		Phase.INCOME: return "income"
		Phase.TECHNOLOGY: return "technology"
		Phase.MOVEMENT: return "movement"
		Phase.COMBAT: return "combat"
		Phase.CONSTRUCTION: return "construction"
	return "unknown"

## Execute the current turn's decisions against the game.
func execute_turn() -> void:
	if execute_action.is_null():
		return
	for decision in _decisions_this_turn:
		execute_action.call(decision)
		decision_made.emit(decision)

## Get the last turn's decisions without reprocessing.
func get_last_decisions() -> Array:
	return _decisions_this_turn.duplicate()

## Serialization for save games.
func serialize() -> Dictionary:
	return {
		"difficulty": difficulty,
		"tribe": tribe_name,
		"turn": _current_turn,
		"strategy": strategy_manager.serialize(),
		"forgotten_units": _forgotten_units.duplicate(),
		"unit_positions": _unit_last_positions.duplicate(),
		"production_queue": _city_production_queue.duplicate(),
		"attack_plans": _attack_plans.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	difficulty = data.get("difficulty", Difficulty.NORMAL)
	tribe_name = data.get("tribe", "")
	_current_turn = data.get("turn", 0)
	strategy_manager.deserialize(data.get("strategy", {}))
	_forgotten_units = data.get("forgotten_units", [])
	_unit_last_positions = data.get("unit_positions", {})
	_city_production_queue = data.get("production_queue", {})
	_attack_plans = data.get("attack_plans", [])
	_setup_for_difficulty()
