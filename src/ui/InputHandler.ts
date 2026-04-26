/**
 * InputHandler.ts
 * Maneja click, drag, scroll y selección de hexágonos.
 */

import { Camera } from './Camera.js';
import { pixelToAxial } from './HexRenderer.js';

export interface InputCallbacks {
  onHexClick?: (q: number, r: number, cell?: unknown) => void;
  onHexHover?: (q: number, r: number, cell?: unknown) => void;
  onPan?: (dx: number, dy: number) => void;
  onZoom?: (screenX: number, screenY: number, delta: number) => void;
  onContextMenu?: (q: number, r: number, cell?: unknown) => void;
}

export class InputHandler {
  private canvas: HTMLCanvasElement;
  private camera: Camera;
  private cells: Map<string, unknown> = new Map();
  private callbacks: InputCallbacks;

  private dragging = false;
  private dragStartX = 0;
  private dragStartY = 0;
  private lastX = 0;
  private lastY = 0;
  private dragThreshold = 4; // px antes de considerar drag

  constructor(
    canvas: HTMLCanvasElement,
    camera: Camera,
    callbacks: InputCallbacks,
  ) {
    this.canvas = canvas;
    this.camera = camera;
    this.callbacks = callbacks;

    this.bindEvents();
  }

  /** Actualiza el mapa de celdas para lookup rápido de hover/click. Opcional. */
  setCells(cells: { q: number; r: number }[]): void {
    this.cells.clear();
    for (const c of cells) {
      this.cells.set(`${c.q},${c.r}`, c);
    }
  }

  private bindEvents(): void {
    const c = this.canvas;
    c.addEventListener('mousedown', this.onMouseDown);
    c.addEventListener('mousemove', this.onMouseMove);
    c.addEventListener('mouseup', this.onMouseUp);
    c.addEventListener('mouseleave', this.onMouseUp);
    c.addEventListener('wheel', this.onWheel, { passive: false });
    c.addEventListener('contextmenu', this.onContextMenu);

    // Touch support básico
    c.addEventListener('touchstart', this.onTouchStart, { passive: false });
    c.addEventListener('touchmove', this.onTouchMove, { passive: false });
    c.addEventListener('touchend', this.onTouchEnd, { passive: false });
  }

  private getMousePos(e: MouseEvent): { x: number; y: number } {
    const rect = this.canvas.getBoundingClientRect();
    return {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
    };
  }

  private onMouseDown = (e: MouseEvent): void => {
    if (e.button !== 0) return; // solo click izquierdo
    const { x, y } = this.getMousePos(e);
    this.dragging = false;
    this.dragStartX = x;
    this.dragStartY = y;
    this.lastX = x;
    this.lastY = y;
  };

  private onMouseMove = (e: MouseEvent): void => {
    const { x, y } = this.getMousePos(e);

    // Hover
    const world = this.camera.screenToWorld(x, y);
    const { q, r } = pixelToAxial(world.x, world.y);
    const cell = this.cells.get(`${q},${r}`);
    this.callbacks.onHexHover?.(q, r, cell);

    // Drag pan
    if (this.dragStartX !== this.lastX || this.dragStartY !== this.lastY || Math.hypot(x - this.dragStartX, y - this.dragStartY) > this.dragThreshold) {
      this.dragging = true;
    }
    if (this.dragging) {
      const dx = x - this.lastX;
      const dy = y - this.lastY;
      this.callbacks.onPan?.(dx, dy);
    }
    this.lastX = x;
    this.lastY = y;
  };

  private onMouseUp = (e: MouseEvent): void => {
    if (!this.dragging) {
      // Fue un click simple
      const { x, y } = this.getMousePos(e);
      const world = this.camera.screenToWorld(x, y);
      const { q, r } = pixelToAxial(world.x, world.y);
      const cell = this.cells.get(`${q},${r}`);
      this.callbacks.onHexClick?.(q, r, cell);
    }
    this.dragging = false;
    this.dragStartX = this.lastX;
    this.dragStartY = this.lastY;
  };

  private onWheel = (e: WheelEvent): void => {
    e.preventDefault();
    const { x, y } = this.getMousePos(e);
    // Normalizar delta: wheel up = zoom in (+), wheel down = zoom out (-)
    const delta = -e.deltaY * 0.001;
    this.callbacks.onZoom?.(x, y, delta);
  };

  private onContextMenu = (e: MouseEvent): void => {
    e.preventDefault();
    const { x, y } = this.getMousePos(e);
    const world = this.camera.screenToWorld(x, y);
    const { q, r } = pixelToAxial(world.x, world.y);
    const cell = this.cells.get(`${q},${r}`);
    this.callbacks.onContextMenu?.(q, r, cell);
  };

  // Touch handlers (map to mouse logic)
  private activeTouchId: number | null = null;

  private onTouchStart = (e: TouchEvent): void => {
    if (e.touches.length === 1) {
      const t = e.touches[0];
      this.activeTouchId = t.identifier;
      const rect = this.canvas.getBoundingClientRect();
      const x = t.clientX - rect.left;
      const y = t.clientY - rect.top;
      this.dragging = false;
      this.dragStartX = x;
      this.dragStartY = y;
      this.lastX = x;
      this.lastY = y;
    }
  };

  private onTouchMove = (e: TouchEvent): void => {
    if (e.touches.length === 1 && this.activeTouchId !== null) {
      const t = e.touches[0];
      if (t.identifier !== this.activeTouchId) return;
      const rect = this.canvas.getBoundingClientRect();
      const x = t.clientX - rect.left;
      const y = t.clientY - rect.top;
      const dist = Math.hypot(x - this.dragStartX, y - this.dragStartY);
      if (dist > this.dragThreshold) this.dragging = true;
      if (this.dragging) {
        this.callbacks.onPan?.(x - this.lastX, y - this.lastY);
      }
      this.lastX = x;
      this.lastY = y;
    }
  };

  private onTouchEnd = (e: TouchEvent): void => {
    if (!this.dragging && this.activeTouchId !== null) {
      const rect = this.canvas.getBoundingClientRect();
      // Use last known position
      const world = this.camera.screenToWorld(this.lastX, this.lastY);
      const { q, r } = pixelToAxial(world.x, world.y);
      const cell = this.cells.get(`${q},${r}`);
      this.callbacks.onHexClick?.(q, r, cell);
    }
    this.dragging = false;
    this.activeTouchId = null;
  };

  destroy(): void {
    const c = this.canvas;
    c.removeEventListener('mousedown', this.onMouseDown);
    c.removeEventListener('mousemove', this.onMouseMove);
    c.removeEventListener('mouseup', this.onMouseUp);
    c.removeEventListener('mouseleave', this.onMouseUp);
    c.removeEventListener('wheel', this.onWheel);
    c.removeEventListener('contextmenu', this.onContextMenu);
    c.removeEventListener('touchstart', this.onTouchStart);
    c.removeEventListener('touchmove', this.onTouchMove);
    c.removeEventListener('touchend', this.onTouchEnd);
  }
}
