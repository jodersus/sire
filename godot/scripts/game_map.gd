class_name GameMap
extends Node2D

## Escena principal del mapa de SIRE.
## Orquesta HexGrid, MapGenerator, y renderizado custom de hexágonos como Polygon2D.
## Renderiza el mapa procedural usando Polygon2D para alinear exactamente con HexGrid.

@onready var hex_grid: Node = $HexGrid
@onready var map_generator: Node = $MapGenerator
@onready var camera: Camera2D = $Camera2D
@onready var unit_renderer: UnitRenderer = $UnitRenderer
@onready var city_renderer: CityRenderer = $CityRenderer

## Layer para los hexágonos de terreno (Polygon2D nodes)
var _terrain_layer: Node2D

## Colores de terreno.
const TERRAIN_COLORS: Array[Color] = [
	Color("#7CB342"),  ## PRADERA
	Color("#33691E"),  ## BOSQUE
	Color("#5D4037"),  ## MONTANA
	Color("#1976D2"),  ## AGUA
	Color("#FBC02D"),  ## DESIERTO
	Color("#E0E0E0"),  ## NIEVE
]

func _ready():
	## Crear layer de terreno.
	_terrain_layer = Node2D.new()
	_terrain_layer.name = "TerrainLayer"
	_terrain_layer.z_index = 0
	add_child(_terrain_layer)
	
	## Conectar dependencias.
	map_generator.hex_grid = hex_grid
	unit_renderer.hex_grid = hex_grid
	city_renderer.hex_grid = hex_grid

	## Renderizar mapa.
	generate_map()

	## Configurar cámara.
	if camera.has_method("update_world_limits"):
		camera.update_world_limits(hex_grid)

	print("GameMap listo: %dx%d hexes" % [hex_grid.map_width, hex_grid.map_height])


## Renderiza todo el mapa como Polygon2D nodes.
func generate_map():
	_render_map()


func _render_map():
	## Limpiar layer anterior.
	for child in _terrain_layer.get_children():
		child.queue_free()

	for q in range(hex_grid.map_width):
		for r in range(hex_grid.map_height):
			var terrain: int = map_generator.get_terrain(q, r)
			var hex_coord := Vector2i(q, r)
			var pixel_pos: Vector2 = hex_grid.axial_to_pixelv(hex_coord)
			
			## Crear Polygon2D para este hex.
			var poly := Polygon2D.new()
			poly.polygon = _make_hex_polygon(pixel_pos, hex_grid.hex_size * 0.98)
			poly.color = TERRAIN_COLORS[terrain]
			
			## Borde sutil para definir la forma.
			var border := Line2D.new()
			border.points = poly.polygon
			border.closed = true
			border.width = 1.0
			border.default_color = Color("#00000040")
			poly.add_child(border)
			
			_terrain_layer.add_child(poly)


func _make_hex_polygon(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	## Flat-top hexagon.
	for i in range(6):
		var angle := i * PI / 3.0 - PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points


## Regenera el mapa con un nuevo seed.
func regenerate(new_seed: int) -> void:
	map_generator.regenerate(new_seed)
	generate_map()
