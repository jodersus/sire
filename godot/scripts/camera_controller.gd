class_name CameraController
extends Camera2D

## Control de cámara para SIRE (Web-compatible).
## Pan con click-drag usando screen-space mouse tracking.
## Zoom con scroll.
## Flechas para pan con teclado.

@export var zoom_step: float = 0.12
@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0
@export var keyboard_pan_speed: float = 500.0
@export var smooth_factor: float = 0.15

var hex_grid: Node

var _target_position: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_screen: Vector2 = Vector2.ZERO
var _camera_start_pos: Vector2 = Vector2.ZERO

func _ready():
	_target_position = position
	position_smoothing_enabled = false
	## Prevenir que el navegador consuma input del juego.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function() {
				var canvas = document.getElementById('canvas');
				if (canvas) {
					canvas.addEventListener('contextmenu', function(e) { e.preventDefault(); }, false);
					canvas.addEventListener('click', function() { canvas.focus(); });
					canvas.style.touchAction = 'none';
					canvas.focus();
				}
				window.addEventListener('keydown', function(e) {
					if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight',' '].includes(e.key)) {
						e.preventDefault();
					}
				}, false);
				window.addEventListener('wheel', function(e) {
					if (e.target.id === 'canvas') {
						e.preventDefault();
					}
				}, { passive: false });
			})();
		""")

func _process(delta):
	var screen_mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var mouse_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	## --- Pan con click-drag ---
	if mouse_pressed and not _is_dragging:
		_is_dragging = true
		_drag_start_screen = screen_mouse_pos
		_camera_start_pos = _target_position
	elif not mouse_pressed and _is_dragging:
		_is_dragging = false

	if _is_dragging:
		var delta_screen: Vector2 = screen_mouse_pos - _drag_start_screen
		var delta_world: Vector2 = delta_screen / zoom
		_target_position = _camera_start_pos - delta_world

	## --- Pan con flechas ---
	var key_delta := Vector2.ZERO
	var speed: float = keyboard_pan_speed / zoom.x * delta
	if Input.is_key_pressed(KEY_UP):    key_delta.y -= speed
	if Input.is_key_pressed(KEY_DOWN):  key_delta.y += speed
	if Input.is_key_pressed(KEY_LEFT):  key_delta.x -= speed
	if Input.is_key_pressed(KEY_RIGHT): key_delta.x += speed
	if key_delta.length_squared() > 0.01:
		_target_position += key_delta

	## Suavizado.
	if position != _target_position:
		position = position.lerp(_target_position, smooth_factor)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_cursor(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_cursor(-zoom_step)

func _zoom_at_cursor(delta_zoom: float):
	var old_zoom: float = zoom.x
	var new_zoom: float = clampf(old_zoom + delta_zoom, min_zoom, max_zoom)
	if new_zoom == old_zoom:
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	zoom = Vector2(new_zoom, new_zoom)
	var mouse_world_after: Vector2 = get_global_mouse_position()
	var adjustment: Vector2 = mouse_world - mouse_world_after
	_target_position += adjustment

func update_world_limits(grid: Node):
	hex_grid = grid
	var rect: Rect2 = grid.get_world_rect()
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
	limit_smoothed = false
	_target_position = rect.get_center()
	position = _target_position

func set_camera_position(pos: Vector2):
	_target_position = pos
	position = pos

func get_hex_under_mouse() -> Vector2i:
	if not hex_grid:
		return Vector2i.ZERO
	return hex_grid.pixel_to_axialv(get_global_mouse_position())
