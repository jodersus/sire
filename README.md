# Sire

Juego de estrategia por turnos inspirado en The Battle of Polytopia. Mundo hexagonal esférico con wrap-around, 7 tribus jugables, sistema de tecnologías, combate por turnos e IA de bots.

## 🎮 Jugar

Accede a la versión publicada en GitHub Pages:

**URL:** `https://<tu-usuario>.github.io/sire/`

> Reemplaza `<tu-usuario>` con tu nombre de usuario de GitHub.

### Token de acceso
Al cargar la página se solicita un token. El token por defecto es:
```
REDACTED_TOKEN
```

## 🛠️ Desarrollo

### Requisitos
- Node.js 18+
- TypeScript 5+

### Instalación
```bash
npm install
```

### Compilar
```bash
npx tsc
```

El compilado se genera en `docs/` (configurado para GitHub Pages).

### Estructura
```
src/
  engine/         # Motor: hex grid, ECS, generación procedural, mundo esférico
  game/           # Lógica: tribus, unidades, ciudades, combate, tecnologías
  ui/             # Interfaz: renderer Canvas 2D, cámara, input, HUD
  assets/         # Paleta de colores y SVGs

docs/             # Compilado para GitHub Pages
```

## 🗺️ Características

- **Mundo esférico**: Mapa toroidal con wrap-around visual. Sal por un borde, entra por el opuesto.
- **7 tribus**: Cada una con habilidad pasiva única, color y unidad inicial.
- **9 unidades**: Explorador, Guerrero, Arquero, Jinete, Caballero, Barco, Buque de Guerra, Catapulta, Gigante.
- **14 tecnologías**: Árbol tecnológico con prerequisitos.
- **Sistema de ciudades**: Niveles 1-5, territorio, edificios, cola de entrenamiento.
- **Combate por turnos**: Con bonos de terreno, contraataque y asedios a ciudades.
- **IA de bots**: 3 niveles de dificultad (expandir, atacar, entrenar).
- **Fog of war**: Exploración progresiva del mapa.

## 📝 Notas

- TypeScript vanilla, sin frameworks externos.
- Renderer Canvas 2D puro.
- Sin backend: autenticación por token en frontend.
