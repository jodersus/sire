extends Node
class_name GameResources

## Resources.gd - Sistema económico de Sire
## Estrellas, madera, piedra, frutas, pescado - producción por turno

enum ResourceType {
	STARS,    ## Moneda principal
	WOOD,     ## Madera
	STONE,    ## Piedra
	FRUITS,   ## Frutas
	FISH      ## Pescado
}

## Nombres legibles de recursos
const RESOURCE_NAMES: Dictionary = {
	ResourceType.STARS: "Estrellas",
	ResourceType.WOOD: "Madera",
	ResourceType.STONE: "Piedra",
	ResourceType.FRUITS: "Frutas",
	ResourceType.FISH: "Pescado"
}

## Producción base por terreno
const TERRAIN_PRODUCTION: Dictionary = {
	"pradera": { "stars": 0, "wood": 0, "stone": 0, "fruits": 1, "fish": 0 },
	"bosque":  { "stars": 0, "wood": 2, "stone": 0, "fruits": 0, "fish": 0 },
	"montaña": { "stars": 0, "wood": 0, "stone": 2, "fruits": 0, "fish": 0 },
	"agua":    { "stars": 0, "wood": 0, "stone": 0, "fruits": 0, "fish": 2 },
	"desierto": { "stars": 0, "wood": 0, "stone": 0, "fruits": 0, "fish": 0 },
	"nieve":   { "stars": 0, "wood": 1, "stone": 0, "fruits": 0, "fish": 0 }
}

## Clase ResourceInventory para gestionar recursos de un jugador
class ResourceInventory:
	var stars: int
	var wood: int
	var stone: int
	var fruits: int
	var fish: int
	
	## Producción por turno (calculada)
	var stars_per_turn: int
	var wood_per_turn: int
	var stone_per_turn: int
	var fruits_per_turn: int
	var fish_per_turn: int
	
	func _init():
		stars = 0
		wood = 0
		stone = 0
		fruits = 0
		fish = 0
		
		stars_per_turn = 0
		wood_per_turn = 0
		stone_per_turn = 0
		fruits_per_turn = 0
		fish_per_turn = 0
	
	## Añade recursos al inventario
	func add(resource: ResourceType, amount: int):
		match resource:
			ResourceType.STARS:
				stars += amount
			ResourceType.WOOD:
				wood += amount
			ResourceType.STONE:
				stone += amount
			ResourceType.FRUITS:
				fruits += amount
			ResourceType.FISH:
				fish += amount
	
	## Gasta recursos. Devuelve true si se pudo gastar.
	func spend(resource: ResourceType, amount: int) -> bool:
		if get_amount(resource) < amount:
			return false
		
		match resource:
			ResourceType.STARS:
				stars -= amount
			ResourceType.WOOD:
				wood -= amount
			ResourceType.STONE:
				stone -= amount
			ResourceType.FRUITS:
				fruits -= amount
			ResourceType.FISH:
				fish -= amount
		
		return true
	
	## Gasta múltiples recursos a la vez. Devuelve true si se pudo.
	func spend_multiple(costs: Dictionary) -> bool:
		## Verificar primero
		if costs.get("stars", 0) > stars:
			return false
		if costs.get("wood", 0) > wood:
			return false
		if costs.get("stone", 0) > stone:
			return false
		if costs.get("fruits", 0) > fruits:
			return false
		if costs.get("fish", 0) > fish:
			return false
		
		## Gastar
		stars -= costs.get("stars", 0)
		wood -= costs.get("wood", 0)
		stone -= costs.get("stone", 0)
		fruits -= costs.get("fruits", 0)
		fish -= costs.get("fish", 0)
		
		return true
	
	## Devuelve la cantidad de un recurso
	func get_amount(resource: ResourceType) -> int:
		match resource:
			ResourceType.STARS:
				return stars
			ResourceType.WOOD:
				return wood
			ResourceType.STONE:
				return stone
			ResourceType.FRUITS:
				return fruits
			ResourceType.FISH:
				return fish
		return 0
	
	## Calcula la producción total del jugador
	## Parámetros: ciudades del jugador, tecnologías investigadas
	func calculate_production(cities: Array[Cities.City], tech_bonuses: Dictionary):
		stars_per_turn = 0
		wood_per_turn = 0
		stone_per_turn = 0
		fruits_per_turn = 0
		fish_per_turn = 0
		
		for city in cities:
			## Producción base de la ciudad
			stars_per_turn += city.get_stars_per_turn()
			
			## Producción de edificios
			for building in city.buildings:
				var data: Dictionary = Cities.get_building_data(building)
				var effect: String = data.get("effect", "")
				var value: int = data.get("effect_value", 0)
				
				match effect:
					"wood_production":
						wood_per_turn += value
					"stone_production":
						stone_per_turn += value
					"naval_production":
						fish_per_turn += value
			
			## Frutas por población
			fruits_per_turn += city.population
		
		## Aplicar bonos de tecnología
		stars_per_turn += tech_bonuses.get("stars_bonus", 0)
	
	## Recolecta la producción del turno
	## Añade los recursos producidos al inventario
	func collect_production():
		stars += stars_per_turn
		wood += wood_per_turn
		stone += stone_per_turn
		fruits += fruits_per_turn
		fish += fish_per_turn
	
	## Devuelve un diccionario con toda la producción
	func get_production_summary() -> Dictionary:
		return {
			"stars": stars_per_turn,
			"wood": wood_per_turn,
			"stone": stone_per_turn,
			"fruits": fruits_per_turn,
			"fish": fish_per_turn
		}
	
	## Devuelve un diccionario con todos los recursos actuales
	func get_resources() -> Dictionary:
		return {
			"stars": stars,
			"wood": wood,
			"stone": stone,
			"fruits": fruits,
			"fish": fish
		}

## Calcula la producción de un terreno individual
static func get_terrain_production(terrain: String) -> Dictionary:
	return TERRAIN_PRODUCTION.get(terrain, {
		"stars": 0, "wood": 0, "stone": 0, "fruits": 0, "fish": 0
	})

## Devuelve el nombre de un recurso
static func get_resource_name(resource: ResourceType) -> String:
	return RESOURCE_NAMES.get(resource, "Desconocido")

## Crea un nuevo inventario de recursos
static func create_inventory() -> ResourceInventory:
	return ResourceInventory.new()

## Costes iniciales de recursos para el primer turno
## Ayuda a balancear el inicio de partida
static func get_starting_resources() -> Dictionary:
	return {
		"stars": 5,
		"wood": 0,
		"stone": 0,
		"fruits": 0,
		"fish": 0
	}

## Devuelve todos los tipos de recurso
static func get_all_resource_types() -> Array:
	return RESOURCE_NAMES.keys()
