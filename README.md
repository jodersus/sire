# SIRE

Juego de estrategia por turnos inspirado en The Battle of Polytopia.
Mundo hexagonal esférico con wrap-around, 7 tribus jugables, sistema de tecnologías, combate por turnos e IA de bots.

**Motor:** Godot 4.4 (GDScript)  
**Export:** HTML5 (GitHub Pages)  
**Repo:** https://github.com/jodersus/sire

---

## Estado Actual

### Implementado
- Generación procedural de mapa (6 terrenos, recursos)
- Grilla hexagonal axial con wrap-around esférico
- 7 tribus con habilidades únicas
- 9 tipos de unidades con stats y bonos de tribu
- 14 tecnologías con árbol de prerequisitos
- Sistema de ciudades (niveles 1-5, edificios, cola de entrenamiento)
- Combate con bonos de terreno, contraataque, asedio
- IA de bots (3 dificultades)
- Menú principal, configuración de partida, HUD
- Cámara con pan, zoom y límites suaves

### En Desarrollo
- Renderizado visual de unidades y ciudades en el mapa
- Selección de unidades y movimiento interactivo
- Pipeline de build/export a HTML5

---

## Estructura

```
godot/
  project.godot
  scenes/           # Escenas: menú, setup, juego, HUD, pausa
  scripts/          # Lógica del juego (GDScript)
  assets/           # Sprites SVG, tilesets, audio, íconos
docs/godot/         # Export HTML5 para GitHub Pages
```

---

## Desarrollo Local

Requiere Godot 4.4.1+.

Exportar a Web:
- Editor → Exportar → Web → Exportar a `docs/godot/`

---

## URL Publicada

`https://jodersus.github.io/sire/` (GitHub Pages desde `/docs`)
