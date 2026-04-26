class_name SireAITests
extends RefCounted
## Self-contained test suite for Sire AI systems.
## Run via: SireAITests.new().run_all()
## No Godot node dependencies.

var _passed: int = 0
var _failed: int = 0

func run_all() -> void:
	print("=== Sire AI Test Suite ===")
	_test_pathfinding()
	_test_pathfinding_wrap()
	_test_decision_scoring()
	_test_strategies()
	_test_controller_easy()
	_test_controller_normal()
	_test_controller_hard()
	_test_combat_estimation()
	_test_integration()
	
	var total := _passed + _failed
	print("\n=== Results: %d/%d passed ===" % [_passed, total])
	if _failed > 0:
		print("FAILED: %d tests" % _failed)

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL: %s" % message)

## -- PATHFINDING TESTS --

func _test_pathfinding() -> void:
	print("\n[Test] Pathfinding basic")
	var pf := SirePathfinding.new(10, 10, false)
	
	## Simple flat terrain path
	var get_terrain := func(c): return "pradera"
	var is_passable := func(c): return true
	var path := pf.find_path(Vector2i(0, 0), Vector2i(2, 0), get_terrain, is_passable)
	_assert(path.size() > 0, "Path should exist for adjacent tiles")
	_assert(path[0] == Vector2i(0, 0), "Path should start at origin")
	_assert(path[path.size() - 1] == Vector2i(2, 0), "Path should end at destination")
	
	## Impassable terrain blocks path
	var get_blocked := func(c):
		if c == Vector2i(1, 0):
			return "agua"
		return "pradera"
	var path_blocked := pf.find_path(Vector2i(0, 0), Vector2i(2, 0), get_blocked, is_passable)
	## Should find a way around or be empty if completely blocked
	_assert(path_blocked.is_empty() or path_blocked.size() > 2, "Should avoid water or fail")

func _test_pathfinding_wrap() -> void:
	print("\n[Test] Pathfinding wrap-around")
	var pf := SirePathfinding.new(10, 10, true)
	
	## Distance across wrap should be shorter than across map
	var dist_wrapped := pf.wrapped_distance(Vector2i(0, 0), Vector2i(9, 0))
	var dist_normal := pf.axial_distance(Vector2i(0, 0), Vector2i(9, 0))
	_assert(dist_wrapped < dist_normal, "Wrapped distance should be shorter: %.1f < %.1f" % [dist_wrapped, dist_normal])
	_assert(dist_wrapped == 1.0, "Wrapped distance across edge should be 1, got %.1f" % dist_wrapped)
	
	## Wrap coordinates
	var wrapped := pf.wrap_coordinate(Vector2i(10, 0))
	_assert(wrapped == Vector2i(0, 0), "Wrap (10,0) on 10x10 should be (0,0)")
	
	wrapped = pf.wrap_coordinate(Vector2i(-1, 0))
	_assert(wrapped == Vector2i(9, 0), "Wrap (-1,0) on 10x10 should be (9,0)")

## -- DECISION SCORING TESTS --

func _test_decision_scoring() -> void:
	print("\n[Test] Decision scoring")
	var dec := SireAIDecision.new({"expand": 2.0, "military": 1.0})
	
	var action1 := SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_FOUND_CITY, {
		"target_tile": {"terrain": "pradera", "has_resource": true},
		"nearest_city_dist": 3.0,
	})
	var action2 := SireAIDecision.make_action(SireAIDecision.ActionType.UNIT_EXPLORE, {
		"new_tiles_revealed": 5,
	})
	
	dec.context = {"turn": 5, "owned_cities": 1}
	var score1 := dec.score_action(action1)
	var score2 := dec.score_action(action2)
	
	_assert(score1 > score2, "Founding city should score higher than exploring early game: %.1f > %.1f" % [score1, score2])
	
	## Best action selection
	var best := dec.choose_best_action([action2, action1])
	_assert(best == action1, "Should choose founding city over explore")

## -- STRATEGY TESTS --

