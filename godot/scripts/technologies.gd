extends Node
class_name Technologies

## Technologies.gd - Árbol tecnológico de Sire
## 14 tecnologías con costes, prerequisitos y desbloqueos

enum TechID {
	ORGANIZACION,
	CAZA,
	PESCA,
	AGRICULTURA,
	EQUITACION,
	NAVEGACION,
	HERRERIA,
	VELAS,
	ESCUDOS,
	ARQUERIA,
	MATEMATICAS,
	CONSTRUCCION,
	CATAPULTAS,
	CAMINOS,
	COMERCIO
}

## Definición de cada tecnología
## Formato: nombre, coste, prerequisitos, desbloqueos
const TECH_DATA: Dictionary = {
	TechID.ORGANIZACION: {
		"name": "Organización",
		"cost": 0,
		"prerequisites": [],
		"unlocks_units": [Units.UnitType.EXPLORADOR],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.CAZA, TechID.PESCA, TechID.AGRICULTURA],
		"description": "Permite entrenar Exploradores."
	},
	TechID.CAZA: {
		"name": "Caza",
		"cost": 2,
		"prerequisites": [TechID.ORGANIZACION],
		"unlocks_units": [Units.UnitType.GUERRERO],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.EQUITACION, TechID.NAVEGACION],
		"description": "Permite entrenar Guerreros."
	},
	TechID.PESCA: {
		"name": "Pesca",
		"cost": 3,
		"prerequisites": [TechID.ORGANIZACION],
		"unlocks_units": [],
		"unlocks_buildings": [Cities.BuildingType.PUERTO],
		"unlocks_techs": [TechID.VELAS],
		"description": "Desbloquea el Puerto. +1 pescado/turno costero."
	},
	TechID.AGRICULTURA: {
		"name": "Agricultura",
		"cost": 4,
		"prerequisites": [TechID.ORGANIZACION],
		"unlocks_units": [],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.CONSTRUCCION],
		"description": "Aumenta crecimiento de población."
	},
	TechID.EQUITACION: {
		"name": "Equitación",
		"cost": 5,
		"prerequisites": [TechID.CAZA],
		"unlocks_units": [Units.UnitType.JINETE],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.HERRERIA],
		"description": "Permite entrenar Jinetes."
	},
	TechID.NAVEGACION: {
		"name": "Navegación",
		"cost": 6,
		"prerequisites": [TechID.CAZA],
		"unlocks_units": [Units.UnitType.BARCO],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.CONSTRUCCION],
		"description": "Permite construir Barcos."
	},
	TechID.HERRERIA: {
		"name": "Herrería",
		"cost": 8,
		"prerequisites": [TechID.EQUITACION],
		"unlocks_units": [Units.UnitType.CABALLERO],
		"unlocks_buildings": [Cities.BuildingType.FORJA],
		"unlocks_techs": [TechID.ESCUDOS, TechID.ARQUERIA, TechID.MATEMATICAS],
		"description": "Permite entrenar Caballeros y construir Forjas."
	},
	TechID.VELAS: {
		"name": "Velas",
		"cost": 7,
		"prerequisites": [TechID.PESCA],
		"unlocks_units": [Units.UnitType.BUQUE_GUERRA],
		"unlocks_buildings": [],
		"unlocks_techs": [],
		"description": "Permite construir Buques de Guerra."
	},
	TechID.ESCUDOS: {
		"name": "Escudos",
		"cost": 5,
		"prerequisites": [TechID.HERRERIA],
		"unlocks_units": [],
		"unlocks_buildings": [],
		"unlocks_techs": [],
		"description": "Todas las unidades terrestres +1 defensa."
	},
	TechID.ARQUERIA: {
		"name": "Arquería",
		"cost": 6,
		"prerequisites": [TechID.HERRERIA],
		"unlocks_units": [Units.UnitType.ARQUERO],
		"unlocks_buildings": [],
		"unlocks_techs": [],
		"description": "Permite entrenar Arqueros."
	},
	TechID.MATEMATICAS: {
		"name": "Matemáticas",
		"cost": 8,
		"prerequisites": [TechID.HERRERIA],
		"unlocks_units": [],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.CATAPULTAS],
		"description": "Prerequisito para tecnologías avanzadas."
	},
	TechID.CONSTRUCCION: {
		"name": "Construcción",
		"cost": 10,
		"prerequisites": [TechID.NAVEGACION, TechID.AGRICULTURA],
		"unlocks_units": [],
		"unlocks_buildings": [Cities.BuildingType.MURALLA, Cities.BuildingType.TEMPO],
		"unlocks_techs": [TechID.CAMINOS],
		"description": "Desbloquea Murallas y Templos."
	},
	TechID.CATAPULTAS: {
		"name": "Catapultas",
		"cost": 10,
		"prerequisites": [TechID.MATEMATICAS],
		"unlocks_units": [Units.UnitType.CATAPULTA],
		"unlocks_buildings": [],
		"unlocks_techs": [],
		"description": "Permite entrenar Catapultas."
	},
	TechID.CAMINOS: {
		"name": "Caminos",
		"cost": 8,
		"prerequisites": [TechID.CONSTRUCCION],
		"unlocks_units": [],
		"unlocks_buildings": [],
		"unlocks_techs": [TechID.COMERCIO],
		"description": "Unidades se mueven +1 en territorio propio."
	},
	TechID.COMERCIO: {
		"name": "Comercio",
		"cost": 12,
		"prerequisites": [TechID.CAMINOS],
		"unlocks_units": [Units.UnitType.GIGANTE],
		"unlocks_buildings": [],
		"unlocks_techs": [],
		"description": "Permite entrenar Gigantes. +2 estrellas/turno."
	}
}

