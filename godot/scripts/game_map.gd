class_name GameMap
extends Node2D

## Escena principal del mapa de SIRE.
## Orquesta HexGrid, MapGenerator, TileMapLayer y Camera2D.
## Renderiza el mapa procedural y gestiona el wrap-around visual de la cámara.

@onready var hex_grid: Node = $HexGrid
@onready var map_generator: Node = $MapGenerator
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D

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

	## Generar atlas procedural y configurar TileSet.
	_setup_tileset()

	## Renderizar mapa.
	_render_map()

	## Configurar cámara.
	if camera.has_method("update_world_limits"):
		camera.update_world_limits(hex_grid)

	print("GameMap listo: %dx%d hexes" % [hex_grid.map_width, hex_grid.map_height])


## Genera una imagen procedural con 6 tiles coloreados para usar como atlas.
func _setup_tileset():
	var img := Image.create_empty(ATLAS_TILE_WIDTH * TERRAIN_COLORS.size(), ATLAS_TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	for i in range(TERRAIN_COLORS.size()):
		var rect := Rect2i(i * ATLAS_TILE_WIDTH, 0, ATLAS_TILE_WIDTH, ATLAS_TILE_HEIGHT)
		img.fill_rect(rect, TERRAIN_COLORS[i])

	_atlas_texture = ImageTexture.create_from_image(img)

	## Crear TileSet con atlas source.
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	ts.tile_size = Vector2i(ATLAS_TILE_WIDTH, ATLAS_TILE_HEIGHT)

	var source := TileSetAtlasSource.new()
	source.texture = _atlas_texture
	source.texture_region_size = Vector2i(ATLAS_TILE_WIDTH, ATLAS_TILE_HEIGHT)

	## Registrar cada terreno como un tile en el atlas.
	for i in range(TERRAIN_COLORS.size()):
		source.create_tile(Vector2i(i, 0))

	var source_id := ts.add_source(source)

	## Asignar terrenos para pintura automática (opcional, pero útil).
	## Nota: en Godot 4.4, la gestión de terrenos es más sencilla con atlas.
	## Dejamos que el atlas defina los tiles visualmente.
	pass

	tilemap.tile_set = ts


## Renderiza todo el mapa en el TileMapLayer.
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


## Proceso principal: wrap-around visual de la cámara.
## Cuando la cámara cruza los límites del mundo, se teletransporta al lado opuesto.
## Esto crea el efecto de mundo esférico continuo.
func _process(_delta: float):
	if not camera or not hex_grid:
		return

	var world_rect: Rect2 = hex_grid.get_world_rect()
	var cam_pos := camera.position
	var teleported := false

	## Wrap horizontal.
	if cam_pos.x > world_rect.end.x + hex_grid.hex_width:
		cam_pos.x -= world_rect.size.x
		teleported = true
	elif cam_pos.x < world_rect.position.x - hex_grid.hex_width:
		cam_pos.x += world_rect.size.x
		teleported = true

	## Wrap vertical.
	if cam_pos.y > world_rect.end.y + hex_grid.hex_height:
		cam_pos.y -= world_rect.size.y
		teleported = true
	elif cam_pos.y < world_rect.position.y - hex_grid.hex_height:
		cam_pos.y += world_rect.size.y
		teleported = true

	if teleported:
		if camera.has_method("set_camera_position"):
			camera.set_camera_position(cam_pos)
		else:
			camera.position = cam_pos


## Regenera el mapa con un nuevo seed.
func regenerate(new_seed: int) -> void:
	map_generator.regenerate(new_seed)
	_render_map()
