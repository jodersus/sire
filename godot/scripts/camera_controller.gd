class_name CameraController
extends Camera2D

## Control de cámara para SIRE.
## Pan con click-drag (polling en _process para evitar conflicto con clicks de selección).
## Zoom con scroll (eventos). Flechas para pan con teclado.

## Factor de zoom por tick de rueda del ratón.
@export var zoom_step: float = 0.1

## Zoom mínimo y máximo.
@export var min_zoom: float = 0.3
@export var max_zoom: float = 3.0

## Velocidad de pan con teclado (píxeles/segundo).
@export var keyboard_pan_speed: float = 600.0

## Factor de suavizado para movimiento (0 = instantáneo, 1 = sin movimiento).
@export var smooth_factor: float = 0.15

## Referencia al sistema de hex grid para conocer el tamaño del mundo.
var hex_grid: Node

## Estado de arrastre (polling del botón del mouse).
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

## Posición objetivo (para suavizado).
var _target_position: Vector2 = Vector2.ZERO

## Límites del mundo en píxeles (se actualizan cuando se asigna hex_grid).
var _world_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1000, 1000))


func _ready():
	_target_position = position
	position_smoothing_enabled = false


func _process(delta: float):
	## --- Pan con click-drag (polling, no eventos) ---
	var mouse_left_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	if mouse_left_pressed and not _is_panning:
		## Iniciar pan.
		_is_panning = true
		_last_mouse_pos = get_global_mouse_position()
	elif not mouse_left_pressed and _is_panning:
		## Terminar pan.
		_is_panning = false
	
	if _is_panning:
		var current_mouse := get_global_mouse_position()
		var delta_pos: Vector2 = _last_mouse_pos - current_mouse
		if delta_pos.length_squared() > 0.01:
			_target_position += delta_pos
			_last_mouse_pos = current_mouse
	
	## --- Pan con flechas (polling) ---
	var keyboard_delta := Vector2.ZERO
	var speed := keyboard_pan_speed / zoom.x * delta
	if Input.is_key_pressed(KEY_UP):    keyboard_delta.y -= speed
	if Input.is_key_pressed(KEY_DOWN):  keyboard_delta.y += speed
	if Input.is_key_pressed(KEY_LEFT):  keyboard_delta.x -= speed
	if Input.is_key_pressed(KEY_RIGHT): keyboard_delta.x += speed
	if keyboard_delta.length_squared() > 0.01:
		_target_position += keyboard_delta
	
	## Suavizar la posición hacia el objetivo.
	if position != _target_position:
		position = position.lerp(_target_position, smooth_factor)


func _unhandled_input(event: InputEvent):
	## Solo zoom con scroll (no entra en conflicto con clicks).
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_cursor(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_cursor(-zoom_step)


## Zoom centrado en la posición del cursor.
func _zoom_at_cursor(delta_zoom: float):
	var old_zoom: float = zoom.x
	var new_zoom: float = clampf(old_zoom + delta_zoom, min_zoom, max_zoom)
	if new_zoom == old_zoom:
		return

	var mouse_world := get_global_mouse_position()
	zoom = Vector2(new_zoom, new_zoom)
	var mouse_world_after := get_global_mouse_position()
	var adjustment := mouse_world - mouse_world_after
	_target_position += adjustment


## Actualiza los límites del mundo basándose en el hex grid.
func update_world_limits(grid: Node):
	hex_grid = grid
	_world_rect = grid.get_world_rect()
	limit_left = int(_world_rect.position.x)
	limit_top = int(_world_rect.position.y)
	limit_right = int(_world_rect.end.x)
	limit_bottom = int(_world_rect.end.y)
	limit_smoothed = false
	## Centrar la cámara al inicio.
	_target_position = _world_rect.get_center()
	position = _target_position


## Fuerza la posición de la cámara.
func set_camera_position(pos: Vector2):
	_target_position = pos
	position = pos


## Obtiene el hex bajo el cursor del ratón.
func get_hex_under_mouse() -> Vector2i:
	if not hex_grid:
		return Vector2i.ZERO
	return hex_grid.pixel_to_axialv(get_global_mouse_position())
