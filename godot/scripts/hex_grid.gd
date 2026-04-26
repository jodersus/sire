class_name HexGrid
extends Node

## Sistema de hex grid con coordenadas axiales (q, r).
## Soporta conversión axial <-> pixel, vecinos, distancia y wrap-around esférico.

## Tamaño del hexágono (radio del círculo circunscrito, en píxeles).
@export var hex_size: float = 32.0

## Tamaño del mapa en coordenadas axiales.
@export var map_width: int = 20
@export var map_height: int = 20

## 6 direcciones vecinales para hexágonos flat-top en coordenadas axiales.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),   # Este
	Vector2i(1, -1),  # Noreste
	Vector2i(0, -1),  # Noroeste
	Vector2i(-1, 0),  # Oeste
	Vector2i(-1, 1),  # Suroeste
	Vector2i(0, 1),   # Sureste
]

## Ancho y alto de un hexágono flat-top en píxeles.
var hex_width: float
var hex_height: float


func _ready():
	_recalculate_dimensions()


func _recalculate_dimensions():
	## Flat-top hex: ancho = 2 * size, alto = sqrt(3) * size.
	hex_width = 2.0 * hex_size
	hex_height = sqrt(3.0) * hex_size


## Convierte coordenadas axiales (q, r) a posición en píxeles (world space).
func axial_to_pixel(q: int, r: int) -> Vector2:
	var x: float = hex_size * 1.5 * q
	var y: float = hex_size * sqrt(3.0) * (r + q * 0.5)
	return Vector2(x, y)


func axial_to_pixelv(axial: Vector2i) -> Vector2:
	return axial_to_pixel(axial.x, axial.y)


## Convierte posición en píxeles (world space) a coordenadas axiales (q, r).
func pixel_to_axial(px: float, py: float) -> Vector2i:
	var q: float = (2.0 / 3.0) * px / hex_size
	var r: float = (-1.0 / 3.0) * px / hex_size + (sqrt(3.0) / 3.0) * py / hex_size
	return _axial_round(q, r)


func pixel_to_axialv(pixel: Vector2) -> Vector2i:
	return pixel_to_axial(pixel.x, pixel.y)


## Redondea coordenadas axiales fraccionarias al hex más cercano.
func _axial_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: float = round(q)
	var rr: float = round(r)
	var rs: float = round(s)

	var dq: float = abs(rq - q)
	var dr: float = abs(rr - r)
	var ds: float = abs(rs - s)

	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs

	return Vector2i(int(rq), int(rr))


## Devuelve las 6 coordenadas vecinas de un hex dado (sin wrap).
func get_neighbors(q: int, r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for n in NEIGHBORS:
		result.append(Vector2i(q + n.x, r + n.y))
	return result


func get_neighborsv(axial: Vector2i) -> Array[Vector2i]:
	return get_neighbors(axial.x, axial.y)


## Aplica wrap-around esférico a una coordenada axial.
## Si te sales por un borde, apareces por el opuesto.
func wrap_axial(q: int, r: int) -> Vector2i:
	var wq := q % map_width
	var wr := r % map_height
	if wq < 0:
		wq += map_width
	if wr < 0:
		wr += map_height
	return Vector2i(wq, wr)


func wrap_axialv(axial: Vector2i) -> Vector2i:
	return wrap_axial(axial.x, axial.y)


## Distancia entre dos hexágonos en coordenadas axiales (sin wrap).
func distance(q1: int, r1: int, q2: int, r2: int) -> int:
	return (abs(q1 - q2) + abs(q1 + r1 - q2 - r2) + abs(r1 - r2)) / 2


func distancev(a: Vector2i, b: Vector2i) -> int:
	return distance(a.x, a.y, b.x, b.y)


## Distancia mínima considerando wrap-around esférico (9 desplazamientos posibles).
## El mapa se repite en una cuadrícula 3x3; calculamos la distancia al vecino más cercano.
func distance_wrapped(q1: int, r1: int, q2: int, r2: int) -> int:
	var min_dist := distance(q1, r1, q2, r2)

	for dq in [-1, 0, 1]:
		for dr in [-1, 0, 1]:
			if dq == 0 and dr == 0:
				continue
			var shifted_q: int = q2 + dq * map_width
			var shifted_r: int = r2 + dr * map_height
			var d := distance(q1, r1, shifted_q, shifted_r)
			if d < min_dist:
				min_dist = d

	return min_dist


func distance_wrappedv(a: Vector2i, b: Vector2i) -> int:
	return distance_wrapped(a.x, a.y, b.x, b.y)


## Devuelve todos los hexágonos dentro de un radio dado desde un centro (con wrap).
func get_hexes_in_range(center_q: int, center_r: int, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			result.append(wrap_axial(center_q + q, center_r + r))
	return result


func get_hexes_in_rangev(center: Vector2i, radius: int) -> Array[Vector2i]:
	return get_hexes_in_range(center.x, center.y, radius)


## Devuelve el ancho total del mundo en píxeles.
func world_width() -> float:
	return hex_width + (map_width - 1) * hex_size * 1.5


## Devuelve el alto total del mundo en píxeles.
func world_height() -> float:
	## El alto depende del offset vertical máximo.
	var max_row_offset := (map_height - 1) * hex_height
	var odd_col_offset := (map_width - 1) * hex_height * 0.5
	return max_row_offset + odd_col_offset + hex_height


## Devuelve el rectángulo que contiene todo el mundo en píxeles.
func get_world_rect() -> Rect2:
	var size := Vector2(world_width(), world_height())
	return Rect2(Vector2.ZERO, size)
