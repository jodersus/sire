extends Control
## Menú principal de SIRE
## Fondo animado con hexágonos flotantes

const BG_COLOR = Color("#0f172a")
const HEX_COLOR = Color("#1e293b")
const HEX_BORDER = Color("#FFD54F")
const HEX_COUNT = 24
const HEX_SIZE = 40.0

var hexagons: Array[Dictionary] = []
var rng = RandomNumberGenerator.new()

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var buttons_container: VBoxContainer = $VBoxContainer/ButtonsContainer

func _ready():
	rng.randomize()
	generate_hexagons()
	
	# Animación de entrada
	buttons_container.modulate.a = 0
	title_label.modulate.a = 0
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.8)

func generate_hexagons():
	var screen_size = get_viewport_rect().size
	for i in range(HEX_COUNT):
		var hex = {
			"position": Vector2(
				rng.randf_range(-HEX_SIZE, screen_size.x + HEX_SIZE),
				rng.randf_range(-HEX_SIZE, screen_size.y + HEX_SIZE)
			),
			"size": rng.randf_range(20, HEX_SIZE),
			"speed": rng.randf_range(5, 20),
			"angle": rng.randf_range(0, TAU),
			"rotation_speed": rng.randf_range(-0.5, 0.5),
			"opacity": rng.randf_range(0.05, 0.2),
			"border_width": rng.randf_range(0.5, 2.0)
		}
		hexagons.append(hex)

func _process(delta):
	var screen_size = get_viewport_rect().size
	for hex in hexagons:
		hex["position"].y += hex["speed"] * delta
		hex["angle"] += hex["rotation_speed"] * delta
		
		# Reset si sale por abajo
		if hex["position"].y > screen_size.y + HEX_SIZE * 2:
			hex["position"].y = -HEX_SIZE * 2
			hex["position"].x = rng.randf_range(-HEX_SIZE, screen_size.x + HEX_SIZE)
	
	queue_redraw()

func _draw():
	# Fondo
	draw_rect(get_viewport_rect(), BG_COLOR, true)
	
	# Hexágonos
	for hex in hexagons:
		var points = get_hex_points(hex["position"], hex["size"], hex["angle"])
		
		var fill_color = HEX_COLOR
		fill_color.a = hex["opacity"]
		draw_polygon(points, PackedColorArray([fill_color]))
		
		var border_color = HEX_BORDER
		border_color.a = hex["opacity"] * 1.5
		draw_polyline(points + PackedVector2Array([points[0]]), border_color, hex["border_width"], true)

func get_hex_points(center: Vector2, size: float, angle_offset: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle = angle_offset + i * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/setup_screen.tscn")

func _on_load_game_pressed():
	# TODO: Implementar carga de partida
	print("Cargar partida - no implementado")

func _on_options_pressed():
	# TODO: Implementar menú de opciones
	print("Opciones - no implementado")

func _on_quit_pressed():
	get_tree().quit()
