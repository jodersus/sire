class_name CameraController
extends Camera2D

## Control de cámara para SIRE.
## Soporta pan con click-drag, zoom con scroll, y límites suaves del mundo.

## Velocidad de pan (píxeles por segundo) cuando se arrastra.
@export var pan_speed: float = 1.0

## Factor de zoom por tick de rueda del ratón.
@export var zoom_step: float = 0.1

## Zoom mínimo y máximo.
@export var min_zoom: float = 0.3
@export var max_zoom: float = 3.0

## Límites suaves: la cámara puede salir un poco del mundo pero rebota.
@export var soft_limit_margin: float = 100.0

## Factor de suavizado para movimiento (0 = instantáneo, 1 = sin movimiento).
@export var smooth_factor: float = 0.15

## Referencia al sistema de hex grid para conocer el tamaño del mundo.
var hex_grid: Node

## Estado de arrastre.
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

## Posición objetivo (para suavizado).
var _target_position: Vector2 = Vector2.ZERO

## Límites del mundo en píxeles (se actualizan cuando se asigna hex_grid).
var _world_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1000, 1000))


func _ready():
	_target_position = position
	## Usamos límites suaves propios, no los de Godot.
	position_smoothing_enabled = false


func _process(delta: float):
	## Suavizar la posición hacia el objetivo.
	if position != _target_position:
		position = position.lerp(_target_position, smooth_factor)

	## Aplicar límites suaves (rebotar si nos pasamos mucho).
	_clamp_to_soft_limits()


func _unhandled_input(event: InputEvent):
	## Click-drag para pan.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_panning = mb.pressed
			if _is_panning:
				_last_mouse_pos = get_global_mouse_position()

		## Zoom con scroll.
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_cursor(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_cursor(-zoom_step)

	elif event is InputEventMouseMotion and _is_panning:
		var motion := event as InputEventMouseMotion
		var current_mouse := get_global_mouse_position()
		var delta_pos: Vector2 = _last_mouse_pos - current_mouse
		_target_position += delta_pos
		_last_mouse_pos = current_mouse

	## Pan alternativo con flechas (para teclado).
	if event is InputEventKey:
		var key := event as InputEventKey
		var pan_delta := Vector2.ZERO
		var keyboard_speed: float = 500.0 / zoom.x  ## Ajustar a zoom actual.
		if key.pressed:
			match key.keycode:
				KEY_UP:    pan_delta.y -= keyboard_speed
				KEY_DOWN:  pan_delta.y += keyboard_speed
				KEY_LEFT:  pan_delta.x -= keyboard_speed
				KEY_RIGHT: pan_delta.x += keyboard_speed
			_target_position += pan_delta


## Zoom centrado en la posición del cursor (o centro si no hay cursor).
func _zoom_at_cursor(delta_zoom: float):
	var old_zoom: float = zoom.x
	var new_zoom: float = clamp(old_zoom + delta_zoom, min_zoom, max_zoom)
	if new_zoom == old_zoom:
		return

	## Obtener posición del mouse en world space antes del zoom.
	var mouse_world := get_global_mouse_position()

	## Aplicar zoom.
	zoom = Vector2(new_zoom, new_zoom)

	## Calcular cuánto se movió el punto bajo el cursor y ajustar.
	var mouse_world_after := get_global_mouse_position()
	var adjustment := mouse_world - mouse_world_after
	_target_position += adjustment


## Limita la cámara a los bordes del mundo con margen suave.
func _clamp_to_soft_limits():
	if not hex_grid:
		return

	var viewport_size := get_viewport_rect().size / zoom
	var half_vp := viewport_size * 0.5

	## Rectángulo visible de la cámara.
	var visible_rect := Rect2(_target_position - half_vp, viewport_size)

	## Límites duros: el centro de la cámara no puede salir mucho del mundo.
	var hard_min := _world_rect.position - Vector2(soft_limit_margin, soft_limit_margin)
	var hard_max := _world_rect.end + Vector2(soft_limit_margin, soft_limit_margin)

	var center := _target_position
	center.x = clamp(center.x, hard_min.x + half_vp.x, hard_max.x - half_vp.x)
	center.y = clamp(center.y, hard_min.y + half_vp.y, hard_max.y - half_vp.y)

	_target_position = center


## Actualiza los límites del mundo basándose en el hex grid.
func update_world_limits(grid: Node):
	hex_grid = grid
	_world_rect = grid.get_world_rect()
	## Centrar la cámara al inicio.
	_target_position = _world_rect.get_center()
	position = _target_position


## Fuerza la posición de la cámara (útil para teletransporte wrap-around).
func set_camera_position(pos: Vector2):
	_target_position = pos
	position = pos


## Obtiene el hex bajo el cursor del ratón.
func get_hex_under_mouse() -> Vector2i:
	if not hex_grid:
		return Vector2i.ZERO
	return hex_grid.pixel_to_axialv(get_global_mouse_position())
