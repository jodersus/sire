# Plan de Desarrollo — sire

## Visión

Juego de estrategia por turnos (4X) en explorador. Inspirado en Polytopia. Casillas hexagonales. Mundo esférico con wrap-around.

## Premisas Técnicas

- **Frontend**: Vanilla TypeScript, HTML5 Canvas (no frameworks de UI)
- **Render**: Canvas 2D, sprites 2D estilo low-poly plano (no WebGL por simplicidad inicial)
- **Build**: Vite (dev server + bundling)
- **Deploy**: GitHub Pages desde repo
- **Arquitectura**: ECS (Entity Component System) para entidades del juego

## Fases

| Fase | Área | Prioridad | Dependencias |
|------|------|-----------|-------------|
| 1 | Motor hex grid + mundo esférico | Crítica | Ninguna |
| 2 | Sistema de recursos y terreno | Alta | Fase 1 |
| 3 | Tribus, unidades, tecnologías | Alta | Fase 2 |
| 4 | Renderizado de mapa y UI básica | Alta | Fase 1 |
| 5 | Turnos y reglas de juego | Alta | Fase 3, 4 |
| 6 | IA de PNJ | Media | Fase 5 |
| 7 | Assets gráficos | Media | Fase 4 |
| 8 | Sonido y polish | Baja | Fase 7 |

## Áreas de Subagentes

1. **Engine** — Hex grid, coordenadas axiales/cúbicas, wrap-around esférico
2. **Game Logic** — Tribus, recursos, tecnologías, unidades, combate
3. **Renderer/UI** — Canvas rendering, cámara, input, HUD
4. **AI** — Pathfinding, decisión de bots, niveles de dificultad
5. **Assets** — Paletas de colores, estilo visual, sprites procedurales

## Decisiones Arquitectónicas Iniciales

| Decisión | Elegido |
|----------|---------|
| Coordenadas hex | Axiales (q, r) |
| Wrap-around | Ambos ejes (X e Y) |
| ECS | Sí, sistema ligero propio |
| Canvas | 2D, sprites flat low-poly |
| Audio | Web Audio API, sin librería externa |

---
_Última actualización: 2026-04-26_
