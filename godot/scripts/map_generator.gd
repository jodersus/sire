class_name MapGenerator
extends Node

## Generador procedural de mapa para SIRE.
## Usa ruido (OpenSimplexNoise/FastNoiseLite) para generar terrenos y colocar recursos.
## El seed garantiza reproducibilidad.

enum Terrain {
	PRADERA,   ## 0 - Pasto verde, movimiento normal.
	BOSQUE,    ## 1 - Árboles, movimiento lento, produce madera.
	MONTANA,   ## 2 - Elevación, movimiento lento, produce piedra.
	AGUA,      ## 3 - Océano/lago, no transitable por tierra, produce pescado.
	DESIERTO,  ## 4 - Arena, movimiento normal.
	NIEVE,     ## 5 - Hielo, movimiento lento.
}

enum ResourceType {
	NONE,      ## 0 - Sin recurso.
	MADERA,    ## 1 - Del bosque.
	PIEDRA,    ## 2 - De la montaña.
	PESCADO,   ## 3 - Del agua.
	FRUTAS,    ## 4 - De praderas especiales.
}

## Seed para reproducibilidad.
@export var seed_value: int = 0:
	set(value):
		seed_value = value
		if _noise:
			_regenerate()

## Tamaño del mapa (debe coincidir con HexGrid).
@export var map_width: int = 20
@export var map_height: int = 20

## Escala del ruido (más bajo = terrenos más grandes).
@export var noise_scale: float = 0.08

## Umbral de agua: todo por debajo es agua.
@export var water_threshold: float = -0.25

## Umbral de montaña: todo por encima es montaña/nieve.
@export var mountain_threshold: float = 0.35

## Umbral de nieve: solo en latitudes altas (bordes verticales) o muy alta altitud.
@export var snow_threshold: float = 0.65

## Umbral de desierto: zonas intermedias-altas sin vegetación.
@export var desert_threshold: float = 0.15

## Frecuencia de recursos (0.0 - 1.0, probabilidad por hex).
@export var resource_density: float = 0.15

## Referencia al sistema de hex grid (se asigna desde fuera).
var hex_grid: Node

## Datos del mapa: terrain[q][r] = Terrain
var terrain_data: Dictionary = {}  ## Clave: Vector2i(q, r), Valor: Terrain

## Datos de recursos: resources[q][r] = ResourceType
var resource_data: Dictionary = {}  ## Clave: Vector2i(q, r), Valor: ResourceType

## Generador de ruido.
var _noise: FastNoiseLite

## RNG separado para colocación de recursos (independiente del ruido de terreno).
var _resource_rng: RandomNumberGenerator


func _ready():
	_setup_noise()
	_generate_map()


## Configura el generador de ruido con el seed actual.
func _setup_noise():
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_scale
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5

	_resource_rng = RandomNumberGenerator.new()
	_resource_rng.seed = seed_value + 12345  ## Offset para independencia.


## Regenera el ruido (llamar cuando cambia el seed).
func _regenerate():
	_setup_noise()
	_generate_map()


## Genera todo el mapa: terrenos y recursos.
func _generate_map():
	terrain_data.clear()
	resource_data.clear()

	for q in range(map_width):
		for r in range(map_height):
			var pos := Vector2i(q, r)
			var terrain := _sample_terrain(q, r)
			terrain_data[pos] = terrain

			var resource := _sample_resource(q, r, terrain)
			resource_data[pos] = resource

	print("Mapa generado: %dx%d, seed=%d" % [map_width, map_height, seed_value])


## Muestra el terreno en una coordenada usando ruido + gradiente de latitud.
func _sample_terrain(q: int, r: int) -> Terrain:
	## Normalizar coordenadas al rango del ruido.
	var nx: float = q * noise_scale
	var ny: float = r * noise_scale

	## Obtener valor de ruido en [-1, 1].
	var noise_val: float = _noise.get_noise_2d(nx, ny)

	## Gradiente de latitud: los bordes verticales son más fríos (nieve potencial).
	## Centro del mapa en r = map_height / 2.
	var lat: float = abs(r - map_height * 0.5) / (map_height * 0.5)
	var temp_mod: float = lat * 0.3  ## Hasta +0.3 en los bordes.

	var effective_val: float = noise_val + temp_mod

	## Determinar terreno por umbrales.
	if noise_val < water_threshold:
		return Terrain.AGUA
	elif effective_val > snow_threshold and lat > 0.6:
		return Terrain.NIEVE
	elif effective_val > mountain_threshold:
		return Terrain.MONTANA
	elif noise_val > desert_threshold and lat > 0.3 and lat < 0.7:
		return Terrain.DESIERTO
	elif noise_val > 0.0:
		return Terrain.BOSQUE
	else:
		return Terrain.PRADERA


## Muestra el recurso en una coordenada según el terreno.
func _sample_resource(q: int, r: int, terrain: Terrain) -> ResourceType:
	## No todos los hexes tienen recursos.
	if _resource_rng.randf() > resource_density:
		return ResourceType.NONE

	match terrain:
		Terrain.BOSQUE:
			return ResourceType.MADERA
		Terrain.MONTANA:
			return ResourceType.PIEDRA
		Terrain.AGUA:
			return ResourceType.PESCADO
		Terrain.PRADERA:
			## Praderas tienen frutas con menor probabilidad.
			if _resource_rng.randf() < 0.4:
				return ResourceType.FRUTAS
			return ResourceType.NONE
		_:
			return ResourceType.NONE


## --- API pública ---

## Obtiene el terreno en una coordenada (con wrap).
func get_terrain(q: int, r: int) -> Terrain:
	if hex_grid:
		var wrapped: Vector2i = hex_grid.wrap_axial(q, r)
		return terrain_data.get(wrapped, Terrain.PRADERA)
	return terrain_data.get(Vector2i(q, r), Terrain.PRADERA)


func get_terrainv(axial: Vector2i) -> Terrain:
	return get_terrain(axial.x, axial.y)


## Obtiene el recurso en una coordenada (con wrap).
func get_resource(q: int, r: int) -> ResourceType:
	if hex_grid:
		var wrapped: Vector2i = hex_grid.wrap_axial(q, r)
		return resource_data.get(wrapped, ResourceType.NONE)
	return resource_data.get(Vector2i(q, r), ResourceType.NONE)


func get_resourcev(axial: Vector2i) -> ResourceType:
	return get_resource(axial.x, axial.y)


## Devuelve el nombre del terreno.
static func terrain_name(t: Terrain) -> String:
	match t:
		Terrain.PRADERA:  return "Pradera"
		Terrain.BOSQUE:   return "Bosque"
		Terrain.MONTANA:  return "Montaña"
		Terrain.AGUA:     return "Agua"
		Terrain.DESIERTO: return "Desierto"
		Terrain.NIEVE:    return "Nieve"
		_:                return "Desconocido"


## Devuelve el nombre del recurso.
static func resource_name(r: ResourceType) -> String:
	match r:
		ResourceType.NONE:    return ""
		ResourceType.MADERA:  return "Madera"
		ResourceType.PIEDRA:  return "Piedra"
		ResourceType.PESCADO: return "Pescado"
		ResourceType.FRUTAS:  return "Frutas"
		_:                    return ""


## Regenera el mapa con un nuevo seed.
func regenerate(new_seed: int) -> void:
	seed_value = new_seed
	_setup_noise()
	_generate_map()
