class_name SirePathfinding
extends RefCounted
## Pure A* pathfinding for hexagonal grids with spherical wrap-around.
## No Godot node dependencies. Fully testable.

## Hex directions for flat-top axial coordinates (q, r)
const DIRECTIONS := [
	Vector2i(+1,  0),
	Vector2i(+1, -1),
	Vector2i( 0, -1),
	Vector2i(-1,  0),
	Vector2i(-1, +1),
	Vector2i( 0, +1),
]

var _map_width: int = 0
var _map_height: int = 0
var _wrap_enabled: bool = true

## Terrain movement costs. Can be overridden per instance.
var terrain_costs: Dictionary = {
	"pradera": 1.0,
	"bosque": 2.0,
	"montana": 3.0,
	"agua": 999.0,     ## impassable for land units
	"desierto": 1.0,
	"nieve": 2.0,
}

func _init(map_width: int = 0, map_height: int = 0, wrap_enabled: bool = true):
	_map_width = max(1, map_width)
	_map_height = max(1, map_height)
	_wrap_enabled = wrap_enabled

## Set map dimensions for wrap calculations.
func set_map_size(width: int, height: int) -> void:
	_map_width = max(1, width)
	_map_height = max(1, height)

## Wrap a coordinate to the toroidal map.
func wrap_coordinate(coord: Vector2i) -> Vector2i:
	if not _wrap_enabled or _map_width <= 0 or _map_height <= 0:
		return coord
	var w := _map_width
	var h := _map_height
	var q := ((coord.x % w) + w) % w
	var r := ((coord.y % h) + h) % h
	return Vector2i(q, r)

## Compute wrapped distance considering 9 offset copies of the target.
## Returns the shortest distance on a torus.
func wrapped_distance(a: Vector2i, b: Vector2i) -> float:
	if not _wrap_enabled:
		return axial_distance(a, b)
	
	var min_dist := axial_distance(a, b)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var offset_b := Vector2i(b.x + dx * _map_width, b.y + dy * _map_height)
			var d := axial_distance(a, offset_b)
			if d < min_dist:
				min_dist = d
	return min_dist

## Standard axial hex distance.
func axial_distance(a: Vector2i, b: Vector2i) -> float:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -a.x - a.y + b.x + b.y
	return (abs(dq) + abs(dr) + abs(ds)) / 2.0

