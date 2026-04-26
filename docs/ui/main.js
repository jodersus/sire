/**
 * main.ts
 * Punto de entrada del juego "sire".
 * Inicializa canvas, cámara, input, HUD y arranca el loop.
 */
import { Camera } from './Camera.js';
import { CanvasRenderer } from './CanvasRenderer.js';
import { InputHandler } from './InputHandler.js';
import { preloadSprites } from './Sprites.js';
import { HUD } from './HUD.js';
// --- Estado del juego (placeholder) ---
let selected = null;
let hover = null;
// Generar un mapa de prueba
function generateTestMap(radius = 6) {
    const cells = [];
    const terrains = ['plains', 'mountain', 'water', 'desert', 'forest'];
    for (let q = -radius; q <= radius; q++) {
        for (let r = -radius; r <= radius; r++) {
            if (Math.abs(q + r) <= radius) {
                const terrain = terrains[Math.floor(Math.random() * terrains.length)];
                const cell = { q, r, terrain };
                // Unidad de prueba en el centro
                if (q === 0 && r === 0) {
                    cell.unit = { tribeColor: 'red', icon: '★' };
                }
                cells.push(cell);
            }
        }
    }
    return cells;
}
function init() {
    const container = document.getElementById('game-container');
    if (!container) {
        throw new Error('No se encontró #game-container');
    }
    // Precargar sprites placeholder
    preloadSprites(32);
    const cells = generateTestMap(8);
    const camera = new Camera({ x: 0, y: 0, zoom: 1.2 });
    camera.setBounds(-500, -500, 500, 500);
    const hudState = {
        turn: 1,
        resources: {
            Estrellas: 5,
            Población: 3,
        },
        selectedHex: null,
        availableActions: [],
    };
    const hud = new HUD(hudState, camera);
    const renderState = {
        cells,
        camera,
        hud,
        turn: 1,
        playerResources: hudState.resources,
    };
    const renderer = new CanvasRenderer(container, renderState);
    const input = new InputHandler(renderer.getCanvas(), camera, {
        onHexClick: (q, r, cell) => {
            selected = { q, r };
            if (cell) {
                cell.highlight = cell.highlight === 'selected' ? undefined : 'selected';
            }
            // Limpiar selección previa de otras celdas
            for (const c of cells) {
                if (c.q !== q || c.r !== r)
                    c.highlight = undefined;
            }
            hud.update({
                selectedHex: selected,
                availableActions: cell ? ['Mover', 'Atacar', 'Colonizar', 'Explorar'] : [],
            });
        },
        onHexHover: (q, r, cell) => {
            hover = { q, r };
            if (cell && cell.highlight !== 'selected') {
                cell.highlight = 'hover';
            }
            // Limpiar hover de otras
            for (const c of cells) {
                if ((c.q !== q || c.r !== r) && c.highlight === 'hover') {
                    c.highlight = undefined;
                }
            }
        },
        onPan: (dx, dy) => {
            camera.pan(dx, dy);
        },
        onZoom: (sx, sy, delta) => {
            camera.zoomAt(sx, sy, delta);
        },
        onContextMenu: (q, r, cell) => {
            console.log('Contexto:', q, r, cell);
        },
    });
    input.setCells(cells);
    renderer.start();
    // Exponer al window para debug
    window.__sire__ = { camera, cells, renderer, input, hud };
    console.log('Sire UI inicializado.');
}
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
}
else {
    init();
}
