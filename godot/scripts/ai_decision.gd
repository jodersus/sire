class_name SireAIDecision
extends RefCounted
## Decision scoring system for Sire AI.
## Evaluates possible actions and scores them based on strategic weights.
## No UI dependencies. Fully testable.

## Action types
enum ActionType {
	UNIT_MOVE,
	UNIT_ATTACK,
	UNIT_FOUND_CITY,
	UNIT_EXPLORE,
	CITY_BUILD_UNIT,
	CITY_BUILD_BUILDING,
	CITY_GROW,
	TECH_RESEARCH,
	DO_NOTHING,
}

## Score weights (will be overridden by strategy)
var weights: Dictionary = {
	"expand": 1.0,
	"military": 1.0,
	"economy": 1.0,
	"defense": 1.0,
	"exploration": 1.0,
	"growth": 1.0,
	"tech": 1.0,
}

## Combat evaluation constants
const ADVANTAGE_RATIO_FOR_ATTACK := 2.0  ## Normal difficulty: attack when 2:1 advantage

## Technology priorities by phase of game
const EARLY_TECHS := ["Organización", "Caza", "Pesca", "Agricultura"]
const MID_TECHS := ["Equitación", "Navegación", "Herrería", "Velas", "Escudos", "Arquería"]
const LATE_TECHS := ["Construcción", "Matemáticas", "Catapultas", "Caminos", "Comercio"]

## Unit priorities by strategy
const EXPANSION_UNITS := ["Explorador", "Barco"]
const MILITARY_UNITS := ["Guerrero", "Arquero", "Jinete", "Caballero", "Buque de Guerra", "Catapulta", "Gigante"]
const DEFENSIVE_UNITS := ["Guerrero", "Arquero", "Caballero"]
const ECONOMIC_UNITS := ["Explorador", "Barco"]

## Building priorities
const EXPANSION_BUILDINGS := ["Templo", "Parque"]
const MILITARY_BUILDINGS := ["Forja", "Muralla"]
const DEFENSIVE_BUILDINGS := ["Muralla", "Puerto", "Mina"]
const ECONOMIC_BUILDINGS := ["Aserradero", "Mina", "Puerto", "Forja"]

## Current game state context (set before evaluation)
var context: Dictionary = {
	"turn": 0,
	"stars": 0,
	"owned_cities": 0,
	"owned_units": 0,
	"enemy_cities": 0,
	"enemy_units": 0,
	"known_techs": [],
	"available_techs": [],
	"phase": "",
}

func _init(strategy_weights: Dictionary = {}):
	for key in strategy_weights:
		if weights.has(key):
			weights[key] = strategy_weights[key]

## Main entry: score a single action.
## Returns float score (higher = better)
func score_action(action: Dictionary) -> float:
	match action.get("type", ActionType.DO_NOTHING):
		ActionType.UNIT_MOVE:
			return _score_unit_move(action)
		ActionType.UNIT_ATTACK:
			return _score_unit_attack(action)
		ActionType.UNIT_FOUND_CITY:
			return _score_unit_found_city(action)
		ActionType.UNIT_EXPLORE:
			return _score_unit_explore(action)
		ActionType.CITY_BUILD_UNIT:
			return _score_city_build_unit(action)
		ActionType.CITY_BUILD_BUILDING:
			return _score_city_build_building(action)
		ActionType.CITY_GROW:
			return _score_city_grow(action)
		ActionType.TECH_RESEARCH:
			return _score_tech_research(action)
		ActionType.DO_NOTHING:
			return 0.0
		_:
			return 0.0

## Evaluate a list of actions and return the best one.
## actions: Array of Dictionaries with at least {"type": ActionType, ...}
## Returns the highest-scoring action Dictionary, or null if empty.
func choose_best_action(actions: Array) -> Dictionary:
	if actions.is_empty():
		return {}

	var best_action: Dictionary = actions[0]
	var best_score := score_action(actions[0])

	for i in range(1, actions.size()):
		var score := score_action(actions[i])
		if score > best_score:
			best_score = score
			best_action = actions[i]

	return best_action

## Evaluate all actions and return them sorted by score (descending).
func rank_actions(actions: Array) -> Array:
	var scored: Array = []
	for action in actions:
		scored.append({"action": action, "score": score_action(action)})

	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	return scored

## -- UNIT ACTION SCORERS --

