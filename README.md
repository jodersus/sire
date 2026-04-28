# SIRE

Juego de estrategia por turnos inspirado en The Battle of Polytopia.
Mundo hexagonal esférico con wrap-around, 7 tribus jugables, sistema de tecnologías, combate por turnos e IA de bots.

**Motor:** Godot 4.4 (GDScript)  
**Export:** HTML5 (GitHub Pages)  
**Repo:** https://github.com/jodersus/sire

---

## Jugar Ahora

**https://jodersus.github.io/sire/**

Single-player contra bots. No requiere autenticación ni registro.

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
- Menú principal, configuración de partida, HUD interactivo
- Cámara con pan, zoom y límites suaves
- Selección de unidades, ciudades y movimiento interactivo
- Sistema de turnos con ingreso de recursos
- Pantalla de victoria/derrota

### En Desarrollo
- Pipeline de build/export automático a HTML5
- Árbol de tecnologías UI
- Sonido y música

---

## Estructura

```
godot/
  project.godot
  scenes/           # Escenas: menú, setup, juego, HUD, pausa, game over
  scripts/          # Lógica del juego (GDScript)
  assets/           # Sprites SVG, tilesets, audio, íconos
docs/               # Export HTML5 para GitHub Pages
```

---

## Desarrollo Local

Requiere Godot 4.4.1+.

Exportar a Web:
```bash
./build.sh
```

O manualmente:
```bash
cd godot
godot --headless --export-release "Web" ../docs/index.html
```

---

## Controles

| Acción | Input |
|--------|-------|
| Desplazar mapa | Click-drag / Flechas |
| Zoom | Scroll |
| Seleccionar unidad/ciudad | Click izquierdo |
| Mover unidad | Click en hex verde |
| Cancelar selección | Click derecho / ESC |
| Fin de turno | ESPACIO / ENTER |
| Pausa | ESC |

