/**
 * HexRenderer.ts
 * Dibujo de hexágonos planos: fill, stroke, hover, selección, y terrenos coloreados.
 * Layout: hexágonos plan-top (puntoy) con apotema = HEX_SIZE.
 */
export const HEX_SIZE = 32; // radio (distancia centro a vértice)
export const HEX_HEIGHT = HEX_SIZE * 2;
export const HEX_WIDTH = Math.sqrt(3) * HEX_SIZE;
export const HEX_HORIZ_SPACING = HEX_WIDTH;
export const HEX_VERT_SPACING = HEX_HEIGHT * 0.75;
const TERRAIN_COLORS = {
    plains: { fill: '#6ab04c', stroke: '#4a8a32' },
    mountain: { fill: '#a0522d', stroke: '#7a3e1f' },
    water: { fill: '#2980b9', stroke: '#1a5276' },
    desert: { fill: '#f1c40f', stroke: '#c9a40e' },
    forest: { fill: '#1e8449', stroke: '#166636' },
    unknown: { fill: '#7f8c8d', stroke: '#5d6d7e' },
};
const HIGHLIGHT_COLORS = {
    hover: 'rgba(255,255,255,0.25)',
    selected: 'rgba(255,255,255,0.50)',
    move: 'rgba(52,211,153,0.40)',
    attack: 'rgba(248,113,113,0.40)',
};
/** Convierte coordenadas axiales (q,r) a píxeles del mundo (flat-top layout). */
export function axialToPixel(q, r) {
    const x = HEX_SIZE * (Math.sqrt(3) * q + (Math.sqrt(3) / 2) * r);
    const y = HEX_SIZE * (1.5 * r);
    return { x, y };
}
/** Convierte píxeles del mundo a coordenadas axiales (q,r). */
export function pixelToAxial(px, py) {
    const q = (Math.sqrt(3) / 3 * px - 1 / 3 * py) / HEX_SIZE;
    const r = (2 / 3 * py) / HEX_SIZE;
    const s = -q - r;
    return cubeRound(q, r, s);
}
function cubeRound(q, r, s) {
    let rq = Math.round(q);
    let rr = Math.round(r);
    let rs = Math.round(s);
    const dq = Math.abs(rq - q);
    const dr = Math.abs(rr - r);
    const ds = Math.abs(rs - s);
    if (dq > dr && dq > ds)
        rq = -rr - rs;
    else if (dr > ds)
        rr = -rq - rs;
    return { q: rq, r: rr };
}
/** Dibuja un hexágono en las coordenadas del mundo. */
export function drawHex(ctx, camera, cell) {
    const { x: cx, y: cy } = axialToPixel(cell.q, cell.r);
    // Frustum culling básico: si está muy lejos de la cámara, saltar
    const screen = camera.worldToScreen(cx, cy);
    const canvas = ctx.canvas;
    const margin = HEX_SIZE * camera.getState().zoom * 2;
    if (screen.x < -margin ||
        screen.x > canvas.width + margin ||
        screen.y < -margin ||
        screen.y > canvas.height + margin) {
        return;
    }
    const colors = TERRAIN_COLORS[cell.terrain] ?? TERRAIN_COLORS.unknown;
    const scaledSize = HEX_SIZE; // la cámara escala el ctx
    ctx.save();
    camera.apply(ctx);
    // Dibujar hexágono
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
        const angle = (Math.PI / 3) * i - Math.PI / 6; // flat-top, empezar arriba
        const px = cx + scaledSize * Math.cos(angle);
        const py = cy + scaledSize * Math.sin(angle);
        if (i === 0)
            ctx.moveTo(px, py);
        else
            ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fillStyle = colors.fill;
    ctx.fill();
    ctx.lineWidth = 1.5 / camera.getState().zoom;
    ctx.strokeStyle = colors.stroke;
    ctx.stroke();
    // Capa de highlight si existe
    if (cell.highlight && HIGHLIGHT_COLORS[cell.highlight]) {
        ctx.fillStyle = HIGHLIGHT_COLORS[cell.highlight];
        ctx.fill();
    }
    // Unidad (placeholder: círculo + letra)
    if (cell.unit) {
        drawUnit(ctx, cx, cy, scaledSize, cell.unit, camera.getState().zoom);
    }
    ctx.restore();
}
function drawUnit(ctx, cx, cy, hexSize, unit, zoom) {
    const radius = hexSize * 0.35;
    ctx.beginPath();
    ctx.arc(cx, cy - hexSize * 0.05, radius, 0, Math.PI * 2);
    ctx.fillStyle = unit.tribeColor;
    ctx.fill();
    ctx.lineWidth = 1.5 / zoom;
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    ctx.stroke();
    // Icono simple centrado
    ctx.fillStyle = '#ffffff';
    ctx.font = `${Math.floor(hexSize * 0.45)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(unit.icon, cx, cy - hexSize * 0.05);
}
/** Dibuja la cuadrícula completa de hexágonos. */
export function drawHexGrid(ctx, camera, cells) {
    // Ordenar para que el agua quede detrás y las unidades encima no se corten mal
    // En flat 2D no hay profundidad real, pero sí orden por terreno
    const order = {
        water: 0, desert: 1, plains: 2, forest: 3, mountain: 4, unknown: 5,
    };
    const sorted = [...cells].sort((a, b) => order[a.terrain] - order[b.terrain]);
    for (const cell of sorted) {
        drawHex(ctx, camera, cell);
    }
}
