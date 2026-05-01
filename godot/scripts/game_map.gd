class_name GameMap
extends Node2D

## Escena principal del mapa de SIRE.
## Orquesta HexGrid, MapGenerator, TileMapLayer y Camera2D.
## Renderiza el mapa procedural y gestiona el wrap-around visual de la cámara.

@onready var hex_grid: Node = $HexGrid
@onready var map_generator: Node = $MapGenerator
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var unit_renderer: UnitRenderer = $UnitRenderer
@onready var city_renderer: CityRenderer = $CityRenderer

## Atlas procedural: 6 tiles de 64x56 en una fila.
var _atlas_texture: ImageTexture

## Colores de terreno (coinciden con DESIGN.md).
const TERRAIN_COLORS: Array[Color] = [
	Color("#7CB342"),  ## PRADERA
	Color("#33691E"),  ## BOSQUE
	Color("#5D4037"),  ## MONTANA
	Color("#1976D2"),  ## AGUA
	Color("#FBC02D"),  ## DESIERTO
	Color("#E0E0E0"),  ## NIEVE
]

## Tamaño de cada tile en el atlas.
const ATLAS_TILE_WIDTH := 64
const ATLAS_TILE_HEIGHT := 56

func _ready():
	## Conectar dependencias.
	map_generator.hex_grid = hex_grid
	unit_renderer.hex_grid = hex_grid
	city_renderer.hex_grid = hex_grid

	## Generar atlas procedural y configurar TileSet.
	_setup_tileset()

	## Renderizar mapa.
	generate_map()

	## Configurar cámara.
	if camera.has_method("update_world_limits"):
		camera.update_world_limits(hex_grid)

	print("GameMap listo: %dx%d hexes" % [hex_grid.map_width, hex_grid.map_height])


## Genera un TileSet usando la textura atlas pre-generada.
## La textura terrain_atlas.png contiene 6 tiles hexagonales de 64x56.
func _setup_tileset():
	# Cargar atlas pre-generado
	var atlas_path := "res://assets/tiles/terrain_atlas.png"
	var atlas_texture: Texture2D = null
	
	if ResourceLoader.exists(atlas_path):
		atlas_texture = load(atlas_path) as Texture2D
		print("GameMap: Atlas cargado desde ", atlas_path)
	else:
		push_error("GameMap: No se encontró terrain_atlas.png. Usando fallback procedural.")
		atlas_texture = _generate_fallback_atlas()

	# Crear TileSet con atlas source.
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	ts.tile_size = Vector2i(ATLAS_TILE_WIDTH, ATLAS_TILE_HEIGHT)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture
	source.texture_region_size = Vector2i(ATLAS_TILE_WIDTH, ATLAS_TILE_HEIGHT)

	# Registrar cada terreno como un tile en el atlas.
	for i in range(TERRAIN_COLORS.size()):
		source.create_tile(Vector2i(i, 0))

	var source_id := ts.add_source(source)
	tilemap.tile_set = ts


## Fallback: genera atlas procedural si el PNG no está disponible.
func _generate_fallback_atlas() -> ImageTexture:
	var img := Image.create_empty(ATLAS_TILE_WIDTH * TERRAIN_COLORS.size(), ATLAS_TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var center_x: float = ATLAS_TILE_WIDTH * 0.5
	var center_y: float = ATLAS_TILE_HEIGHT * 0.5
	var hex_r: float = ATLAS_TILE_HEIGHT * 0.45

	for i in range(TERRAIN_COLORS.size()):
		var tile_offset: int = i * ATLAS_TILE_WIDTH
		var points: Array[Vector2] = []
		for p in range(6):
			var angle: float = p * PI / 3.0 - PI / 6.0
			points.append(Vector2(
				center_x + tile_offset + cos(angle) * hex_r,
				center_y + sin(angle) * hex_r
			))

		# Dibujar relleno hexagonal píxel a píxel (point-in-polygon)
		var min_x := maxi(0, int(tile_offset))
		var max_x := mini(img.get_width() - 1, int(tile_offset + ATLAS_TILE_WIDTH - 1))
		var min_y := 0
		var max_y := img.get_height() - 1

		for px in range(min_x, max_x + 1):
			for py in range(min_y, max_y + 1):
				if _point_in_polygon(Vector2(px + 0.5, py + 0.5), points):
					var col := TERRAIN_COLORS[i]
					# Borde oscuro en los bordes del hexágono para definir forma
					var dist_to_edge := _distance_to_polygon_edge(Vector2(px + 0.5, py + 0.5), points)
					if dist_to_edge < 2.0:
						col = col.darkened(0.3)
					img.set_pixel(px, py, col)

	return ImageTexture.create_from_image(img)


func _point_in_polygon(pt: Vector2, poly: Array[Vector2]) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var vi := poly[i]
		var vj := poly[j]
		if ((vi.y > pt.y) != (vj.y > pt.y)) and (pt.x < (vj.x - vi.x) * (pt.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = not inside
		j = i
	return inside


func _distance_to_polygon_edge(pt: Vector2, poly: Array[Vector2]) -> float:
	var min_dist := 99999.0
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var dist := _distance_to_segment(pt, a, b)
		if dist < min_dist:
			min_dist = dist
	return min_dist


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var t := clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	var closest := a + ab * t
	return p.distance_to(closest)


## Renderiza todo el mapa en el TileMapLayer.
func generate_map():
	_render_map()


func _render_map():
	tilemap.clear()

	var used_cells: Array[Vector2i] = []
	var used_altas: Array[Vector2i] = []

	for q in range(hex_grid.map_width):
		for r in range(hex_grid.map_height):
			var terrain: int = map_generator.get_terrain(q, r)
			var atlas_coord := Vector2i(int(terrain), 0)
			var cell := Vector2i(q, r)
			used_cells.append(cell)
			used_altas.append(atlas_coord)

	## En Godot 4.4, TileMapLayer usa set_cells_terrain_connect o set_cell.
	## Usamos un bucle simple con set_cell para máxima compatibilidad.
	for i in range(used_cells.size()):
		tilemap.set_cell(used_cells[i], 0, used_altas[i])


## Regenera el mapa con un nuevo seed.
func regenerate(new_seed: int) -> void:
	map_generator.regenerate(new_seed)
	generate_map()
