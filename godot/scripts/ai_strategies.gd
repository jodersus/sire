class_name SireAIStrategies
extends RefCounted
## Strategy presets and dynamic strategy blending for Sire AI.
## Defines weight configurations for different AI behaviors.
## No UI dependencies. Fully testable.

enum StrategyType {
	EXPANSION,
	MILITARY,
	ECONOMIC,
	DEFENSIVE,
	BALANCED,
}

## Base weights for each pure strategy.
## Keys: expand, military, economy, defense, exploration, growth, tech
const STRATEGY_PRESETS: Dictionary = {
	StrategyType.EXPANSION: {
		"expand": 2.5,
		"military": 0.8,
		"economy": 1.2,
		"defense": 0.6,
		"exploration": 2.0,
		"growth": 1.5,
		"tech": 1.0,
	},
	StrategyType.MILITARY: {
		"expand": 1.0,
		"military": 2.5,
		"economy": 0.8,
		"defense": 1.0,
		"exploration": 0.6,
		"growth": 0.5,
		"tech": 1.2,
	},
	StrategyType.ECONOMIC: {
		"expand": 1.2,
		"military": 0.5,
		"economy": 2.5,
		"defense": 0.8,
		"exploration": 1.0,
		"growth": 1.5,
		"tech": 2.0,
	},
	StrategyType.DEFENSIVE: {
		"expand": 0.6,
		"military": 1.0,
		"economy": 1.0,
		"defense": 2.5,
		"exploration": 0.5,
		"growth": 1.2,
		"tech": 0.8,
	},
	StrategyType.BALANCED: {
		"expand": 1.0,
		"military": 1.0,
		"economy": 1.0,
		"defense": 1.0,
		"exploration": 1.0,
		"growth": 1.0,
		"tech": 1.0,
	},
}

## Human-readable names
const STRATEGY_NAMES: Dictionary = {
	StrategyType.EXPANSION: "expansion",
	StrategyType.MILITARY: "military",
	StrategyType.ECONOMIC: "economic",
	StrategyType.DEFENSIVE: "defensive",
	StrategyType.BALANCED: "balanced",
}

var _current_strategy: int = StrategyType.BALANCED
var _current_weights: Dictionary = STRATEGY_PRESETS[StrategyType.BALANCED].duplicate()

## Dynamic strategy state machine
var _game_phase: String = "early"  ## early, mid, late
var _threat_level: float = 0.0     ## 0-1, increases when enemies are near
var _opportunity_level: float = 0.0 ## 0-1, increases when weak enemies are spotted

func _init(strategy: int = StrategyType.BALANCED):
	set_strategy(strategy)

## Set a pure strategy preset.
func set_strategy(strategy_type: int) -> void:
	_current_strategy = strategy_type
	_current_weights = STRATEGY_PRESETS.get(strategy_type, STRATEGY_PRESETS[StrategyType.BALANCED]).duplicate()

## Get current strategy type.
func get_current_strategy() -> int:
	return _current_strategy

## Get current strategy name.
func get_current_name() -> String:
	return STRATEGY_NAMES.get(_current_strategy, "balanced")

## Get current weights.
func get_weights() -> Dictionary:
	return _current_weights.duplicate()

## Blend between two strategies with a given ratio (0.0 = first, 1.0 = second).
static func blend_weights(weights_a: Dictionary, weights_b: Dictionary, ratio: float) -> Dictionary:
	var result := {
		"expand": 1.0,
		"military": 1.0,
		"economy": 1.0,
		"defense": 1.0,
		"exploration": 1.0,
		"growth": 1.0,
		"tech": 1.0,
	}
	var t := clampf(ratio, 0.0, 1.0)
	for key in result:
		var a: float = weights_a.get(key, 1.0)
		var b: float = weights_b.get(key, 1.0)
		result[key] = a * (1.0 - t) + b * t
	return result

## Adapt weights based on game context.
## Call this before each turn's decision phase.
func adapt(context: Dictionary) -> void:
	_game_phase = _detect_game_phase(context)
	_threat_level = _calculate_threat(context)
	_opportunity_level = _calculate_opportunity(context)
	
	## Apply phase modifiers
	match _game_phase:
		"early":
			_current_weights.exploration += 0.5
			_current_weights.expand += 0.3
			_current_weights.growth += 0.3
		"mid":
			_current_weights.military += 0.2
			_current_weights.tech += 0.2
		"late":
			_current_weights.military += 0.4
			_current_weights.defense += 0.3
	
	## React to threats
	if _threat_level > 0.6:
		_current_weights.defense += _threat_level * 0.8
		_current_weights.military += _threat_level * 0.5
		_current_weights.expand -= _threat_level * 0.3
		_current_weights.exploration -= _threat_level * 0.3
	
	## React to opportunities
	if _opportunity_level > 0.5:
		_current_weights.military += _opportunity_level * 0.6
		_current_weights.expand += _opportunity_level * 0.4
	
	## Clamp weights to reasonable range
	for key in _current_weights:
		_current_weights[key] = clampf(_current_weights[key], 0.2, 4.0)

