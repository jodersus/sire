/**
 * HexRenderer.ts
 * Dibujo de hexágonos planos con wrap-around esférico.
 * Renderiza múltiples copias del mundo para efecto toroidal.
 */
export const HEX_SIZE = 28;
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
    unknown: { fill: '#2c3e50', stroke: '#1a252f' },
};
const HIGHLIGHT_COLORS = {
    hover: 'rgba(255,255,255,0.25)',
    selected: 'rgba(255,255,255,0.55)',
    move: 'rgba(52,211,153,0.45)',
    attack: 'rgba(248,113,113,0.50)',
    city: 'rgba(255,213,79,0.45)',
};
/** Convierte axial a píxeles (flat-top). */
export function axialToPixel(q, r) {
    const x = HEX_SIZE * (Math.sqrt(3) * q + (Math.sqrt(3) / 2) * r);
    const y = HEX_SIZE * (1.5 * r);
    return { x, y };
}
/** Convierte píxeles a axial. */
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
/** Calcula vectores de repetición del mundo en píxeles. */
export function getWorldRepeatVectors(worldW, worldH) {
    // Vector 1: desplazar q por worldW
    const p1a = axialToPixel(0, 0);
    const p1b = axialToPixel(worldW, 0);
    // Vector 2: desplazar r por worldH
    const p2a = axialToPixel(0, 0);
    const p2b = axialToPixel(0, worldH);
    return {
        dx1: p1b.x - p1a.x,
        dy1: p1b.y - p1a.y,
        dx2: p2b.x - p2a.x,
        dy2: p2b.y - p2a.y,
    };
}
/** Genera offsets 3x3 para wrap-around. */
export function getWrapOffsets(worldW, worldH) {
    const { dx1, dy1, dx2, dy2 } = getWorldRepeatVectors(worldW, worldH);
    const offsets = [];
    for (let i = -1; i <= 1; i++) {
        for (let j = -1; j <= 1; j++) {
            offsets.push({
                x: i * dx1 + j * dx2,
                y: i * dy1 + j * dy2,
            });
        }
    }
    return offsets;
}
/** Dibuja un hexágono. */
function drawHexShape(ctx, cx, cy, size) {
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
}
/** Dibuja una celda completa. */
export function drawHexCell(ctx, camera, cell, offsetX = 0, offsetY = 0) {
    const { x: cx, y: cy } = axialToPixel(cell.q, cell.r);
    const wx = cx + offsetX;
    const wy = cy + offsetY;
    // Frustum culling
    const screen = camera.worldToScreen(wx, wy);
    const canvas = ctx.canvas;
    const margin = HEX_SIZE * camera.getState().zoom * 2;
    if (screen.x < -margin ||
        screen.x > canvas.width / (window.devicePixelRatio || 1) + margin ||
        screen.y < -margin ||
        screen.y > canvas.height / (window.devicePixelRatio || 1) + margin) {
        return;
    }
    const colors = TERRAIN_COLORS[cell.terrain] ?? TERRAIN_COLORS.unknown;
    const zoom = camera.getState().zoom;
    ctx.save();
    camera.apply(ctx);
    // Hex base
    drawHexShape(ctx, wx, wy, HEX_SIZE);
    ctx.fillStyle = colors.fill;
    ctx.fill();
    ctx.lineWidth = 1.2 / zoom;
    ctx.strokeStyle = colors.stroke;
    ctx.stroke();
    // Fog of war
    if (cell.fogged) {
        ctx.fillStyle = 'rgba(10,15,30,0.75)';
        ctx.fill();
    }
    // Highlight
    if (cell.highlight && HIGHLIGHT_COLORS[cell.highlight]) {
        ctx.fillStyle = HIGHLIGHT_COLORS[cell.highlight];
        ctx.fill();
        // Borde brillante
        ctx.lineWidth = 2 / zoom;
        ctx.strokeStyle = HIGHLIGHT_COLORS[cell.highlight].replace(/[\d.]+\)$/, '0.9)');
        ctx.stroke();
    }
    // Ciudad
    if (cell.city && !cell.fogged) {
        drawCity(ctx, wx, wy, HEX_SIZE, cell.city.color, cell.city.level, cell.city.name, zoom);
    }
    // Unidad
    if (cell.unit && !cell.fogged) {
        drawUnit(ctx, wx, wy, HEX_SIZE, cell.unit, zoom);
    }
    ctx.restore();
}
function drawCity(ctx, cx, cy, hexSize, color, level, name, zoom) {
    const size = hexSize * 0.45;
    // Sombra
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fillRect(cx - size + 2, cy - size + 2, size * 2, size * 2);
    // Edificio
    ctx.fillStyle = color;
    ctx.fillRect(cx - size, cy - size, size * 2, size * 2);
    ctx.lineWidth = 1.5 / zoom;
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    ctx.strokeRect(cx - size, cy - size, size * 2, size * 2);
    // Nivel (puntos en esquina)
    ctx.fillStyle = '#FFD54F';
    for (let i = 0; i < level; i++) {
        ctx.beginPath();
        ctx.arc(cx + size - 4 - i * 6, cy - size + 5, 2, 0, Math.PI * 2);
        ctx.fill();
    }
    // Nombre pequeño
    ctx.fillStyle = '#ffffff';
    ctx.font = `${Math.max(8, Math.floor(hexSize * 0.22))}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText(name, cx, cy - size - 2);
}
function drawUnit(ctx, cx, cy, hexSize, unit, zoom) {
    const radius = hexSize * 0.32;
    // Sombra
    ctx.beginPath();
    ctx.arc(cx + 1, cy + 2, radius, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.fill();
    // Cuerpo
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fillStyle = unit.tribeColor;
    ctx.fill();
    ctx.lineWidth = 1.5 / zoom;
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    ctx.stroke();
    // Icono
    ctx.fillStyle = '#ffffff';
    ctx.font = `bold ${Math.floor(hexSize * 0.4)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(unit.icon, cx, cy);
    // Barra de vida
    if (unit.healthPercent < 1) {
        const barW = radius * 1.6;
        const barH = 3;
        const bx = cx - barW / 2;
        const by = cy + radius + 3;
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.fillRect(bx, by, barW, barH);
        ctx.fillStyle = unit.healthPercent > 0.5 ? '#4caf50' : unit.healthPercent > 0.25 ? '#ff9800' : '#f44336';
        ctx.fillRect(bx, by, barW * unit.healthPercent, barH);
    }
}
/** Dibuja la cuadrícula completa con wrap-around. */
export function drawHexGrid(ctx, camera, cells, worldW, worldH) {
    const offsets = getWrapOffsets(worldW, worldH);
    // Ordenar: agua primero, luego terreno, unidades al final
    const order = {
        water: 0, desert: 1, plains: 2, forest: 3, mountain: 4, unknown: 5,
    };
    const sorted = [...cells].sort((a, b) => order[a.terrain] - order[b.terrain]);
    for (const offset of offsets) {
        for (const cell of sorted) {
            drawHexCell(ctx, camera, cell, offset.x, offset.y);
        }
    }
}