## Get the 6 neighbours of a hex coordinate, wrapped.
func get_neighbours(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(wrap_coordinate(coord + dir))
	return result

## Get the 6 neighbours with their unwrapped coordinates (for path reconstruction).
## Returns array of {wrapped, unwrapped} dictionaries.
func get_neighbours_unwrapped(coord: Vector2i) -> Array:
	var result: Array = []
	for dir in DIRECTIONS:
		var unwrapped: Vector2i = coord + dir
		var wrapped := wrap_coordinate(unwrapped)
		result.append({"wrapped": wrapped, "unwrapped": unwrapped})
	return result

## A* pathfinding. Returns array of Vector2i from start to goal (inclusive).
## 
## Parameters:
##   start, goal: Vector2i axial coordinates
##   get_terrain: Callable(coord: Vector2i) -> String  (returns terrain type name)
##   is_passable: Callable(coord: Vector2i) -> bool   (optional, defaults to true)
##   max_cost: float (optional, abort if path cost exceeds this)
##
## Returns empty array if no path exists.
func find_path(
	start: Vector2i,
	goal: Vector2i,
	get_terrain: Callable,
	is_passable: Callable = Callable(),
	max_cost: float = 999999.0
) -> Array[Vector2i]:
	start = wrap_coordinate(start)
	goal = wrap_coordinate(goal)
	
	if start == goal:
		return [start]
	
	## Priority queue as array of {coord, priority, unwrapped}
	## We track unwrapped coordinates to properly reconstruct wrap crossings.
	var open_set: Array = []
	var came_from: Dictionary = {}  ## Vector2i(unwrapped) -> Vector2i(unwrapped parent)
	var g_score: Dictionary = {}   ## Vector2i(unwrapped) -> float
	var in_open: Dictionary = {}   ## Vector2i(wrapped) -> bool (approximate)
	
	var start_key := _key(start)
	g_score[start_key] = 0.0
	var start_f := wrapped_distance(start, goal)
	open_set.append({"coord": start, "unwrapped": start, "f": start_f})
	in_open[start_key] = true
	
	while open_set.size() > 0:
		## Find lowest f-score (simple O(n) - sufficient for turn-based)
		var best_idx := 0
		var best_f: float = open_set[0]["f"]
		for i in range(1, open_set.size()):
			if open_set[i]["f"] < best_f:
				best_f = open_set[i]["f"]
				best_idx = i
		
		var current = open_set[best_idx]
		open_set.remove_at(best_idx)
		var current_coord: Vector2i = current["coord"]
		var current_unwrapped: Vector2i = current["unwrapped"]
		var current_key := _key(current_unwrapped)
		in_open.erase(current_key)
		
		## Check if we reached goal (by wrapped position)
		if current_coord == goal:
			return _reconstruct_path(came_from, current_unwrapped)
		
		var neighbours = get_neighbours_unwrapped(current_unwrapped)
		for n in neighbours:
			var n_wrapped: Vector2i = n["wrapped"]
			var n_unwrapped: Vector2i = n["unwrapped"]
			var n_key := _key(n_unwrapped)
			
			## Passability check
			if not is_passable.is_null() and not is_passable.call(n_wrapped):
				continue
			
			## Terrain cost
			var terrain: String = get_terrain.call(n_wrapped)
			var move_cost: float = terrain_costs.get(terrain, 1.0)
			if move_cost >= 900.0:  ## impassable threshold
				continue
			
			var tentative_g: float = g_score[current_key] + move_cost
			if tentative_g > max_cost:
				continue
			
			var existing_g: float = g_score.get(n_key, 999999.0)
			if tentative_g < existing_g:
				came_from[n_key] = current_unwrapped
				g_score[n_key] = tentative_g
				var f_score: float = tentative_g + wrapped_distance(n_wrapped, goal)
				
				## Only add if not already in open with better score
				if not in_open.get(n_key, false):
					open_set.append({"coord": n_wrapped, "unwrapped": n_unwrapped, "f": f_score})
					in_open[n_key] = true
	
	return []  ## No path found

## Reconstruct path from unwrapped coordinates, then wrap them.
func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var key := _key(current)
	while came_from.has(key):
		path.append(wrap_coordinate(current))
		current = came_from[key]
		key = _key(current)
	path.append(wrap_coordinate(current))
	path.reverse()
	return path

func _key(coord: Vector2i) -> Vector2i:
	## Use unwrapped coordinate as key so we can track wrap crossings
	return coord

## Get all reachable tiles within a movement budget.
## Returns Dictionary of Vector2i(wrapped) -> float(cost)
func get_reachable(
	start: Vector2i,
	movement_budget: float,
	get_terrain: Callable,
	is_passable: Callable = Callable()
) -> Dictionary:
	start = wrap_coordinate(start)
	var reachable: Dictionary = {}
	var g_score: Dictionary = {}
	var queue: Array = [start]
	
	var start_key := _key(start)
	g_score[start_key] = 0.0
	reachable[start] = 0.0
	
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		var current_key := _key(current)
		var current_g: float = g_score[current_key]
		
		for n in get_neighbours(current):
			var n_key := _key(n)
			
			if not is_passable.is_null() and not is_passable.call(n):
				continue
			
			var terrain: String = get_terrain.call(n)
			var move_cost: float = terrain_costs.get(terrain, 1.0)
			if move_cost >= 900.0:
				continue
			
			var new_g: float = current_g + move_cost
			if new_g > movement_budget:
				continue
			
			var existing_g: float = g_score.get(n_key, 999999.0)
			if new_g < existing_g:
				g_score[n_key] = new_g
				reachable[n] = new_g
				queue.append(n)
	
	return reachable

## Heuristic for A* (admissible for toroidal grid).
func heuristic(a: Vector2i, b: Vector2i) -> float:
	return wrapped_distance(a, b)

## Get line of sight / range tiles within a given distance.
func get_tiles_in_range(center: Vector2i, range_dist: int, get_terrain: Callable = Callable()) -> Array[Vector2i]:
	center = wrap_coordinate(center)
	var result: Array[Vector2i] = []
	
	for dq in range(-range_dist, range_dist + 1):
		for dr in range(max(-range_dist, -dq - range_dist), min(range_dist, -dq + range_dist) + 1):
			var coord := wrap_coordinate(Vector2i(center.x + dq, center.y + dr))
			if coord not in result:
				result.append(coord)
	
	return result

## Check if a path exists between two points without full path reconstruction.
func path_exists(
	start: Vector2i,
	goal: Vector2i,
	get_terrain: Callable,
	is_passable: Callable = Callable()
) -> bool:
	return find_path(start, goal, get_terrain, is_passable, 999999.0).size() > 0

## Get the wrapped delta (shortest direction) from a to b considering wrap.
## Returns Vector2i indicating the direction to move.
func wrapped_direction(a: Vector2i, b: Vector2i) -> Vector2i:
	var best_delta := Vector2i(b.x - a.x, b.y - a.y)
	var best_dist := axial_distance(a, b)
	
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var offset_b := Vector2i(b.x + dx * _map_width, b.y + dy * _map_height)
			var d := axial_distance(a, offset_b)
			if d < best_dist:
				best_dist = d
				best_delta = Vector2i(offset_b.x - a.x, offset_b.y - a.y)
	
	## Normalize to one of the 6 hex directions or zero
	if best_delta == Vector2i.ZERO:
		return Vector2i.ZERO
	
	## Find closest hex direction
	var best_dir := DIRECTIONS[0]
	var best_dir_dist := 999.0
	for dir in DIRECTIONS:
		var diff := Vector2i(best_delta.x - dir.x, best_delta.y - dir.y)
		var dist: int = abs(diff.x) + abs(diff.y)
		if dist < best_dir_dist:
			best_dir_dist = dist
			best_dir = dir
	
	return best_dir