## Clase TechnologyTree para gestionar el progreso de un jugador
class TechnologyTree:
	var researched: Array[TechID]      ## Tecnologías investigadas
	var available: Array[TechID]       ## Tecnologías disponibles para investigar
	var researching: TechID            ## Tecnología en investigación actual
	var research_progress: int         ## Estrellas invertidas en investigación actual
	
	func _init():
		researched = [TechID.ORGANIZACION]  ## Organización es gratis
		available = _update_available()
		researching = TechID.ORGANIZACION
		research_progress = 0
	
	## Actualiza la lista de tecnologías disponibles
	func _update_available() -> Array[TechID]:
		var new_available: Array[TechID] = []
		
		for tech_id in TechID.values():
			if researched.has(tech_id):
				continue
			if available.has(tech_id):
				continue
			
			var data: Dictionary = Technologies.get_tech_data(tech_id)
			var prereqs: Array = data.get("prerequisites", [])
			
			## Comprobar si todos los prerequisitos están investigados
			var prereqs_met := true
			for prereq in prereqs:
				if not researched.has(prereq):
					prereqs_met = false
					break
			
			if prereqs_met:
				new_available.append(tech_id)
		
		return new_available
	
	## Inicia la investigación de una tecnología
	## Devuelve true si se pudo iniciar
	func start_research(tech_id: TechID) -> bool:
		if not available.has(tech_id):
			return false
		if researching != TechID.ORGANIZACION and research_progress > 0:
			return false  ## Ya hay una investigación en curso
		
		researching = tech_id
		research_progress = 0
		return true
	
	## Invierte estrellas en la investigación actual
	## Devuelve true si la tecnología se completó
	func invest_stars(amount: int) -> bool:
		if researching == TechID.ORGANIZACION:
			return false
		
		var data: Dictionary = Technologies.get_tech_data(researching)
		var cost: int = data.get("cost", 0)
		
		research_progress += amount
		
		if research_progress >= cost:
			## Investigación completada
			researched.append(researching)
			available.erase(researching)
			
			## Actualizar disponibles
			var new_available := _update_available()
			for tech in new_available:
				if not available.has(tech):
					available.append(tech)
			
			researching = TechID.ORGANIZACION
			research_progress = 0
			return true
		
		return false
	
	## Devuelve el coste de la tecnología en investigación
	func get_current_research_cost() -> int:
		if researching == TechID.ORGANIZACION:
			return 0
		var data: Dictionary = Technologies.get_tech_data(researching)
		return data.get("cost", 0)
	
	## Devuelve las estrellas restantes para completar
	func get_research_remaining() -> int:
		var cost: int = get_current_research_cost()
		return maxi(0, cost - research_progress)
	
	## Comprueba si una tecnología está investigada
	func is_researched(tech_id: TechID) -> bool:
		return researched.has(tech_id)
	
	## Comprueba si una tecnología está disponible
	func is_available(tech_id: TechID) -> bool:
		return available.has(tech_id)
	
	## Comprueba si una unidad está desbloqueada
	func is_unit_unlocked(unit_type: Units.UnitType) -> bool:
		for tech_id in researched:
			var data: Dictionary = Technologies.get_tech_data(tech_id)
			var unlocks: Array = data.get("unlocks_units", [])
			if unlocks.has(unit_type):
				return true
		return false
	
	## Comprueba si un edificio está desbloqueado
	func is_building_unlocked(building: Cities.BuildingType) -> bool:
		for tech_id in researched:
			var data: Dictionary = Technologies.get_tech_data(tech_id)
			var unlocks: Array = data.get("unlocks_buildings", [])
			if unlocks.has(building):
				return true
		return false
	
	## Devuelve todas las unidades desbloqueadas
	func get_unlocked_units() -> Array[Units.UnitType]:
		var unlocked: Array[Units.UnitType] = []
		for tech_id in researched:
			var data: Dictionary = Technologies.get_tech_data(tech_id)
			var units: Array = data.get("unlocks_units", [])
			for unit in units:
				if not unlocked.has(unit):
					unlocked.append(unit)
		return unlocked
	
	## Devuelve todos los edificios desbloqueados
	func get_unlocked_buildings() -> Array[Cities.BuildingType]:
		var unlocked: Array[Cities.BuildingType] = []
		for tech_id in researched:
			var data: Dictionary = Technologies.get_tech_data(tech_id)
			var buildings: Array = data.get("unlocks_buildings", [])
			for building in buildings:
				if not unlocked.has(building):
					unlocked.append(building)
		return unlocked
	
	## Aplica efectos pasivos de tecnologías investigadas
	## Devuelve un diccionario con modificadores
	func get_passive_bonuses() -> Dictionary:
		var bonuses := {
			"unit_defense": 0,
			"movement_bonus": 0,
			"stars_bonus": 0
		}
		
		if researched.has(TechID.ESCUDOS):
			bonuses.unit_defense += 1
		if researched.has(TechID.CAMINOS):
			bonuses.movement_bonus += 1
		if researched.has(TechID.COMERCIO):
			bonuses.stars_bonus += 2
		
		return bonuses

