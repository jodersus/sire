extends Node
class_name Combat

## Combat.gd - Sistema de combate de Sire
## Resolución de ataques con bonos de terreno, contraataque y asedio

## Bonos de terreno para defensa
const TERRAIN_DEFENSE_BONUS: Dictionary = {
	"pradera": 0,
	"bosque": 1,
	"montaña": 2,
	"agua": 0,
	"desierto": 0,
	"nieve": 0
}

## Bonos de terreno para ataque
const TERRAIN_ATTACK_BONUS: Dictionary = {
	"pradera": 0,
	"bosque": 0,
	"montaña": 1,
	"agua": 0,
	"desierto": 0,
	"nieve": 0
}

## Resultado de un combate
class CombatResult:
	var attacker_damage_dealt: int
	var defender_damage_dealt: int
	var attacker_destroyed: bool
	var defender_destroyed: bool
	var city_captured: bool
	var experience_gained: int
	
	func _init():
		attacker_damage_dealt = 0
		defender_damage_dealt = 0
		attacker_destroyed = false
		defender_destroyed = false
		city_captured = false
		experience_gained = 0

## Resuelve un ataque entre dos unidades
## Parámetros:
##   attacker: unidad atacante
##   defender: unidad defensora
##   attacker_terrain: terreno donde está el atacante
##   defender_terrain: terreno donde está el defensor
##   city: ciudad en la posición del defensor (opcional, para asedio)
## Devuelve: CombatResult con el resultado
static func resolve_attack(attacker: Units.Unit, defender: Units.Unit,
						   attacker_terrain: String = "pradera",
						   defender_terrain: String = "pradera",
						   city: Cities.City = null) -> CombatResult:
	var result := CombatResult.new()
	
	## Calcular fuerza de ataque del atacante
	var attack_force: int = _calculate_attack_force(attacker, attacker_terrain)
	
	## Calcular fuerza de defensa del defensor
	var defense_force: int = _calculate_defense_force(defender, defender_terrain, city)
	
	## Calcular daño
	var damage_to_defender: int = _calculate_damage(attack_force, defense_force)
	var damage_to_attacker: int = 0
	
	## Aplicar daño al defensor
	result.attacker_damage_dealt = damage_to_defender
	result.defender_destroyed = defender.take_damage(damage_to_defender)
	
	## Contraataque (solo cuerpo a cuerpo, y si el defensor sobrevive)
	if not attacker.is_ranged() and not defender.is_ranged() and not result.defender_destroyed:
		if defender.counterattack():
			damage_to_attacker = _calculate_damage(defense_force, attack_force)
			result.defender_damage_dealt = damage_to_attacker
			result.attacker_destroyed = attacker.take_damage(damage_to_attacker)
	
	## Experiencia (simplificada)
	if result.defender_destroyed:
		result.experience_gained = defender.max_health
	
	## Si hay ciudad y el defensor es destruido, comprobar captura
	if city != null and result.defender_destroyed and city.owner_id != attacker.owner_id:
		## Solo unidades terrestres pueden capturar ciudades
		if not attacker.is_naval():
			result.city_captured = true
	
	## Marcar atacante como que ha atacado
	attacker.attack_target()
	
	return result

## Resuelve un asedio a una ciudad (sin unidad defensora)
## Parámetros:
##   attacker: unidad atacante
##   city: ciudad bajo asedio
##   city_terrain: terreno de la ciudad
## Devuelve: CombatResult
static func resolve_siege(attacker: Units.Unit, city: Cities.City,
						  city_terrain: String = "pradera") -> CombatResult:
	var result := CombatResult.new()
	
	## Calcular fuerza de ataque
	var attack_force: int = _calculate_attack_force(attacker, city_terrain)
	
	## Calcular defensa de la ciudad
	var city_defense: int = city.get_defense()
	var terrain_bonus: int = TERRAIN_DEFENSE_BONUS.get(city_terrain, 0)
	var total_defense: int = city_defense + terrain_bonus
	
	## Calcular daño a la ciudad
	var damage_to_city: int = _calculate_damage(attack_force, total_defense)
	result.attacker_damage_dealt = damage_to_city
	
	## Las ciudades no pueden contraatacar sin unidades
	result.defender_damage_dealt = 0
	
	## Reducir defensa de la ciudad temporalmente
	city.siege_defense_bonus = maxi(0, city.siege_defense_bonus - 1)
	
	## Si la defensa llega a 0, la ciudad es capturada
	if city.get_defense() <= 0:
		result.city_captured = true
		result.defender_destroyed = true
		city.end_siege()
	else:
		## La ciudad entra/continúa en asedio
		city.start_siege()
	
	## Marcar atacante como que ha atacado
	attacker.attack_target()
	
	return result

