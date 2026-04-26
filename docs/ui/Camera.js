/**
 * Camera.ts
 * Sistema de cámara 2D: pan, zoom, transformaciones de coordenadas mundo-pantalla.
 */
export class Camera {
    x = 0;
    y = 0;
    zoom = 1;
    // Limites del mundo (en unidades de hexágonos aprox)
    minX = -1000;
    minY = -1000;
    maxX = 1000;
    maxY = 1000;
    // Zoom limits
    minZoom = 0.3;
    maxZoom = 3.0;
    constructor(initial = {}) {
        this.x = initial.x ?? 0;
        this.y = initial.y ?? 0;
        this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, initial.zoom ?? 1));
    }
    /** Establece los límites del mundo. */
    setBounds(minX, minY, maxX, maxY) {
        this.minX = minX;
        this.minY = minY;
        this.maxX = maxX;
        this.maxY = maxY;
        this.clamp();
    }
    /** Pan relativo en píxeles de pantalla. */
    pan(dx, dy) {
        this.x -= dx / this.zoom;
        this.y -= dy / this.zoom;
        this.clamp();
    }
    /** Zoom con punto de anclaje en coordenadas de pantalla. */
    zoomAt(screenX, screenY, delta) {
        const oldZoom = this.zoom;
        const newZoom = Math.max(this.minZoom, Math.min(this.maxZoom, oldZoom + delta));
        if (newZoom === oldZoom)
            return;
        // Zoom hacia el cursor: ajustar offset para que el punto bajo el ratón quede fijo
        const worldX = (screenX - this.x * oldZoom) / oldZoom;
        const worldY = (screenY - this.y * oldZoom) / oldZoom;
        this.x = (screenX / newZoom) - worldX;
        this.y = (screenY / newZoom) - worldY;
        this.zoom = newZoom;
        this.clamp();
    }
    /** Set zoom directo (ej: minimapa). */
    setZoom(z) {
        this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, z));
        this.clamp();
    }
    /** Transforma coordenadas mundo a pantalla. */
    worldToScreen(wx, wy) {
        return {
            x: (wx - this.x) * this.zoom,
            y: (wy - this.y) * this.zoom,
        };
    }
    /** Transforma coordenadas pantalla a mundo. */
    screenToWorld(sx, sy) {
        return {
            x: sx / this.zoom + this.x,
            y: sy / this.zoom + this.y,
        };
    }
    /** Escala un valor de mundo a pantalla. */
    scale(value) {
        return value * this.zoom;
    }
    /** Aplica la transformación al contexto 2D. */
    apply(ctx) {
        ctx.scale(this.zoom, this.zoom);
        ctx.translate(-this.x, -this.y);
    }
    getState() {
        return { x: this.x, y: this.y, zoom: this.zoom };
    }
    clamp() {
        // Margen extra para no quedar atascado en bordes
        const margin = 200;
        this.x = Math.max(this.minX - margin, Math.min(this.maxX + margin, this.x));
        this.y = Math.max(this.minY - margin, Math.min(this.maxY + margin, this.y));
    }
}
