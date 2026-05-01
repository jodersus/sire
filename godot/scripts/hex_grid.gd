class_name HexGrid
extends Node

## Sistema de hex grid con coordenadas en layout offset odd-q (columnas escalonadas).
## Las coordenadas internas (q, r) representan (columna, fila) en un grid rectangular.
## Soporta conversión offset <-> pixel, vecinos, distancia y wrap-around esférico.
## Referencia: redblobgames.com/grids/hexagons/#offset-conversions

## Tamaño del hexágono (radio del círculo circunscrito, en píxeles).
@export var hex_size: float = 32.0

## Tamaño del mapa en celdas (columnas, filas).
@export var map_width: int = 20
@export var map_height: int = 20

## 6 direcciones vecinales para hexágonos pointy-top con odd-q offset.
## Índice 0 = par, 1 = impar (q % 2)
const NEIGHBORS: Array = [
	[ # columnas PARES (q % 2 == 0)
		Vector2i(1, -1),  # NE
		Vector2i(1,  0),  # E
		Vector2i(0,  1),  # SE
		Vector2i(-1,  0), # W
		Vector2i(-1, -1), # NW
		Vector2i(0, -1),  # N
	],
	[ # columnas IMPARES (q % 2 == 1)
		Vector2i(1,  0),  # NE
		Vector2i(1,  1),  # E
		Vector2i(0,  1),  # SE
		Vector2i(-1,  1), # W
		Vector2i(-1,  0), # NW
		Vector2i(0, -1),  # N
	]
]

## Ancho y alto de un hexágono pointy-top en píxeles.
var hex_width: float
var hex_height: float

## Espaciado entre centros adyacentes.
var hex_h_spacing: float
var hex_v_spacing: float


func _ready():
	_recalculate_dimensions()


func _recalculate_dimensions():
	## Pointy-top hex: ancho = sqrt(3) * size, alto = 2 * size.
	## Spacing horizontal = sqrt(3) * size, spacing vertical = 1.5 * size.
	hex_width = sqrt(3.0) * hex_size
	hex_height = 2.0 * hex_size
	hex_h_spacing = hex_width
	hex_v_spacing = hex_size * 1.5


# ---------------------------------------------------------------------------
# OFFSET <-> PIXEL (renderizado e input)
# ---------------------------------------------------------------------------

## Convierte coordenadas offset (q=columna, r=fila) a posición en píxeles (world space).
## Usa layout odd-q para hexágonos pointy-top.
func axial_to_pixel(q: int, r: int) -> Vector2:
	var x: float = hex_h_spacing * q
	var y: float = hex_v_spacing * (r + 0.5 * float(q & 1))
	return Vector2(x, y)


func axial_to_pixelv(axial: Vector2i) -> Vector2:
	return axial_to_pixel(axial.x, axial.y)


## Convierte posición en píxeles (world space) a coordenadas offset (q, r).
func pixel_to_axial(px: float, py: float) -> Vector2i:
	var q: float = round(px / hex_h_spacing)
	var r: float = round(py / hex_v_spacing - 0.5 * float(int(q) & 1))
	return Vector2i(int(q), int(r))


func pixel_to_axialv(pixel: Vector2) -> Vector2i:
	return pixel_to_axial(pixel.x, pixel.y)


# ---------------------------------------------------------------------------
# OFFSET <-> AXIAL (cálculos de distancia)
# ---------------------------------------------------------------------------

## Convierte offset (q, r) a axial para cálculos de distancia y rango.
func offset_to_axial(q: int, r: int) -> Vector2i:
	var aq: int = q
	var ar: int = r - (q >> 1)  # floor(q / 2) usando shift para enteros
	return Vector2i(aq, ar)


func offset_to_axialv(offset: Vector2i) -> Vector2i:
	return offset_to_axial(offset.x, offset.y)


## Convierte axial a offset.
func axial_to_offset(aq: int, ar: int) -> Vector2i:
	var q: int = aq
	var r: int = ar + (aq >> 1)
	return Vector2i(q, r)


func axial_to_offsetv(axial: Vector2i) -> Vector2i:
	return axial_to_offset(axial.x, axial.y)


# ---------------------------------------------------------------------------
# VECINOS
# ---------------------------------------------------------------------------

