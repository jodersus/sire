# Assets de SIRE

Este directorio contiene todos los activos visuales del juego.

## Estructura

```
assets/
├── palette.ts          ← Paleta de colores tipada (TypeScript)
├── style-guide.md      ← Guía visual completa
├── README.md           ← Este archivo
└── svg/                ← Assets vectoriales
    ├── hex_base.svg
    ├── terrain_*.svg
    ├── unit_*.svg
    └── resource_*.svg
```

## Cómo usar

### Importar colores

```ts
import { TERRAIN, TRIBES, UI, hex, darken, lighten } from './palette';

// Color base
ctx.fillStyle = hex(TERRAIN.pradera);

// Variación para sombreado flat
ctx.fillStyle = darken(TERRAIN.pradera, 0.2);

// Color de tribu
ctx.fillStyle = hex(TRIBES.imperio);
```

### Usar SVGs

Los SVGs están optimizados para usar inline o como sprites:

```ts
// Inline (recomendado para canvas)
const svgText = await fetch('assets/svg/hex_base.svg').then(r => r.text());
const img = new Image();
img.src = 'data:image/svg+xml;base64,' + btoa(svgText);

// O dibujar proceduralmente con palette.ts
```

### Generar terrenos dinámicos

Cada SVG de terreno usa los colores de `palette.ts`. Para variaciones:

```ts
// Reemplazar colores en el SVG string antes de renderizar
const coloredSvg = terrainSvg
  .replace('#BASE_COLOR', hex(TERRAIN.pradera))
  .replace('#DETAIL_COLOR', lighten(TERRAIN.pradera, 0.15));
```

## Reglas

1. **Nuevos assets** van en `svg/` con prefijo de tipo.
2. **Nuevos colores** se añaden a `palette.ts`.
3. **No usar herramientas externas.** Todo es code-generated.
4. **Mantener consistencia** con `style-guide.md`.

## Lista de Assets

| Archivo              | Descripción                        |
|---------------------|------------------------------------|
| hex_base.svg        | Hexágono base, stroke + fill       |
| terrain_pradera.svg | Pradera con textura low-poly       |
| terrain_montana.svg | Montaña con pico central           |
| terrain_agua.svg    | Agua con ondas simplificadas       |
| terrain_desierto.svg| Desierto con dunas                 |
| unit_warrior.svg    | Silueta de guerrero con lanza      |
| unit_rider.svg      | Silueta de jinete                  |
| unit_ship.svg       | Silueta de barco                   |
| resource_star.svg   | Estrella (puntos / moneda)         |
| resource_tree.svg   | Árbol estilizado                   |
| resource_mine.svg   | Mina / montaña con pico            |

---

*Generado automáticamente. Modificar con cuidado.*