func _score_unit_move(action: Dictionary) -> float:
	var score: float = 10.0  ## Base: moving is better than nothing
	var target: Dictionary = action.get("target_tile", {})
	var purpose: String = action.get("purpose", "")

	match purpose:
		"approach_enemy":
			score += 20.0 * weights.military
			## Bonus if we have advantage
			if action.get("advantage_ratio", 1.0) >= ADVANTAGE_RATIO_FOR_ATTACK:
				score += 30.0 * weights.military
		"retreat":
			score += 15.0 * weights.defense
		"approach_city":
			score += 25.0 * weights.expand
		"reinforce":
			score += 20.0 * weights.defense
		"explore":
			score += 15.0 * weights.exploration
		"flank":
			score += 35.0 * weights.military
		_:
			score += 5.0

	## Penalty for moving into dangerous terrain
	var terrain: String = target.get("terrain", "pradera")
	if terrain == "montana":
		score -= 3.0  ## Slower retreat/approach
	elif terrain == "bosque":
		score -= 1.0

	## Bonus for moving toward known resources
	if target.get("has_resource", false):
		score += 10.0 * weights.economy

	## Early game: exploration is more valuable
	if context.turn <= 10:
		if purpose == "explore":
			score += 20.0

	return score

func _score_unit_attack(action: Dictionary) -> float:
	var score := 5.0  ## Base attack willingness
	var advantage: float = action.get("advantage_ratio", 1.0)
	var target_is_city: bool = action.get("target_is_city", false)
	var expected_damage: float = action.get("expected_damage", 0.0)
	var risk: float = action.get("risk", 0.5)

	## Core combat calculus
	if advantage >= ADVANTAGE_RATIO_FOR_ATTACK:
		score += 50.0 * weights.military
	elif advantage >= 1.5:
		score += 30.0 * weights.military
	elif advantage >= 1.0:
		score += 10.0 * weights.military
	else:
		score -= 20.0  ## Disadvantageous attack

	## City capture is highly valuable
	if target_is_city:
		score += 40.0 * weights.expand
		score += 20.0 * weights.military

	## Damage expectation
	score += expected_damage * 5.0 * weights.military

	## Risk aversion
	score -= risk * 25.0

	## Flanking bonus (higher if attacking from behind/side)
	if action.get("is_flank", false):
		score += 25.0 * weights.military

	## Don't suicide weak units
	var unit_hp: float = action.get("unit_hp", 10.0)
	if unit_hp <= 3.0 and risk > 0.3:
		score -= 20.0

	return score

func _score_unit_found_city(action: Dictionary) -> float:
	var score: float = 40.0 * weights.expand

	## Penalty if we already have many cities (diminishing returns)
	var city_count: int = context.get("owned_cities", 0)
	if city_count >= 8:
		score -= 20.0
	elif city_count >= 5:
		score -= 10.0

	## Bonus for good city location
	var tile: Dictionary = action.get("target_tile", {})
	if tile.get("has_resource", false):
		score += 15.0 * weights.economy
	if tile.get("terrain", "pradera") in ["pradera", "desierto"]:
		score += 5.0  ## Good terrain for growth

	## Early game priority
	if context.turn <= 15:
		score += 20.0

	## Penalty for founding too close to existing cities
	var nearest_city_dist: float = action.get("nearest_city_dist", 0.0)
	if nearest_city_dist < 2.0:
		score -= 15.0

	return score

func _score_unit_explore(action: Dictionary) -> float:
	var score: float = 15.0 * weights.exploration

	## More valuable early game and when few cities
	var city_count: int = context.get("owned_cities", 0)
	if context.turn <= 10:
		score += 25.0
	if city_count < 3:
		score += 15.0

	## Bonus for revealing fog of war
	var new_tiles: int = action.get("new_tiles_revealed", 0)
	score += new_tiles * 3.0

	## Slight penalty for exploring far from territory
	var distance_from_base: float = action.get("distance_from_base", 0.0)
	if distance_from_base > 10.0:
		score -= 5.0

	return score

## -- CITY ACTION SCORERS --

func _score_city_build_unit(action: Dictionary) -> float:
	var unit_type: String = action.get("unit_type", "")
	var cost: int = action.get("cost", 0)
	var stars: int = context.get("stars", 0)
	var score := 10.0

	## Can we afford it?
	if cost > stars:
		return -100.0  ## Cannot build

	## Prioritize by strategy and unit type
	if unit_type in EXPANSION_UNITS:
		score += 20.0 * weights.expand
		if context.get("owned_cities", 0) < 4:
			score += 15.0
	elif unit_type in MILITARY_UNITS:
		score += 25.0 * weights.military
		## More military if we detect enemies
		if context.get("enemy_units", 0) > context.get("owned_units", 0):
			score += 15.0
	elif unit_type in DEFENSIVE_UNITS:
		score += 20.0 * weights.defense
	elif unit_type in ECONOMIC_UNITS:
		score += 15.0 * weights.economy

	## City level affects what we should build
	var city_level: int = action.get("city_level", 1)
	if city_level >= 3 and unit_type in ["Caballero", "Catapulta", "Gigante"]:
		score += 10.0  ## High-level cities can afford expensive units

	## Affordability factor (prefer cheaper when poor)
	if stars < cost * 2:
		score -= (cost - stars * 0.5) * 2.0

	return score

