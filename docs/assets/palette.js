// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  SIRE — Paleta de Colores                                               ║
// ║  Estilo: Low-poly flat 2D                                                ║
// ║  Uso: Importa los objetos de paleta o usa hex() para valores raw       ║
// ╚══════════════════════════════════════════════════════════════════════════╝
// ─── Terrenos (colores del mundo) ──────────────────────────────────────────
export const TERRAIN = {
    pradera: { hex: '#7CB342', rgb: [124, 179, 66] }, // verde vivo
    montana: { hex: '#8D6E63', rgb: [141, 110, 99] }, // marrón tierra
    agua: { hex: '#29B6F6', rgb: [41, 182, 246] }, // azul claro
    desierto: { hex: '#FDD835', rgb: [253, 216, 53] }, // amarillo arena
    nieve: { hex: '#ECEFF1', rgb: [236, 239, 241] }, // blanco hielo
    bosque: { hex: '#33691E', rgb: [51, 105, 30] }, // verde oscuro
};
// ─── Tribus / Facciones (colores de jugador) ───────────────────────────────
export const TRIBES = {
    imperio: { hex: '#E53935', rgb: [229, 57, 53] }, // rojo
    alianza: { hex: '#1E88E5', rgb: [30, 136, 229] }, // azul
    tribu: { hex: '#43A047', rgb: [67, 160, 71] }, // verde
    clan: { hex: '#FB8C00', rgb: [251, 140, 0] }, // naranja
    orden: { hex: '#8E24AA', rgb: [142, 36, 170] }, // púrpura
    enclave: { hex: '#00ACC1', rgb: [0, 172, 193] }, // cian
};
// ─── UI / Interfaz ─────────────────────────────────────────────────────────
export const UI = {
    bgDark: { hex: '#263238', rgb: [38, 50, 56] }, // fondo oscuro
    bgPanel: { hex: '#37474F', rgb: [55, 71, 79] }, // panel
    bgLight: { hex: '#CFD8DC', rgb: [207, 216, 220] }, // fondo claro
    textPrimary: { hex: '#FFFFFF', rgb: [255, 255, 255] },
    textMuted: { hex: '#90A4AE', rgb: [144, 164, 174] },
    accent: { hex: '#FFD54F', rgb: [255, 213, 79] }, // dorado
    danger: { hex: '#EF5350', rgb: [239, 83, 80] },
    success: { hex: '#66BB6A', rgb: [102, 187, 106] },
};
// ─── Recursos ──────────────────────────────────────────────────────────────
export const RESOURCES = {
    estrella: { hex: '#FFD600', rgb: [255, 214, 0] }, // oro / puntos
    arbol: { hex: '#558B2F', rgb: [85, 139, 47] }, // madera
    mineral: { hex: '#78909C', rgb: [120, 144, 156] }, // piedra/hierro
    fruto: { hex: '#E91E63', rgb: [233, 30, 99] }, // comida
    pez: { hex: '#0288D1', rgb: [2, 136, 209] }, // pesca
};
// ─── Neutros / Mapa ────────────────────────────────────────────────────────
export const NEUTRAL = {
    hexStroke: { hex: '#263238', rgb: [38, 50, 56] },
    hexHighlight: { hex: '#FFEE58', rgb: [255, 238, 88] },
    fogOfWar: { hex: '#102027', rgb: [16, 32, 39] },
    gridLine: { hex: '#455A64', rgb: [69, 90, 100] },
    selectionRing: { hex: '#FFD54F', rgb: [255, 213, 79] },
};
// ─── Helpers ───────────────────────────────────────────────────────────────
/** Devuelve el string hex de cualquier swatch */
export function hex(swatch) { return swatch.hex; }
/** Convierte un swatch a string rgba con opacidad */
export function rgba(swatch, alpha) {
    const [r, g, b] = swatch.rgb;
    return `rgba(${r},${g},${b},${alpha})`;
}
/** Genera un color más claro (para variaciones de terreno) */
export function lighten(swatch, amount = 0.2) {
    const [r, g, b] = swatch.rgb.map(c => Math.min(255, Math.round(c + (255 - c) * amount)));
    return `rgb(${r},${g},${b})`;
}
/** Genera un color más oscuro (para sombreado flat) */
export function darken(swatch, amount = 0.2) {
    const [r, g, b] = swatch.rgb.map(c => Math.max(0, Math.round(c * (1 - amount))));
    return `rgb(${r},${g},${b})`;
}
/** Devuelve un color de tribu por índice (para asignación dinámica) */
export function tribeColor(index) {
    const keys = Object.keys(TRIBES);
    return TRIBES[keys[index % keys.length]];
}
/** Colección completa exportada para iteración */
export const PALETTE = { TERRAIN, TRIBES, UI, RESOURCES, NEUTRAL };