## Realiza un ataque a distancia
## Los ataques a distancia no provocan contraataque
static func resolve_ranged_attack(attacker: Units.Unit, defender: Units.Unit,
								   defender_terrain: String = "pradera") -> CombatResult:
	var result := CombatResult.new()
	
	## Verificar que el atacante tiene rango
	if attacker.rango_ataque <= 1:
		push_error("Unidad sin capacidad de ataque a distancia intentó atacar a rango")
		return result
	
	## Calcular fuerza de ataque
	var attack_force: int = _calculate_attack_force(attacker, "pradera")  ## No aplica bono de terreno al atacante
	
	## Calcular defensa del defensor
	var defense_force: int = _calculate_defense_force(defender, defender_terrain)
	
	## Ataque a distancia: daño reducido
	var damage: int = maxi(1, _calculate_damage(attack_force, defense_force) / 2)
	
	result.attacker_damage_dealt = damage
	result.defender_destroyed = defender.take_damage(damage)
	
	## Sin contraataque a distancia
	result.defender_damage_dealt = 0
	
	## Experiencia
	if result.defender_destroyed:
		result.experience_gained = defender.max_health
	
	## Marcar atacante
	attacker.attack_target()
	
	return result

## Captura una ciudad (transfiere propiedad)
static func capture_city(city: Cities.City, new_owner_id: int, new_tribe_id: Tribes.TribeID):
	city.owner_id = new_owner_id
	city.tribe_id = new_tribe_id
	city.level = maxi(1, city.level - 1)  ## Penalización: baja 1 nivel
	city.under_siege = false
	city.siege_defense_bonus = 0
	city.population = maxi(1, city.population - 1)
	
	## Limpiar cola de entrenamiento
	city.training_queue.clear()
	city.currently_training = {}

## Calcula la fuerza de ataque de una unidad
static func _calculate_attack_force(unit: Units.Unit, terrain: String) -> int:
	var base_attack: int = unit.attack
	var terrain_bonus: int = TERRAIN_ATTACK_BONUS.get(terrain, 0)
	return base_attack + terrain_bonus

## Calcula la fuerza de defensa de una unidad
static func _calculate_defense_force(unit: Units.Unit, terrain: String, city: Cities.City = null) -> int:
	var base_defense: int = unit.defense
	var terrain_bonus: int = TERRAIN_DEFENSE_BONUS.get(terrain, 0)
	var total: int = base_defense + terrain_bonus
	
	## Bonus de ciudad
	if city != null:
		total += city.get_defense()
	
	return total

## Calcula el daño basado en fuerza atacante vs defensora
## Fórmula: max(1, ataque - defensa/2) + variación aleatoria pequeña
static func _calculate_damage(attack_force: int, defense_force: int) -> int:
	var base_damage: int = maxi(1, attack_force - defense_force / 2)
	## Variación aleatoria: ±1 (para añadir algo de impredecibilidad)
	## Nota: en Godot usar randi_range, pero aquí lo dejamos determinista
	## para que el caller pueda añadir RNG si quiere
	return base_damage

## Devuelve el bono de defensa de un terreno
static func get_terrain_defense_bonus(terrain: String) -> int:
	return TERRAIN_DEFENSE_BONUS.get(terrain, 0)

## Devuelve el bono de ataque de un terreno
static func get_terrain_attack_bonus(terrain: String) -> int:
	return TERRAIN_ATTACK_BONUS.get(terrain, 0)

## Comprueba si una posición está al alcance de ataque
## Parámetros:
##   from_pos: posición del atacante
##   to_pos: posición objetivo
##   range: rango de ataque
##   map_size: tamaño del mapa (para wrap-around)
static func is_in_attack_range(from_pos: Vector2i, to_pos: Vector2i, range: int, map_size: int) -> bool:
	var distance: int = _spherical_distance(from_pos, to_pos, map_size)
	return distance <= range

## Calcula distancia en mundo esférico (wrap-around)
## Considera 9 desplazamientos posibles del mapa
static func _spherical_distance(a: Vector2i, b: Vector2i, map_size: int) -> int:
	var min_dist: int = 999999
	
	## Desplazamientos del mundo esférico
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var offset: Vector2i = Vector2i(dx * map_size, dy * map_size)
			var dist: int = _hex_distance(a, b + offset)
			min_dist = mini(min_dist, dist)
	
	return min_dist

## Distancia hexagonal axial
static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return (absi(dq) + absi(dq + dr) + absi(dr)) / 2

## Curación de unidades en territorio propio
## Devuelve la cantidad curada
static func heal_in_friendly_territory(unit: Units.Unit, city: Cities.City = null) -> int:
	var heal_amount: int = 2  ## Curación base
	
	if city != null:
		## Curación aumentada cerca de ciudades
		heal_amount += city.level
	
	unit.heal(heal_amount)
	return heal_amount
