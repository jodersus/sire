/**
 * Sprites.ts
 * Carga y cache de sprites. Por ahora genera placeholders coloreados
 * para terrenos y unidades, sin dependencias externas.
 */
const TERRAIN_COLORS = {
    plains: '#6ab04c',
    mountain: '#a0522d',
    water: '#2980b9',
    desert: '#f1c40f',
    forest: '#1e8449',
    unknown: '#7f8c8d',
};
const TRIBE_COLORS = {
    red: '#c0392b',
    blue: '#2980b9',
    green: '#27ae60',
    yellow: '#f1c40f',
    purple: '#8e44ad',
};
/** Genera un canvas con un hexágono relleno del color dado. */
function createHexSprite(size, fill, stroke) {
    const canvas = document.createElement('canvas');
    canvas.width = size * 2 + 4;
    canvas.height = size * 2 + 4;
    const ctx = canvas.getContext('2d');
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
        const angle = (Math.PI / 3) * i - Math.PI / 6;
        const px = cx + size * Math.cos(angle);
        const py = cy + size * Math.sin(angle);
        if (i === 0)
            ctx.moveTo(px, py);
        else
            ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = stroke;
    ctx.stroke();
    return canvas;
}
/** Genera un canvas con un círculo (unidad placeholder). */
function createUnitSprite(size, tribeColor, icon) {
    const canvas = document.createElement('canvas');
    canvas.width = size + 4;
    canvas.height = size + 4;
    const ctx = canvas.getContext('2d');
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    const radius = size * 0.35;
    // Sombra sutil
    ctx.beginPath();
    ctx.arc(cx + 1, cy + 1, radius, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.2)';
    ctx.fill();
    // Cuerpo
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fillStyle = tribeColor;
    ctx.fill();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = 'rgba(0,0,0,0.4)';
    ctx.stroke();
    // Icono
    ctx.fillStyle = '#ffffff';
    ctx.font = `bold ${Math.floor(size * 0.4)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(icon, cx, cy);
    return canvas;
}
/** Cache de sprites generados. */
const spriteCache = {
    hex: new Map(),
    unit: new Map(),
};
/**
 * Obtiene (o genera) un sprite de hexágono para un tipo de terreno.
 */
export function getHexSprite(terrain, size = 32) {
    const key = `${terrain}_${size}`;
    let sprite = spriteCache.hex.get(key);
    if (!sprite) {
        const fill = TERRAIN_COLORS[terrain] ?? TERRAIN_COLORS.unknown;
        const stroke = adjustColor(fill, -30);
        sprite = createHexSprite(size, fill, stroke);
        spriteCache.hex.set(key, sprite);
    }
    return sprite;
}
/**
 * Obtiene (o genera) un sprite de unidad para un color de tribu e icono.
 */
export function getUnitSprite(tribeColor, icon, size = 32) {
    const key = `${tribeColor}_${icon}_${size}`;
    let sprite = spriteCache.unit.get(key);
    if (!sprite) {
        const color = TRIBE_COLORS[tribeColor] ?? tribeColor;
        sprite = createUnitSprite(size, color, icon);
        spriteCache.unit.set(key, sprite);
    }
    return sprite;
}
/** Precalcula sprites comunes para evitar stalls en runtime. */
export function preloadSprites(size = 32) {
    for (const t of Object.keys(TERRAIN_COLORS)) {
        getHexSprite(t, size);
    }
    for (const c of Object.keys(TRIBE_COLORS)) {
        getUnitSprite(c, '★', size);
        getUnitSprite(c, '♦', size);
        getUnitSprite(c, '♠', size);
    }
}
/** Oscurece un color hex (#rrggbb) por `amount` (negativo = más oscuro). */
function adjustColor(hex, amount) {
    const num = parseInt(hex.replace('#', ''), 16);
    let r = (num >> 16) + amount;
    let g = ((num >> 8) & 0x00ff) + amount;
    let b = (num & 0x0000ff) + amount;
    r = Math.max(0, Math.min(255, r));
    g = Math.max(0, Math.min(255, g));
    b = Math.max(0, Math.min(255, b));
    return `#${(r << 16 | g << 8 | b).toString(16).padStart(6, '0')}`;
}
