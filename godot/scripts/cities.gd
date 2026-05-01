extends Node
class_name Cities

## Cities.gd - Sistema de ciudades de Sire
## Niveles 1-5, población, territorio, edificios construibles y cola de entrenamiento

enum BuildingType {
	GRANJA,
	PUERTO,
	MINA,
	ASERRADERO,
	FORJA,
	MURALLA,
	TEMPO,
	PARQUE
}

## Definición de edificios
## Formato: { nombre, coste_estrellas, coste_madera, coste_piedra, efecto }
const BUILDING_DATA: Dictionary = {
	BuildingType.GRANJA: {
		"name": "Granja",
		"cost_stars": 4,
		"cost_wood": 0,
		"cost_stone": 0,
		"requires_water": false,
		"effect": "food_production",
		"effect_value": 1,
		"description": "+1 población/turno."
	},
	BuildingType.PUERTO: {
		"name": "Puerto",
		"cost_stars": 10,
		"cost_wood": 0,
		"cost_stone": 0,
		"requires_water": true,
		"effect": "naval_production",
		"effect_value": 1,
		"description": "Permite construir unidades navales. +1 pescado/turno."
	},
	BuildingType.MINA: {
		"name": "Mina",
		"cost_stars": 5,
		"cost_wood": 0,
		"cost_stone": 0,
		"requires_mountain": true,
		"effect": "stone_production",
		"effect_value": 2,
		"description": "+2 piedra/turno si hay montaña en territorio."
	},
	BuildingType.ASERRADERO: {
		"name": "Aserradero",
		"cost_stars": 5,
		"cost_wood": 0,
		"cost_stone": 0,
		"requires_forest": true,
		"effect": "wood_production",
		"effect_value": 2,
		"description": "+2 madera/turno si hay bosque en territorio."
	},
	BuildingType.FORJA: {
		"name": "Forja",
		"cost_stars": 10,
		"cost_wood": 5,
		"cost_stone": 5,
		"requires_tech": "herreria",
		"effect": "unit_discount",
		"effect_value": 0.10,
		"description": "-10% coste de unidades terrestres."
	},
	BuildingType.MURALLA: {
		"name": "Muralla",
		"cost_stars": 5,
		"cost_wood": 0,
		"cost_stone": 10,
		"effect": "city_defense",
		"effect_value": 3,
		"description": "+3 defensa de la ciudad en asedios."
	},
	BuildingType.TEMPO: {
		"name": "Templo",
		"cost_stars": 20,
		"cost_wood": 0,
		"cost_stone": 10,
		"requires_tech": "construccion",
		"effect": "population_growth",
		"effect_value": 1.5,
		"description": "+50% crecimiento de población."
	},
	BuildingType.PARQUE: {
		"name": "Parque",
		"cost_stars": 5,
		"cost_wood": 0,
		"cost_stone": 0,
		"effect": "happiness",
		"effect_value": 1,
		"description": "+1 felicidad, reduce tiempo de entrenamiento."
	}
}

## Datos por nivel de ciudad
## Formato: { población_max, territorio_radio, bonus_producción }
const CITY_LEVEL_DATA: Dictionary = {
	1: { "max_pop": 2,  "territory": 1, "production_bonus": 0,   "stars_per_turn": 2 },
	2: { "max_pop": 4,  "territory": 1, "production_bonus": 1,   "stars_per_turn": 3 },
	3: { "max_pop": 6,  "territory": 2, "production_bonus": 2,   "stars_per_turn": 4 },
	4: { "max_pop": 8,  "territory": 2, "production_bonus": 3,   "stars_per_turn": 5 },
	5: { "max_pop": 12, "territory": 3, "production_bonus": 5,   "stars_per_turn": 7 }
}

## Coste de subida de nivel
const LEVEL_UP_COST: Dictionary = {
	2: { "stars": 5,  "population": 2 },
	3: { "stars": 10, "population": 4 },
	4: { "stars": 15, "population": 6 },
	5: { "stars": 20, "population": 8 }
}

