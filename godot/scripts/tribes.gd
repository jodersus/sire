extends Node
class_name Tribes

## Tribes.gd - Definición de las 7 tribus de Sire
## Cada tribu tiene: nombre, color, habilidad especial y unidad inicial

enum TribeID {
	SOLARIS,
	UMBRA,
	SYLVA,
	FERRUM,
	MARIS,
	EQUUS,
	NOMAD
}

const TRIBE_DATA: Dictionary = {
	TribeID.SOLARIS: {
		"name": "Solaris",
		"color": Color("#F4D03F"),
		"special_ability": "tech_discount",
		"ability_value": 0.20,  ## -20% coste tecnologías
		"description": "-20% coste de tecnologías",
		"starting_unit": Units.UnitType.EXPLORADOR
	},
	TribeID.UMBRA: {
		"name": "Umbra",
		"color": Color("#2C3E50"),
		"special_ability": "vision_bonus",
		"ability_value": 1,  ## +1 visión
		"description": "+1 rango de visión",
		"starting_unit": Units.UnitType.EXPLORADOR
	},
	TribeID.SYLVA: {
		"name": "Sylva",
		"color": Color("#27AE60"),
		"special_ability": "wood_discount",
		"ability_value": 0.30,  ## -30% coste madera
		"description": "-30% coste de madera en edificios",
		"starting_unit": Units.UnitType.EXPLORADOR
	},
	TribeID.FERRUM: {
		"name": "Ferrum",
		"color": Color("#922B21"),
		"special_ability": "attack_bonus",
		"ability_value": 1,  ## +1 ataque
		"description": "+1 de ataque a todas las unidades",
		"starting_unit": Units.UnitType.GUERRERO
	},
	TribeID.MARIS: {
		"name": "Maris",
		"color": Color("#3498DB"),
		"special_ability": "naval_bonus",
		"ability_value": 1,  ## Bono naval
		"description": "Unidades navales +1 ataque y +1 movimiento",
		"starting_unit": Units.UnitType.BARCO
	},
	TribeID.EQUUS: {
		"name": "Equus",
		"color": Color("#E67E22"),
		"special_ability": "cavalry_movement",
		"ability_value": 1,  ## +1 movimiento caballería
		"description": "Unidades de caballería +1 movimiento",
		"starting_unit": Units.UnitType.JINETE
	},
	TribeID.NOMAD: {
		"name": "Nomad",
		"color": Color("#8E44AD"),
		"special_ability": "city_growth",
		"ability_value": 0.25,  ## +25% crecimiento ciudades
		"description": "+25% crecimiento de ciudades",
		"starting_unit": Units.UnitType.EXPLORADOR
	}
}

## Devuelve los datos de una tribu por su ID
static func get_tribe_data(tribe_id: TribeID) -> Dictionary:
	if TRIBE_DATA.has(tribe_id):
		return TRIBE_DATA[tribe_id]
	push_error("TribeID inválido: " + str(tribe_id))
	return {}

## Devuelve el nombre de una tribu
static func get_tribe_name(tribe_id: TribeID) -> String:
	var data := get_tribe_data(tribe_id)
	return data.get("name", "Desconocido")

## Devuelve el color de una tribu
static func get_tribe_color(tribe_id: TribeID) -> Color:
	var data := get_tribe_data(tribe_id)
	return data.get("color", Color.WHITE)

## Devuelve la unidad inicial de una tribu
static func get_starting_unit(tribe_id: TribeID) -> int:
	var data := get_tribe_data(tribe_id)
	return data.get("starting_unit", Units.UnitType.EXPLORADOR)

## Aplica el bono de una tribu a un valor base
## Parámetros: tribe_id, ability_type, base_value
## Devuelve el valor modificado
static func apply_bonus(tribe_id: TribeID, ability_type: String, base_value: float) -> float:
	var data := get_tribe_data(tribe_id)
	if data.get("special_ability", "") == ability_type:
		var ability_value: float = data.get("ability_value", 0.0)
		match ability_type:
			"tech_discount", "wood_discount":
				return base_value * (1.0 - ability_value)  ## Reduce coste
			"city_growth":
				return base_value * (1.0 + ability_value)  ## Aumenta crecimiento
			_:  ## attack_bonus, vision_bonus, naval_bonus, cavalry_movement
				return base_value + ability_value  ## Añade valor flat
	return base_value

## Devuelve si una tribu tiene una habilidad específica
static func has_ability(tribe_id: TribeID, ability_type: String) -> bool:
	var data := get_tribe_data(tribe_id)
	return data.get("special_ability", "") == ability_type

## Devuelve un array con todos los IDs de tribus
static func get_all_tribe_ids() -> Array:
	return TRIBE_DATA.keys()

## Devuelve el número total de tribus
static func get_tribe_count() -> int:
	return TRIBE_DATA.size()
