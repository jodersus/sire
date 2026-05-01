class_name UnitRenderer
extends Node2D

## Renderiza unidades en el mapa hexagonal.
## Cada unidad se muestra como un Sprite2D con su SVG correspondiente,
## coloreado según la tribu del propietario.

## Diccionario de rutas de sprites SVG por tipo de unidad
const UNIT_SPRITES_SVG: Dictionary = {
	Units.UnitType.EXPLORADOR: "res://assets/sprites/unit_explorer.svg",
	Units.UnitType.GUERRERO: "res://assets/sprites/unit_warrior.svg",
	Units.UnitType.ARQUERO: "res://assets/sprites/unit_archer.svg",
	Units.UnitType.JINETE: "res://assets/sprites/unit_rider.svg",
	Units.UnitType.CABALLERO: "res://assets/sprites/unit_knight.svg",
	Units.UnitType.BARCO: "res://assets/sprites/unit_boat.svg",
	Units.UnitType.BUQUE_GUERRA: "res://assets/sprites/unit_warship.svg",
	Units.UnitType.CATAPULTA: "res://assets/sprites/unit_catapult.svg",
	Units.UnitType.GIGANTE: "res://assets/sprites/unit_giant.svg",
}

## Diccionario de rutas de sprites PNG (fallback para web export)
const UNIT_SPRITES_PNG: Dictionary = {
	Units.UnitType.EXPLORADOR: "res://assets/sprites/unit_explorer_png.png",
	Units.UnitType.GUERRERO: "res://assets/sprites/unit_warrior_png.png",
	Units.UnitType.ARQUERO: "res://assets/sprites/unit_archer_png.png",
	Units.UnitType.JINETE: "res://assets/sprites/unit_rider_png.png",
	Units.UnitType.CABALLERO: "res://assets/sprites/unit_knight_png.png",
	Units.UnitType.BARCO: "res://assets/sprites/unit_boat_png.png",
	Units.UnitType.BUQUE_GUERRA: "res://assets/sprites/unit_warship_png.png",
	Units.UnitType.CATAPULTA: "res://assets/sprites/unit_catapult_png.png",
	Units.UnitType.GIGANTE: "res://assets/sprites/unit_giant_png.png",
}

const UNIT_SCALE := Vector2(0.6, 0.6)
const Z_INDEX_UNITS := 10

## Referencia al hex grid para conversiones coordenadas
var hex_grid: HexGrid

## Mapa: unit_id -> Sprite2D
var _unit_sprites: Dictionary = {}

## Crea el sprite visual para una unidad
func spawn_unit(unit: Units.Unit) -> void:
	var unit_id := _make_unit_id(unit)
	if _unit_sprites.has(unit_id):
		return  # Ya existe

	var sprite := Sprite2D.new()
	sprite.name = "Unit_%s" % unit_id
	sprite.scale = UNIT_SCALE
	sprite.z_index = Z_INDEX_UNITS

	# Cargar textura: intentar SVG primero, luego PNG fallback
	var tex: Texture2D = null
	var svg_path: String = UNIT_SPRITES_SVG.get(unit.type, "")
	var png_path: String = UNIT_SPRITES_PNG.get(unit.type, "")
	
	# Intentar SVG
	if not svg_path.is_empty() and ResourceLoader.exists(svg_path):
		tex = load(svg_path) as Texture2D
	
	# Fallback a PNG
	if tex == null and not png_path.is_empty() and ResourceLoader.exists(png_path):
		tex = load(png_path) as Texture2D
		print("UnitRenderer: Usando PNG fallback para unidad tipo %d" % unit.type)
	
	if tex != null:
		sprite.texture = tex
	else:
		push_warning("UnitRenderer: No se pudo cargar textura para tipo %d" % unit.type)

	# Colorear según tribu
	var tribe_color: Color = Tribes.get_tribe_color(unit.tribe_id)
	sprite.modulate = tribe_color

	# Posicionar en el mapa
	_update_sprite_position(sprite, unit.position)

	add_child(sprite)
	_unit_sprites[unit_id] = sprite

## Actualiza la posición visual de una unidad (después de movimiento)
func move_unit(unit: Units.Unit) -> void:
	var unit_id := _make_unit_id(unit)
	var sprite := _unit_sprites.get(unit_id) as Sprite2D
	if sprite == null:
		spawn_unit(unit)
		return
	_update_sprite_position(sprite, unit.position)

## Elimina el sprite de una unidad destruida
func remove_unit(unit: Units.Unit) -> void:
	var unit_id := _make_unit_id(unit)
	var sprite := _unit_sprites.get(unit_id) as Sprite2D
	if sprite != null:
		sprite.queue_free()
		_unit_sprites.erase(unit_id)

## Actualiza el color/visual de una unidad (por ejemplo, si cambia de propietario)
func update_unit(unit: Units.Unit) -> void:
	var unit_id := _make_unit_id(unit)
	var sprite := _unit_sprites.get(unit_id) as Sprite2D
	if sprite == null:
		return
	var tribe_color: Color = Tribes.get_tribe_color(unit.tribe_id)
	sprite.modulate = tribe_color
	_update_sprite_position(sprite, unit.position)

## Limpia todas las unidades visuales
func clear_all() -> void:
	for sprite in _unit_sprites.values():
		if is_instance_valid(sprite):
			sprite.queue_free()
	_unit_sprites.clear()

## Reposiciona todos los sprites según las unidades actuales
func sync_from_players(players: Array[TurnManager.Player]) -> void:
	clear_all()
	for player in players:
		for unit in player.units:
			if unit.is_alive():
				spawn_unit(unit)

func _make_unit_id(unit: Units.Unit) -> String:
	return "%d_%d_%d_%d" % [unit.owner_id, unit.type, unit.position.x, unit.position.y]

func _update_sprite_position(sprite: Sprite2D, pos: Vector2i) -> void:
	if hex_grid == null:
		return
	var pixel_pos: Vector2 = hex_grid.axial_to_pixelv(pos)
	sprite.position = pixel_pos