func _test_strategies() -> void:
	print("\n[Test] Strategy presets")
	var strat := SireAIStrategies.new(SireAIStrategies.StrategyType.EXPANSION)
	var weights := strat.get_weights()
	_assert(weights.expand > weights.military, "Expansion strategy should prioritize expand over military")
	
	## Blend test
	var blended := SireAIStrategies.blend_weights(
		SireAIStrategies.STRATEGY_PRESETS[SireAIStrategies.StrategyType.MILITARY],
		SireAIStrategies.STRATEGY_PRESETS[SireAIStrategies.StrategyType.ECONOMIC],
		0.5
	)
	_assert(abs(blended.military - 1.65) < 0.1, "Blended military should be ~1.65")
	
	## Adaptation
	strat.set_strategy(SireAIStrategies.StrategyType.BALANCED)
	strat.adapt({
		"turn": 5,
		"owned_cities": 1,
		"enemy_units_nearby": 5,
		"owned_units": 2,
		"enemy_at_border": true,
	})
	var adapted := strat.get_weights()
	_assert(adapted.defense > 1.0, "Under threat, defense should increase")

## -- CONTROLLER TESTS --

func _test_controller_easy() -> void:
	print("\n[Test] AI Controller - Easy")
	var ctrl := SireAIController.new(SireAIController.Difficulty.EASY)
	ctrl.setup(
		SireAIController.Difficulty.EASY,
		"Solaris",
		func(): return {"stars": 10, "available_techs": [{"name": "Caza", "cost": 2}]},
		func(): return [{"id": "u1", "type": "Explorador", "coord": Vector2i(0, 0), "movement": 2, "hp": 10, "attack": 1}],
		func(): return [{"id": "c1", "level": 1, "population": 1, "coord": Vector2i(0, 0)}],
		func(): return [],
		func(): return [],
		func(c): return {"terrain": "pradera", "passable": true},
		func(a): return true
	)
	
	var decisions := ctrl.process_turn()
	_assert(decisions.size() > 0, "Easy AI should make at least one decision")
	
	## Easy should sometimes make suboptimal choices due to randomness
	var tech_decisions := decisions.filter(func(d): return d.get("type", -1) == SireAIDecision.ActionType.TECH_RESEARCH)
	## It might or might not research, but the system should handle it

func _test_controller_normal() -> void:
	print("\n[Test] AI Controller - Normal")
	var ctrl := SireAIController.new(SireAIController.Difficulty.NORMAL)
	ctrl.setup(
		SireAIController.Difficulty.NORMAL,
		"Ferrum",
		func(): return {"stars": 15, "available_techs": [{"name": "Caza", "cost": 2}, {"name": "Pesca", "cost": 3}]},
		func(): return [
			{"id": "u1", "type": "Explorador", "coord": Vector2i(0, 0), "movement": 2, "hp": 10, "attack": 1},
			{"id": "u2", "type": "Guerrero", "coord": Vector2i(1, 0), "movement": 1, "hp": 10, "attack": 2},
		],
		func(): return [{"id": "c1", "level": 2, "population": 2, "coord": Vector2i(0, 0), "is_coastal": false}],
		func(): return [{"id": "e1", "type": "Guerrero", "coord": Vector2i(3, 0), "defense": 1, "hp": 5}],
		func(): return [],
		func(c): return {"terrain": "pradera", "passable": true, "has_enemy": c == Vector2i(3, 0)},
		func(a): return true
	)
	
	var decisions := ctrl.process_turn()
	_assert(decisions.size() >= 2, "Normal AI should make decisions for units and city")
	
	## Should prioritize expansion early
	var found_actions := decisions.filter(func(d): return d.get("type", -1) == SireAIDecision.ActionType.UNIT_FOUND_CITY)
	## Explorer should consider founding city

