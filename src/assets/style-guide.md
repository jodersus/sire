# SIRE — Style Guide

> Guía visual para mantener coherencia en todo el juego.
> Estilo: **low-poly flat 2D**, inspirado en The Battle of Polytopia.

---

## 1. Filosofía Visual

- **Simplicidad antes que detalle.** Cada sprite debe leerse a 64px.
- **Formas geométricas.** Hexágonos, triángulos, rombos. Curvas mínimas.
- **Color como información.** El color dice más que la forma.
- **Sin gradientes.** Usa tonos planos con variaciones de luminosidad máximo 2 niveles.

---

## 2. Paleta de Colores

Ver `palette.ts` para valores exactos.

| Categoría  | Propósito                           |
|-----------|-------------------------------------|
| TERRAIN   | Colores base del mapa               |
| TRIBES    | Identidad visual de cada jugador    |
| UI        | Paneles, botones, texto             |
| RESOURCES | Iconos de recursos recolectables    |
| NEUTRAL   | Grids, selección, fog of war        |

### Principios de color

- **Contraste mínimo:** texto blanco (#FFF) sobre fondos oscuros, texto oscuro (#263238) sobre terrenos claros.
- **Accesibilidad:** los 6 colores de tribu son distinguibles para daltonismo (rojo/azul/verde/naranja/púrpura/cian).
- **Variedad de terreno:** cada terreno tiene un tono base + un tono más claro para detalles.

---

## 3. Formas y Geometría

### Hexágonos

- Tamaño estándar de referencia: **ancho 100px, alto ~86.6px** (flat-top).
- Stroke: 2px, color `#263238`.
- Esquinas ligeramente redondeadas (rx=4) para suavidad flat.

### Unidades

- Siluetas simples, orientadas a 45° o de frente.
- Máximo 3-4 polígonos por unidad.
- Color de relleno = color de tribu. Sin outline.

### Recursos

- Iconos de ~24-32px.
- Formas reconocibles instantáneamente.
- Color propio de recurso, sin outline.

---

## 4. Tipografía

| Contexto         | Familia           | Peso   | Tamaño |
|-----------------|-------------------|--------|--------|
| Títulos / HUD   | Inter, system-ui  | 700    | 24px   |
| Labels / Botones| Inter, system-ui  | 600    | 14px   |
| Números (turno) | JetBrains Mono    | 700    | 18px   |
| Chat / Flavor   | Inter, system-ui  | 400    | 12px   |

- Todo en **mayúsculas** para labels cortos (botones, etiquetas).
- Tracking +0.05em en mayúsculas.

---

## 5. Espaciado y Layout

- Grid base: **8px**.
- Padding estándar de paneles: **16px**.
- Separación entre elementos: **8px o 16px**.
- Bordes redondeados UI: **4px** (suave) o **8px** (cards).
- Sombras: ninguna. Usa bordes o separación de color.

---

## 6. Convenciones de Nomenclatura

### Archivos SVG

```
{tipo}_{nombre}.svg
```

- `hex_base.svg`
- `terrain_pradera.svg`
- `unit_warrior.svg`
- `resource_star.svg`

### En código

```ts
import { TERRAIN, TRIBES, UI, hex, darken } from './palette';

// Asignar color de terreno
ctx.fillStyle = hex(TERRAIN.pradera);

// Sombreado flat
ctx.fillStyle = darken(TERRAIN.pradera, 0.15);

// Color de tribu
const miColor = TRIBES.imperio;
```

---

## 7. Renderizado Canvas

- Hexágonos: usar `Path2D` o función `drawHex(ctx, x, y, size)`.
- Unidades: dibujar como polígonos con `ctx.beginPath()` + `ctx.fill()`.
- Recursos: sprites de 32x32, centrados en el hexágono.
- Escala: todo el juego renderiza a un canvas fijo; escala con CSS `transform`.

---

## 8. Consistencia de Assets

- Todo SVG usa **viewBox** para escalabilidad.
- Colores hardcodeados en SVG (no dependen de CSS externo).
- Formas cerradas sin transparencia en rellenos principales.
- Stroke sólo en hexágonos de grid, nunca en unidades o recursos.

---

*Última actualización: inicial.*