func _score_city_build_building(action: Dictionary) -> float:
	var building: String = action.get("building", "")
	var cost: int = action.get("cost", 0)
	var stars: int = context.get("stars", 0)
	var score := 15.0

	if cost > stars:
		return -100.0

	## Building type priorities
	if building in EXPANSION_BUILDINGS:
		score += 15.0 * weights.expand + 10.0 * weights.growth
	elif building in MILITARY_BUILDINGS:
		score += 20.0 * weights.military
	elif building in DEFENSIVE_BUILDINGS:
		score += 20.0 * weights.defense
	elif building in ECONOMIC_BUILDINGS:
		score += 20.0 * weights.economy

	## City-specific needs
	var city_has_port: bool = action.get("city_has_port", false)
	var city_is_coastal: bool = action.get("city_is_coastal", false)
	if building == "Puerto" and city_is_coastal and not city_has_port:
		score += 15.0 * weights.economy

	## Don't overbuild in small cities
	var city_level: int = action.get("city_level", 1)
	if city_level == 1 and cost >= 5:
		score -= 10.0

	return score

func _score_city_grow(action: Dictionary) -> float:
	var score: float = 20.0 * weights.growth
	var city_level: int = action.get("city_level", 1)
	var city_pop: int = action.get("city_pop", 1)

	## Growing is good, but expensive at high levels
	if city_level >= 4:
		score -= 10.0

	## More valuable if city is productive
	if city_pop >= 3:
		score += 10.0

	## Early growth is very valuable
	if context.turn <= 20:
		score += 15.0

	return score

## -- TECHNOLOGY SCORER --

func _score_tech_research(action: Dictionary) -> float:
	var tech: String = action.get("tech", "")
	var cost: int = action.get("cost", 0)
	var stars: int = context.get("stars", 0)
	var score: float = 10.0 * weights.tech

	if cost > stars:
		return -100.0

	## Phase of game determines tech priority
	if tech in EARLY_TECHS:
		if context.turn <= 15:
			score += 25.0
		else:
			score += 5.0  ## Still useful later
	elif tech in MID_TECHS:
		if context.turn <= 30 and context.turn > 10:
			score += 20.0
		else:
			score += 10.0
	elif tech in LATE_TECHS:
		if context.turn > 25:
			score += 20.0
		else:
			score -= 5.0  ## Too early

	## Military techs when we need units
	if tech in ["Herrería", "Arquería", "Escudos", "Matemáticas", "Catapultas"]:
		if context.get("enemy_units", 0) > 0 or weights.military > 1.2:
			score += 15.0 * weights.military

	## Naval techs when we have coastal cities
	if tech in ["Pesca", "Navegación", "Velas"]:
		if action.get("has_coastal_city", false):
			score += 15.0 * weights.economy

	## Expansion techs
	if tech in ["Organización", "Agricultura", "Construcción", "Caminos"]:
		score += 10.0 * weights.expand

	## Cost efficiency
	score -= cost * 0.5

	return score

## -- UTILITY --

## Batch score multiple actions of the same type.
func score_actions(actions: Array) -> Array:
	return rank_actions(actions)

## Create a simple action dictionary helper.
static func make_action(type: int, params: Dictionary = {}) -> Dictionary:
	var action := {"type": type}
	for key in params:
		action[key] = params[key]
	return action

## Update weights at runtime.
func set_weights(new_weights: Dictionary) -> void:
	for key in new_weights:
		if weights.has(key):
			weights[key] = new_weights[key]

## Get current weights.
func get_weights() -> Dictionary:
	return weights.duplicate()

## Estimate combat outcome. Returns Dictionary with predicted result.
static func estimate_combat(attacker: Dictionary, defender: Dictionary, terrain_bonus: Dictionary = {}) -> Dictionary:
	var atk_force: float = attacker.get("attack", 1) + attacker.get("hp", 10) * 0.1
	var def_force: float = defender.get("defense", 1) + defender.get("hp", 10) * 0.1

	## Apply terrain bonus to defender
	var terrain: String = terrain_bonus.get("terrain", "pradera")
	match terrain:
		"montana":
			def_force += 2.0
		"bosque":
			def_force += 1.0
		"pradera", "desierto":
			pass

	var ratio: float = atk_force / max(def_force, 0.1)
	var win_chance := clampf(ratio / (ratio + 1.0), 0.05, 0.95)
	var expected_damage := atk_force * win_chance
	var risk := 1.0 - win_chance

	return {
		"ratio": ratio,
		"win_chance": win_chance,
		"expected_damage": expected_damage,
		"risk": risk,
		"recommend_attack": ratio >= ADVANTAGE_RATIO_FOR_ATTACK,
	}