## Devuelve los datos de una tecnología
static func get_tech_data(tech_id: TechID) -> Dictionary:
	if TECH_DATA.has(tech_id):
		return TECH_DATA[tech_id]
	push_error("TechID inválido: " + str(tech_id))
	return {}

## Devuelve el nombre de una tecnología
static func get_tech_name(tech_id: TechID) -> String:
	var data := get_tech_data(tech_id)
	return data.get("name", "Desconocido")

## Devuelve el coste base de una tecnología
static func get_tech_cost(tech_id: TechID) -> int:
	var data := get_tech_data(tech_id)
	return data.get("cost", 0)

## Comprueba si un jugador puede investigar una tecnología
static func can_research(tech_id: TechID, researched_techs: Array[TechID]) -> bool:
	if researched_techs.has(tech_id):
		return false
	
	var data := get_tech_data(tech_id)
	var prereqs: Array = data.get("prerequisites", [])
	
	for prereq in prereqs:
		if not researched_techs.has(prereq):
			return false
	
	return true

## Crea un nuevo árbol tecnológico para un jugador
static func create_tech_tree() -> TechnologyTree:
	return TechnologyTree.new()

## Devuelve todos los IDs de tecnología
static func get_all_tech_ids() -> Array:
	return TECH_DATA.keys()

## Devuelve el número total de tecnologías
static func get_tech_count() -> int:
	return TECH_DATA.size()
