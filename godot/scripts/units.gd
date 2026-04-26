extends Node
class_name Units

## Units.gd - Sistema de unidades de Sire
## 9 tipos de unidades con stats, movimiento, ataque, defensa y habilidades especiales

enum UnitType {
	EXPLORADOR,
	GUERRERO,
	ARQUERO,
	JINETE,
	CABALLERO,
	BARCO,
	BUQUE_GUERRA,
	CATAPULTA,
	GIGANTE
}

enum UnitState {
	IDLE,       ## Sin acciones realizadas este turno
	MOVED,      ## Ya se movió, puede atacar
	ATTACKED,   ## Ya atacó, no puede hacer más
	DONE        ## Turno completado
}

## Stats base de cada unidad
## Formato: { ataque, defensa, movimiento, coste, vida_max }
const UNIT_STATS: Dictionary = {
	UnitType.EXPLORADOR: {
		"attack": 1,
		"defense": 1,
		"movement": 2,
		"cost": 2,
		"max_health": 10,
		"rango_ataque": 1,
		"naval": false,
		"caballeria": false,
		"special": "found_city"
	},
	UnitType.GUERRERO: {
		"attack": 2,
		"defense": 2,
		"movement": 1,
		"cost": 3,
		"max_health": 15,
		"rango_ataque": 1,
		"naval": false,
		"caballeria": false,
		"special": ""
	},
	UnitType.ARQUERO: {
		"attack": 2,
		"defense": 1,
		"movement": 1,
		"cost": 3,
		"max_health": 10,
		"rango_ataque": 2,
		"naval": false,
		"caballeria": false,
		"special": "ranged_attack"
	},
	UnitType.JINETE: {
		"attack": 2,
		"defense": 1,
		"movement": 2,
		"cost": 5,
		"max_health": 15,
		"rango_ataque": 1,
		"naval": false,
		"caballeria": true,
		"special": "hit_and_run"
	},
	UnitType.CABALLERO: {
		"attack": 3,
		"defense": 3,
		"movement": 1,
		"cost": 8,
		"max_health": 25,
		"rango_ataque": 1,
		"naval": false,
		"caballeria": true,
		"special": ""
	},
	UnitType.BARCO: {
		"attack": 1,
		"defense": 1,
		"movement": 3,
		"cost": 5,
		"max_health": 10,
		"rango_ataque": 1,
		"naval": true,
		"caballeria": false,
		"special": "transport"
	},
	UnitType.BUQUE_GUERRA: {
		"attack": 3,
		"defense": 2,
		"movement": 2,
		"cost": 8,
		"max_health": 20,
		"rango_ataque": 2,
		"naval": true,
		"caballeria": false,
		"special": "ranged_attack"
	},
	UnitType.CATAPULTA: {
		"attack": 4,
		"defense": 0,
		"movement": 1,
		"cost": 8,
		"max_health": 10,
		"rango_ataque": 3,
		"naval": false,
		"caballeria": false,
		"special": "ranged_attack"
	},
	UnitType.GIGANTE: {
		"attack": 5,
		"defense": 4,
		"movement": 1,
		"cost": 20,
		"max_health": 40,
		"rango_ataque": 1,
		"naval": false,
		"caballeria": false,
		"special": ""
	}
}

const UNIT_NAMES: Dictionary = {
	UnitType.EXPLORADOR: "Explorador",
	UnitType.GUERRERO: "Guerrero",
	UnitType.ARQUERO: "Arquero",
	UnitType.JINETE: "Jinete",
	UnitType.CABALLERO: "Caballero",
	UnitType.BARCO: "Barco",
	UnitType.BUQUE_GUERRA: "Buque de Guerra",
	UnitType.CATAPULTA: "Catapulta",
	UnitType.GIGANTE: "Gigante"
}

