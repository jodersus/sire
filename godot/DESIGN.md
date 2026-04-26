# Diseño del Juego - sire
## Migración a Godot 4

### Concepto
Juego de estrategia por turnos (4X) inspirado en The Battle of Polytopia.
Diferencias clave: casillas hexagonales + mundo esférico con wrap-around.

### Terrenos (TileMapLayer)
| Terreno | Color | Movimiento | Visión | Recursos |
|---------|-------|-----------|--------|----------|
| Pradera | #7CB342 | 1 | normal | - |
| Bosque | #33691E | 2 | -1 | Madera |
| Montaña | #5D4037 | 3 | +1 | Piedra |
| Agua | #1976D2 | - | - | Pescado |
| Desierto | #FBC02D | 1 | normal | - |
| Nieve | #E0E0E0 | 2 | normal | - |

### Tribus (7)
| Tribu | Color | Habilidad Especial | Unidad Inicial |
|-------|-------|-------------------|----------------|
| Solaris | #F4D03F | -20% coste tecnologías | Explorador |
| Umbra | #2C3E50 | +1 visión | Explorador |
| Sylva | #27AE60 | -30% coste madera | Explorador |
| Ferrum | #922B21 | +1 ataque | Guerrero |
| Maris | #3498DB | Bono naval | Barco |
| Equus | #E67E22 | +1 movimiento caballería | Jinete |
| Nomad | #8E44AD | +25% crecimiento ciudades | Explorador |

### Unidades (9)
| Unidad | Ataque | Defensa | Movimiento | Coste | Especial |
|--------|--------|---------|-----------|-------|----------|
| Explorador | 1 | 1 | 2 | 2 | Fundar ciudad |
| Guerrero | 2 | 2 | 1 | 3 | - |
| Arquero | 2 | 1 | 1 | 3 | Ataque a distancia (2) |
| Jinete | 2 | 1 | 2 | 5 | Escape (mover después de atacar) |
| Caballero | 3 | 3 | 1 | 8 | - |
| Barco | 1 | 1 | 3 | 5 | Transporte acuático |
| Buque de Guerra | 3 | 2 | 2 | 8 | Ataque a distancia (2) |
| Catapulta | 4 | 0 | 1 | 8 | Ataque a distancia (3) |
| Gigante | 5 | 4 | 1 | 20 | Sin habilidades |

### Tecnologías (14) - Árbol
```
Organización (0)
├── Caza (2) → Equitación (5) → Herrería (8)
│   └── Navegación (6) → Construcción (10)
├── Pesca (3) → Velas (7)
└── Agricultura (4) → Construcción (10)

Herrería (8)
├── Escudos (5)
├── Arquería (6)
└── Matemáticas (8) → Catapultas (10)

Construcción (10)
└── Caminos (8) → Comercio (12)
```

### Ciudades
- Niveles 1-5
- Población inicial: 1
- Crecimiento por turno según recursos
- Edificios: Puerto, Mina, Aserradero, Forja, Muralla, Templo, Parque

### Recursos
- Estrellas (moneda principal)
- Madera, Piedra, Frutas, Pescado

### Combate
- Ataque vs Defensa + bonos terreno
- Contraataque cuerpo a cuerpo
- Asedio a ciudades
- Curación en territorio propio

### Turnos (Fases)
1. Ingreso (recursos)
2. Tecnología (investigar)
3. Movimiento (unidades)
4. Combate (resolución)
5. Construcción (edificios/unidades)

### Mundo Esférico (Wrap-around)
- Mapa cuadrado con coordenadas (q, r) axiales
- Si te sales por un borde, apareces por el opuesto
- Distancia mínima considerando 9 desplazamientos posibles
- Renderizado: repetición visual del mapa en 3x3 para efecto continuo

### Estilo Visual
- Low-poly flat 2D
- Colores planos, sin gradientes
- Hexágonos flat-top
- Sprites simples para unidades (siluetas)
- UI oscura con acentos dorados