## Devuelve las 6 coordenadas vecinas de un hex dado (sin wrap).
func get_neighbors(q: int, r: int) -> Array[Vector2i]:
	var parity: int = q & 1
	var dirs: Array[Vector2i] = NEIGHBORS[parity]
	var result: Array[Vector2i] = []
	for d in dirs:
		result.append(Vector2i(q + d.x, r + d.y))
	return result


func get_neighborsv(axial: Vector2i) -> Array[Vector2i]:
	return get_neighbors(axial.x, axial.y)


# ---------------------------------------------------------------------------
# WRAP-AROUND
# ---------------------------------------------------------------------------

## Aplica wrap-around esférico a una coordenada offset.
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


# ---------------------------------------------------------------------------
# DISTANCIA
# ---------------------------------------------------------------------------

## Distancia axial (cube) entre dos hexágonos.
func _axial_distance(aq1: int, ar1: int, aq2: int, ar2: int) -> int:
	var as1: int = -aq1 - ar1
	var as2: int = -aq2 - ar2
	return (abs(aq1 - aq2) + abs(ar1 - ar2) + abs(as1 - as2)) / 2


## Distancia entre dos hexágonos en coordenadas offset (sin wrap).
func distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var a1 := offset_to_axial(q1, r1)
	var a2 := offset_to_axial(q2, r2)
	return _axial_distance(a1.x, a1.y, a2.x, a2.y)


func distancev(a: Vector2i, b: Vector2i) -> int:
	return distance(a.x, a.y, b.x, b.y)


## Distancia mínima considerando wrap-around esférico.
## Para offset odd-q, el desplazamiento wrap en axial es distinto para q y r.
func distance_wrapped(q1: int, r1: int, q2: int, r2: int) -> int:
	var a1 := offset_to_axial(q1, r1)
	var a2 := offset_to_axial(q2, r2)
	var min_dist := _axial_distance(a1.x, a1.y, a2.x, a2.y)

	# Wrap en Q (columnas): desplazamiento axial = (map_width, -map_width/2)
	# Wrap en R (filas):    desplazamiento axial = (0, map_height)
	var wq_axial := map_width
	var wr_axial := -map_width / 2

	for dq in [-1, 0, 1]:
		for dr in [-1, 0, 1]:
			if dq == 0 and dr == 0:
				continue
			var shifted_q: int = a2.x + dq * wq_axial
			var shifted_r: int = a2.y + dq * wr_axial + dr * map_height
			var d := _axial_distance(a1.x, a1.y, shifted_q, shifted_r)
			if d < min_dist:
				min_dist = d

	return min_dist


func distance_wrappedv(a: Vector2i, b: Vector2i) -> int:
	return distance_wrapped(a.x, a.y, b.x, b.y)


## Devuelve todos los hexágonos dentro de un radio dado desde un centro (con wrap).
func get_hexes_in_range(center_q: int, center_r: int, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var ca := offset_to_axial(center_q, center_r)
	for q in range(-radius, radius + 1):
		for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			var axial := Vector2i(ca.x + q, ca.y + r)
			var offset := axial_to_offsetv(axial)
			result.append(wrap_axialv(offset))
	return result


func get_hexes_in_rangev(center: Vector2i, radius: int) -> Array[Vector2i]:
	return get_hexes_in_range(center.x, center.y, radius)


# ---------------------------------------------------------------------------
# DIMENSIONES DEL MUNDO
# ---------------------------------------------------------------------------

## Devuelve el ancho total del mundo en píxeles.
func world_width() -> float:
	return hex_h_spacing * map_width


## Devuelve el alto total del mundo en píxeles.
func world_height() -> float:
	# La última fila en columna impar tiene el mayor Y.
	var last_odd_col: int = map_width - 1 if (map_width - 1) & 1 == 1 else map_width - 2
	var last_row: int = map_height - 1
	var max_center_y: float = hex_v_spacing * (last_row + 0.5 * float(last_odd_col & 1))
	return max_center_y + hex_height * 0.5


## Devuelve el rectángulo que contiene todo el mundo en píxeles.
func get_world_rect() -> Rect2:
	var size := Vector2(world_width(), world_height())
	return Rect2(Vector2(-hex_width * 0.5, -hex_height * 0.5), size)