## Clase Unit que representa una instancia de unidad en el mapa
class Unit:
	var type: UnitType
	var owner_id: int           ## ID del jugador propietario
	var tribe_id: Tribes.TribeID
	var position: Vector2i      ## Coordenadas axiales (q, r)
	
	## Stats actuales (pueden modificarse por bonos)
	var attack: int
	var defense: int
	var movement: int
	var max_health: int
	var current_health: int
	var rango_ataque: int
	
	## Estado
	var state: UnitState
	var movimientos_restantes: int
	
	## Flags
	var naval: bool
	var caballeria: bool
	var special: String
	
	func _init(unit_type: UnitType, player_id: int, tribe: Tribes.TribeID, pos: Vector2i):
		type = unit_type
		owner_id = player_id
		tribe_id = tribe
		position = pos
		state = UnitState.IDLE
		
		## Cargar stats base
		var stats: Dictionary = Units.get_unit_stats(unit_type)
		attack = stats.attack
		defense = stats.defense
		movement = stats.movement
		max_health = stats.max_health
		current_health = max_health
		rango_ataque = stats.rango_ataque
		naval = stats.naval
		caballeria = stats.caballeria
		special = stats.special
		
		## Aplicar bonos de tribu
		_apply_tribe_bonuses()
		
		movimientos_restantes = movement
	
	## Aplica los bonos de la tribu a esta unidad
	func _apply_tribe_bonuses():
		## Bono de ataque (Ferrum)
		if Tribes.has_ability(tribe_id, "attack_bonus"):
			attack = int(Tribes.apply_bonus(tribe_id, "attack_bonus", attack))
		
		## Bono naval (Maris)
		if naval and Tribes.has_ability(tribe_id, "naval_bonus"):
			attack = int(Tribes.apply_bonus(tribe_id, "naval_bonus", attack))
			movement = int(Tribes.apply_bonus(tribe_id, "naval_bonus", movement))
		
		## Bono caballería (Equus)
		if caballeria and Tribes.has_ability(tribe_id, "cavalry_movement"):
			movement = int(Tribes.apply_bonus(tribe_id, "cavalry_movement", movement))
	
	## Mueve la unidad a una nueva posición
	## Devuelve true si el movimiento fue exitoso
	func move_to(new_pos: Vector2i, cost: int) -> bool:
		if state == UnitState.ATTACKED or state == UnitState.DONE:
			return false
		if cost > movimientos_restantes:
			return false
		
		position = new_pos
		movimientos_restantes -= cost
		
		if movimientos_restantes <= 0:
			state = UnitState.MOVED
		else:
			state = UnitState.MOVED  ## Se movió, puede seguir moviéndose o atacar
		
		return true
	
	## Marca la unidad como que ha atacado
	func attack_target() -> bool:
		if state == UnitState.DONE:
			return false
		
		state = UnitState.ATTACKED
		return true
	
	## Realiza un contraataque si es posible
	func counterattack() -> bool:
		## Solo contraataque cuerpo a cuerpo
		if rango_ataque > 1:
			return false
		if current_health <= 0:
			return false
		return true
	
	## Recibe daño
	func take_damage(damage: int) -> bool:
		current_health -= damage
		if current_health <= 0:
			current_health = 0
			return true  ## Unidad destruida
		return false
	
	## Cura la unidad (hasta max_health)
	func heal(amount: int):
		current_health = mini(current_health + amount, max_health)
	
	## Restaura la unidad para un nuevo turno
	func reset_turn():
		state = UnitState.IDLE
		movimientos_restantes = movement
	
	## Marca la unidad como completada para este turno
	func end_turn():
		state = UnitState.DONE
		movimientos_restantes = 0
	
	## Comprueba si puede fundar una ciudad
	func can_found_city() -> bool:
		return special == "found_city" and state != UnitState.DONE
	
	## Comprueba si puede atacar a distancia
	func is_ranged() -> bool:
		return rango_ataque > 1
	
	## Comprueba si tiene habilidad hit-and-run
	func has_hit_and_run() -> bool:
		return special == "hit_and_run"
	
	## Comprueba si es unidad naval
	func is_naval() -> bool:
		return naval
	
	## Devuelve el nombre legible de la unidad
	func get_name() -> String:
		return Units.get_unit_name(type)
	
	## Comprueba si la unidad está viva
	func is_alive() -> bool:
		return current_health > 0

## Devuelve los stats base de un tipo de unidad
static func get_unit_stats(unit_type: UnitType) -> Dictionary:
	if UNIT_STATS.has(unit_type):
		return UNIT_STATS[unit_type]
	push_error("UnitType inválido: " + str(unit_type))
	return {}

## Devuelve el nombre legible de un tipo de unidad
static func get_unit_name(unit_type: UnitType) -> String:
	return UNIT_NAMES.get(unit_type, "Desconocido")

## Devuelve el coste de una unidad
static func get_unit_cost(unit_type: UnitType) -> int:
	var stats := get_unit_stats(unit_type)
	return stats.get("cost", 0)

## Crea una nueva instancia de unidad
static func create_unit(unit_type: UnitType, player_id: int, tribe_id: Tribes.TribeID, position: Vector2i) -> Unit:
	return Unit.new(unit_type, player_id, tribe_id, position)

## Comprueba si una unidad puede moverse por un terreno
## Devuelve el coste de movimiento, o -1 si es imposible
static func get_terrain_movement_cost(unit_type: UnitType, terrain_type: String) -> int:
	var stats := get_unit_stats(unit_type)
	
	## Unidades navales solo pueden moverse por agua
	if stats.naval:
		if terrain_type == "agua":
			return 1
		return -1
	
	## Unidades terrestres no pueden moverse por agua (excepto transporte)
	if terrain_type == "agua":
		return -1
	
	## Costes base por terreno
	match terrain_type:
		"pradera", "desierto":
			return 1
		"bosque", "nieve":
			return 2
		"montaña":
			return 3
		_:
			return 1

## Devuelve todos los tipos de unidad disponibles
static func get_all_unit_types() -> Array:
	return UNIT_STATS.keys()

## Devuelve el número total de tipos de unidad
static func get_unit_type_count() -> int:
	return UNIT_STATS.size()