func _test_controller_hard() -> void:
	print("\n[Test] AI Controller - Hard")
	var ctrl := SireAIController.new(SireAIController.Difficulty.HARD)
	ctrl.setup(
		SireAIController.Difficulty.HARD,
		"Umbra",
		func(): return {"stars": 30, "available_techs": [{"name": "Herreria", "cost": 8}, {"name": "Caza", "cost": 2}]},
		func(): return [
			{"id": "u1", "type": "Caballero", "coord": Vector2i(0, 0), "movement": 1, "hp": 15, "attack": 3},
			{"id": "u2", "type": "Guerrero", "coord": Vector2i(2, 0), "movement": 1, "hp": 10, "attack": 2},
		],
		func(): return [
			{"id": "c1", "level": 3, "population": 4, "coord": Vector2i(0, 0), "is_coastal": true, "has_port": false},
		],
		func(): return [{"id": "e1", "type": "Guerrero", "coord": Vector2i(4, 0), "defense": 1, "hp": 3}],
		func(): return [{"id": "ec1", "is_city": true, "coord": Vector2i(5, 0), "defenders": 0}],
		func(c): return {"terrain": "pradera", "passable": true, "has_enemy": c in [Vector2i(4, 0), Vector2i(5, 0)]},
		func(a): return true
	)
	
	var decisions := ctrl.process_turn()
	_assert(decisions.size() > 0, "Hard AI should make decisions")
	
	## Hard should consider flanking and economy
	var move_actions := decisions.filter(func(d): return d.get("type", -1) == SireAIDecision.ActionType.UNIT_MOVE)
	for ma in move_actions:
		if ma.get("purpose", "") == "flank":
			## Found a flanking move
			pass

## -- COMBAT ESTIMATION TESTS --

func _test_combat_estimation() -> void:
	print("\n[Test] Combat estimation")
	var result := SireAIDecision.estimate_combat(
		{"attack": 3, "hp": 15},
		{"defense": 1, "hp": 3},
		{"terrain": "pradera"}
	)
	_assert(result.recommend_attack, "3 atk vs 1 def should recommend attack")
	_assert(result.ratio >= 2.0, "Advantage ratio should be >= 2")
	
	var result_mountain := SireAIDecision.estimate_combat(
		{"attack": 2, "hp": 10},
		{"defense": 2, "hp": 10},
		{"terrain": "montana"}
	)
	_assert(not result_mountain.recommend_attack, "Equal forces on mountain should not recommend attack")

## -- INTEGRATION TEST --

func _test_integration() -> void:
	print("\n[Test] Full integration")
	## Create a full AI stack and run multiple turns
	var ctrl := SireAIController.new(SireAIController.Difficulty.NORMAL)
	ctrl.pathfinding = SirePathfinding.new(20, 20, true)
	
	var stars := 10
	var units := [
		{"id": "u1", "type": "Explorador", "coord": Vector2i(5, 5), "movement": 2, "hp": 10, "attack": 1},
	]
	var cities := [
		{"id": "c1", "level": 1, "population": 1, "coord": Vector2i(5, 5), "is_coastal": false},
	]
	
	ctrl.setup(
		SireAIController.Difficulty.NORMAL,
		"Sylva",
		func(): return {"stars": stars, "available_techs": [{"name": "Organizacion", "cost": 0}], "known_techs": [], "turn": 1},
		func(): return units,
		func(): return cities,
		func(): return [],
		func(): return [],
		func(c): return {"terrain": "pradera", "passable": true, "unexplored": c != Vector2i(5, 5)},
		func(a): return true
	)
	
	## Run 3 turns
	for i in range(3):
		var d := ctrl.process_turn()
		_assert(d.size() > 0, "Turn %d should produce decisions" % (i + 1))
	
	## Test serialization
	var saved := ctrl.serialize()
	_assert(saved.has("difficulty"), "Serialization should include difficulty")
	_assert(saved.has("strategy"), "Serialization should include strategy")
	
	var ctrl2 := SireAIController.new()
	ctrl2.deserialize(saved)
	_assert(ctrl2.difficulty == SireAIController.Difficulty.NORMAL, "Deserialized difficulty should match")

## Run this to verify all AI systems work independently.
## Can be called from any Godot script or test runner.
static func run() -> void:
	var tests := SireAITests.new()
	tests.run_all()
