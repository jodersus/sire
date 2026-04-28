extends Node2D
class_name GameScreen

## Pantalla principal del juego
## Delega la inicialización completa al GameManager autoload

@onready var hud = $HUD
@onready var game_over_screen = $GameOverScreen

func _ready():
	# Inicializar el juego a través del GameManager (autoload singleton)
	if GameManager != null:
		GameManager.initialize_game()
	else:
		push_error("GameManager no está disponible como autoload")

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			# El HUD maneja el menú de pausa
			hud._on_pause_pressed()
