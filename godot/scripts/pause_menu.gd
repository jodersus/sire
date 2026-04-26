extends Control
## Menú de pausa

func _ready():
	# Animación de entrada
	modulate.a = 0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_continue_pressed():
	get_tree().paused = false
	queue_free()

func _on_save_pressed():
	# TODO: Implementar guardado
	print("Guardar - no implementado")

func _on_options_pressed():
	# TODO: Implementar opciones
	print("Opciones - no implementado")

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