## Detect game phase based on turn and empire size.
func _detect_game_phase(context: Dictionary) -> String:
	var turn: int = context.get("turn", 0)
	var cities: int = context.get("owned_cities", 0)
	
	if turn <= 15 and cities <= 3:
		return "early"
	elif turn >= 40 or cities >= 8:
		return "late"
	else:
		return "mid"

## Calculate threat level (0-1) based on enemy proximity and strength.
func _calculate_threat(context: Dictionary) -> float:
	var threat := 0.0
	
	var enemy_units: int = context.get("enemy_units_nearby", 0)
	var enemy_cities: int = context.get("enemy_cities_nearby", 0)
	var own_units: int = context.get("owned_units", 1)
	var own_cities: int = context.get("owned_cities", 1)
	
	## Enemy unit ratio
	if own_units > 0:
		var ratio := float(enemy_units) / own_units
		threat += clampf(ratio * 0.5, 0.0, 0.5)
	
	## Enemy city pressure
	threat += clampf(enemy_cities * 0.1, 0.0, 0.3)
	
	## Border proximity
	if context.get("enemy_at_border", false):
		threat += 0.3
	
	return clampf(threat, 0.0, 1.0)

## Calculate opportunity level (0-1) based on weak enemies and unclaimed land.
func _calculate_opportunity(context: Dictionary) -> float:
	var opp := 0.0
	
	## Weak enemy units spotted
	var weak_enemies: int = context.get("weak_enemies_spotted", 0)
	opp += clampf(weak_enemies * 0.1, 0.0, 0.4)
	
	## Unclaimed city sites
	var city_sites: int = context.get("available_city_sites", 0)
	if city_sites > 0 and context.get("owned_cities", 0) < 8:
		opp += clampf(city_sites * 0.08, 0.0, 0.4)
	
	## Enemy cities undefended
	var undefended_enemy_cities: int = context.get("undefended_enemy_cities", 0)
	opp += clampf(undefended_enemy_cities * 0.15, 0.0, 0.4)
	
	return clampf(opp, 0.0, 1.0)

## Select the best strategy based purely on game context.
static func recommend_strategy(context: Dictionary) -> int:
	var cities: int = context.get("owned_cities", 0)
	var enemy_units: int = context.get("enemy_units", 0)
	var stars: int = context.get("stars", 0)
	var turn: int = context.get("turn", 0)
	
	## Very early: always expansion
	if cities < 3 and turn <= 15:
		return StrategyType.EXPANSION
	
	## Under attack: defensive
	if context.get("enemy_at_border", false) and enemy_units > context.get("owned_units", 0) * 0.8:
		return StrategyType.DEFENSIVE
	
	## Rich and safe: economic
	if stars >= 20 and enemy_units <= context.get("owned_units", 0) * 0.5:
		return StrategyType.ECONOMIC
	
	## Strong military advantage: military
	if context.get("owned_units", 0) >= enemy_units * 1.5 and cities >= 4:
		return StrategyType.MILITARY
	
	## Default: balanced
	return StrategyType.BALANCED

## Get a description of current strategic posture.
func get_posture_description() -> String:
	var parts: Array[String] = []
	parts.append("strategy:" + get_current_name())
	parts.append("phase:" + _game_phase)
	parts.append("threat:%.1f" % _threat_level)
	parts.append("opportunity:%.1f" % _opportunity_level)
	return " ".join(parts)

## Create a defensive override (temporary boost to defense weights).
func emergency_defensive() -> void:
	_current_weights.defense += 2.0
	_current_weights.military += 1.0
	_current_weights.expand -= 0.5
	_current_weights.exploration -= 0.5
	for key in _current_weights:
		_current_weights[key] = clampf(_current_weights[key], 0.2, 4.0)

## Reset to a clean strategy (discard dynamic adaptations).
func reset(strategy: int = StrategyType.BALANCED) -> void:
	set_strategy(strategy)
	_game_phase = "early"
	_threat_level = 0.0
	_opportunity_level = 0.0

## Serialization for save games.
func serialize() -> Dictionary:
	return {
		"strategy": _current_strategy,
		"weights": _current_weights.duplicate(),
		"phase": _game_phase,
		"threat": _threat_level,
		"opportunity": _opportunity_level,
	}

func deserialize(data: Dictionary) -> void:
	_current_strategy = data.get("strategy", StrategyType.BALANCED)
	_current_weights = data.get("weights", STRATEGY_PRESETS[StrategyType.BALANCED]).duplicate()
	_game_phase = data.get("phase", "early")
	_threat_level = data.get("threat", 0.0)
	_opportunity_level = data.get("opportunity", 0.0)
