# sire

_Juego de estrategia por turnos, basado en explorador web._

Inspirado en *The Battle of Polytopia*, con dos cambios fundamentales:
- **Casillas hexagonales** en lugar de cuadradas
- **Mundo esférico**: el tablero tiene wrap-around en ambos ejes

## Stack Tecnológico

- HTML5 Canvas / WebGL
- TypeScript
- Sin framework de UI externo (canvas nativo)

## Estructura del Proyecto

```
src/
├── engine/          ← Motor del juego (hex grid, mundo esférico, turnos)
├── game/            ← Reglas, tribus, tecnologías, unidades
├── ai/              ← Inteligencia de los PNJ
├── ui/              ← Interfaz de usuario, renderizado, input
├── assets/          ← Sprites, tilesets, audio
└── main.ts          ← Punto de entrada
```

## Estado

En desarrollo. Fase 1: motor de hex grid + mundo esférico.

---
_Última actualización: 2026-04-26_