## Clase City que representa una ciudad en el mapa
class City:
	var name: String
	var owner_id: int
	var tribe_id: Tribes.TribeID
	var position: Vector2i
	
	## Nivel y población
	var level: int
	var population: int
	var population_growth_progress: float  ## 0.0 a 1.0, acumula por turno
	
	## Edificios construidos
	var buildings: Array[BuildingType]
	
	## Cola de entrenamiento
	## Formato: [ { unit_type, turns_remaining } ]
	var training_queue: Array[Dictionary]
	var currently_training: Dictionary  ## Unidad en entrenamiento actual
	
	## Estado
	var under_siege: bool
	var siege_defense_bonus: int
	
	## Recursos producidos por turno (caché)
	var production_cache: Dictionary
	
	func _init(city_name: String, player_id: int, tribe: Tribes.TribeID, pos: Vector2i):
		name = city_name
		owner_id = player_id
		tribe_id = tribe
		position = pos
		
		level = 1
		population = 1
		population_growth_progress = 0.0
		
		buildings = []
		training_queue = []
		currently_training = {}
		
		under_siege = false
		siege_defense_bonus = 0
		
		_update_production_cache()
	
	## Devuelve los datos del nivel actual
	func get_level_data() -> Dictionary:
		return Cities.get_level_data(level)
	
	## Devuelve la población máxima para el nivel actual
	func get_max_population() -> int:
		return get_level_data().get("max_pop", 2)
	
	## Devuelve el radio de territorio
	func get_territory_radius() -> int:
		return get_level_data().get("territory", 1)
	
	## Calcula la producción de estrellas por turno
	func get_stars_per_turn() -> int:
		var base: int = get_level_data().get("stars_per_turn", 2)
		var bonus: int = get_level_data().get("production_bonus", 0)
		return base + bonus
	
	## Añade población al progreso de crecimiento
	## Devuelve true si la ciudad subió de población
	func grow_population(growth_amount: float) -> bool:
		var max_pop: int = get_max_population()
		if population >= max_pop:
			return false
		
		## Aplicar bono de tribu Nomad
		var effective_growth: float = growth_amount
		if Tribes.has_ability(tribe_id, "city_growth"):
			effective_growth = Tribes.apply_bonus(tribe_id, "city_growth", growth_amount)
		
		population_growth_progress += effective_growth
		
		if population_growth_progress >= 1.0:
			population += 1
			population_growth_progress -= 1.0
			return true
		return false
	
	## Intenta subir de nivel
	## Devuelve true si se subió de nivel
	func level_up(stars_available: int) -> bool:
		if level >= 5:
			return false
		
		var next_level: int = level + 1
		var cost: Dictionary = Cities.get_level_up_cost(next_level)
		
		if stars_available < cost.stars:
			return false
		if population < cost.population:
			return false
		
		level = next_level
		_update_production_cache()
		return true
	
	## Comprueba si se puede construir un edificio
	func can_build_building(building: BuildingType, resources: Dictionary) -> bool:
		## Ya construido?
		if buildings.has(building):
			return false
		
		var data: Dictionary = Cities.get_building_data(building)
		
		## Comprobar costes
		var wood_cost: int = data.get("cost_wood", 0)
		var stone_cost: int = data.get("cost_stone", 0)
		var stars_cost: int = data.get("cost_stars", 0)
		
		## Aplicar descuento de tribu Sylva en madera
		if Tribes.has_ability(tribe_id, "wood_discount") and wood_cost > 0:
			wood_cost = int(Tribes.apply_bonus(tribe_id, "wood_discount", wood_cost))
		
		if resources.get("wood", 0) < wood_cost:
			return false
		if resources.get("stone", 0) < stone_cost:
			return false
		if resources.get("stars", 0) < stars_cost:
			return false
		
		return true
	
	## Construye un edificio
	## Devuelve el coste real pagado (para deducir recursos)
	func build_building(building: BuildingType) -> Dictionary:
		if buildings.has(building):
			return {}
		
		var data: Dictionary = Cities.get_building_data(building)
		var wood_cost: int = data.get("cost_wood", 0)
		
		## Aplicar descuento de tribu Sylva en madera
		if Tribes.has_ability(tribe_id, "wood_discount") and wood_cost > 0:
			wood_cost = int(Tribes.apply_bonus(tribe_id, "wood_discount", wood_cost))
		
		buildings.append(building)
		_update_production_cache()
		
		return {
			"stars": data.get("cost_stars", 0),
			"wood": wood_cost,
			"stone": data.get("cost_stone", 0)
		}
	
	## Añade una unidad a la cola de entrenamiento
	## Devuelve true si se añadió correctamente
	func queue_unit(unit_type: Units.UnitType) -> bool:
		## Máximo 3 unidades en cola
		if training_queue.size() >= 3:
			return false
		
		var cost: int = Units.get_unit_cost(unit_type)
		var train_turns: int = maxi(1, cost / 2)  ## Coste/2 turnos, mínimo 1
		
		## Reducir turnos si hay parque
		if buildings.has(BuildingType.PARQUE):
			train_turns = maxi(1, train_turns - 1)
		
		training_queue.append({
			"unit_type": unit_type,
			"turns_remaining": train_turns
		})
		
		return true
	
	## Procesa la cola de entrenamiento
	## Devuelve las unidades completadas este turno
	func process_training() -> Array[Units.UnitType]:
		var completed: Array[Units.UnitType] = []
		
		if currently_training.is_empty() and not training_queue.is_empty():
			currently_training = training_queue.pop_front()
		
		if not currently_training.is_empty():
			currently_training.turns_remaining -= 1
			
			if currently_training.turns_remaining <= 0:
				completed.append(currently_training.unit_type)
				currently_training = {}
				
				## Empezar siguiente unidad
				if not training_queue.is_empty():
					currently_training = training_queue.pop_front()
		
		return completed
	
	## Entra en estado de asedio
	func start_siege():
		under_siege = true
		siege_defense_bonus = 0
		## Bonus de muralla
		if buildings.has(BuildingType.MURALLA):
			var data: Dictionary = Cities.get_building_data(BuildingType.MURALLA)
			siege_defense_bonus = data.get("effect_value", 0)
	
	## Termina el asedio
	func end_siege():
		under_siege = false
		siege_defense_bonus = 0
	
	## Devuelve la defensa total de la ciudad
	func get_defense() -> int:
		var base_defense: int = level  ## Nivel = defensa base
		base_defense += siege_defense_bonus
		return base_defense
	
	## Actualiza la caché de producción
	func _update_production_cache():
		production_cache = {
			"stars": get_stars_per_turn(),
			"wood": _get_resource_production("wood"),
			"stone": _get_resource_production("stone"),
			"fish": _get_resource_production("fish")
		}
	
	## Calcula producción de un recurso específico
	func _get_resource_production(resource: String) -> int:
		var amount: int = 0
		for building in buildings:
			var data: Dictionary = Cities.get_building_data(building)
			if data.get("effect", "") == resource + "_production":
				amount += data.get("effect_value", 0)
		return amount
	
	## Devuelve el progreso de entrenamiento actual (0.0 a 1.0)
	func get_training_progress() -> float:
		if currently_training.is_empty():
			return 0.0
		## Necesitaríamos guardar los turnos totales para calcular progreso exacto
		## Por ahora devolvemos un valor aproximado
		return 0.5  ## Simplificado

