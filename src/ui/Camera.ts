/**
 * Camera.ts
 * Sistema de cámara 2D: pan, zoom, transformaciones de coordenadas mundo-pantalla.
 */

export interface CameraState {
  x: number;
  y: number;
  zoom: number;
}

export class Camera {
  private x: number = 0;
  private y: number = 0;
  private zoom: number = 1;

  // Limites del mundo (en unidades de hexágonos aprox)
  private minX: number = -1000;
  private minY: number = -1000;
  private maxX: number = 1000;
  private maxY: number = 1000;

  // Zoom limits
  private minZoom: number = 0.3;
  private maxZoom: number = 3.0;

  constructor(initial: Partial<CameraState> = {}) {
    this.x = initial.x ?? 0;
    this.y = initial.y ?? 0;
    this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, initial.zoom ?? 1));
  }

  /** Establece los límites del mundo. */
  setBounds(minX: number, minY: number, maxX: number, maxY: number): void {
    this.minX = minX;
    this.minY = minY;
    this.maxX = maxX;
    this.maxY = maxY;
    this.clamp();
  }

  /** Pan relativo en píxeles de pantalla. */
  pan(dx: number, dy: number): void {
    this.x -= dx / this.zoom;
    this.y -= dy / this.zoom;
    this.clamp();
  }

  /** Zoom con punto de anclaje en coordenadas de pantalla. */
  zoomAt(screenX: number, screenY: number, delta: number): void {
    const oldZoom = this.zoom;
    const newZoom = Math.max(this.minZoom, Math.min(this.maxZoom, oldZoom + delta));
    if (newZoom === oldZoom) return;

    // Zoom hacia el cursor: ajustar offset para que el punto bajo el ratón quede fijo
    const worldX = (screenX - this.x * oldZoom) / oldZoom;
    const worldY = (screenY - this.y * oldZoom) / oldZoom;

    this.x = (screenX / newZoom) - worldX;
    this.y = (screenY / newZoom) - worldY;
    this.zoom = newZoom;
    this.clamp();
  }

  /** Set zoom directo (ej: minimapa). */
  setZoom(z: number): void {
    this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, z));
    this.clamp();
  }

  /** Transforma coordenadas mundo a pantalla. */
  worldToScreen(wx: number, wy: number): { x: number; y: number } {
    return {
      x: (wx - this.x) * this.zoom,
      y: (wy - this.y) * this.zoom,
    };
  }

  /** Transforma coordenadas pantalla a mundo. */
  screenToWorld(sx: number, sy: number): { x: number; y: number } {
    return {
      x: sx / this.zoom + this.x,
      y: sy / this.zoom + this.y,
    };
  }

  /** Escala un valor de mundo a pantalla. */
  scale(value: number): number {
    return value * this.zoom;
  }

  /** Aplica la transformación al contexto 2D. */
  apply(ctx: CanvasRenderingContext2D): void {
    ctx.scale(this.zoom, this.zoom);
    ctx.translate(-this.x, -this.y);
  }

  getState(): CameraState {
    return { x: this.x, y: this.y, zoom: this.zoom };
  }

  private clamp(): void {
    // Margen extra para no quedar atascado en bordes
    const margin = 200;
    this.x = Math.max(this.minX - margin, Math.min(this.maxX + margin, this.x));
    this.y = Math.max(this.minY - margin, Math.min(this.maxY + margin, this.y));
  }
}
