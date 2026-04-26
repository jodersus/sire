extends Node
## Configuración global del juego
## Autoload singleton - añadir en Project -> AutoLoad

# Configuración de partida
var selected_tribe: String = "Solaris"
var bot_count: int = 2
var map_size_index: int = 1

# Estado de partida
var current_turn: int = 1
var current_phase: int = 0
var player_stars: int = 0
var player_population: int = 0

const PHASES = ["Ingreso", "Tecnología", "Movimiento", "Combate", "Construcción"]

func get_map_size() -> int:
	match map_size_index:
		0: return 11
		1: return 15
		2: return 19
		_: return 15
