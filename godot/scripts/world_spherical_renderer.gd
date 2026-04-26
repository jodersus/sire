extends Node
class_name WorldSphericalRenderer

## Renderizado esférico wrap-around usando técnica de repetición 3x3.
## Duplica el TileMapLayer en 8 posiciones alrededor del mapa central
## para crear un efecto de mundo continuo. Las copias son puramente visuales;
## el input y la lógica de juego usan siempre el mapa central.

@export var tilemap: TileMapLayer
@export var hex_grid: HexGrid

var _copies: Array[TileMapLayer] = []
var _world_width: float = 0.0
var _world_height: float = 0.0

## Configura el renderer con el TileMapLayer original y el grid hexagonal.
func setup(p_tilemap: TileMapLayer, p_hex_grid: HexGrid) -> void:
	tilemap = p_tilemap
	hex_grid = p_hex_grid
	_create_copies()

func _create_copies() -> void:
	if tilemap == null or hex_grid == null:
		push_error("WorldSphericalRenderer: faltan referencias (tilemap o hex_grid)")
		return

	clear_copies()

	# Calcular dimensiones aproximadas del mundo en píxeles.
	# Flat-top hex: ancho = hex_size * sqrt(3), alto = hex_size * 2.
	# En la práctica usamos los valores del grid para mantener coherencia.
	var hex_w: float = hex_grid.hex_size * 1.73205  # sqrt(3)
	var hex_h: float = hex_grid.hex_size * 1.5
	_world_width = hex_grid.map_width * hex_w
	_world_height = hex_grid.map_height * hex_h

	# Crear 8 copias en grid 3x3 (excluyendo el centro 0,0)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue

			var copy: TileMapLayer = tilemap.duplicate()
			copy.name = "TileMapCopy_%d_%d" % [dx, dy]
			copy.position = Vector2(dx * _world_width, dy * _world_height)
			# Las copias son puramente visuales; el input se maneja en el mapa central
			add_child(copy)
			_copies.append(copy)

## Elimina todas las copias existentes.
func clear_copies() -> void:
	for copy in _copies:
		if is_instance_valid(copy) and not copy.is_queued_for_deletion():
			copy.queue_free()
	_copies.clear()

## Recrea las copias cuando el mapa original cambia (regeneración, etc.)
func sync_copies() -> void:
	_create_copies()