## Devuelve los datos de un edificio
static func get_building_data(building: BuildingType) -> Dictionary:
	if BUILDING_DATA.has(building):
		return BUILDING_DATA[building]
	push_error("BuildingType inválido: " + str(building))
	return {}

## Devuelve los datos de un nivel de ciudad
static func get_level_data(level: int) -> Dictionary:
	if CITY_LEVEL_DATA.has(level):
		return CITY_LEVEL_DATA[level]
	push_error("Nivel de ciudad inválido: " + str(level))
	return CITY_LEVEL_DATA[1]

## Devuelve el coste de subida a un nivel
static func get_level_up_cost(level: int) -> Dictionary:
	if LEVEL_UP_COST.has(level):
		return LEVEL_UP_COST[level]
	return { "stars": 999, "population": 999 }

## Devuelve el nombre de un edificio
static func get_building_name(building: BuildingType) -> String:
	var data := get_building_data(building)
	return data.get("name", "Desconocido")

## Devuelve todos los tipos de edificio
static func get_all_building_types() -> Array:
	return BUILDING_DATA.keys()

## Crea una nueva ciudad
static func create_city(city_name: String, player_id: int, tribe_id: Tribes.TribeID, position: Vector2i) -> City:
	return City.new(city_name, player_id, tribe_id, position)
