/**
 * InputHandler.ts
 * Maneja click, drag, scroll y selección de hexágonos.
 */
import { pixelToAxial } from './HexRenderer.js';
export class InputHandler {
    canvas;
    camera;
    cells = new Map();
    callbacks;
    isMouseDown = false;
    dragging = false;
    dragStartX = 0;
    dragStartY = 0;
    lastX = 0;
    lastY = 0;
    dragThreshold = 4; // px antes de considerar drag
    constructor(canvas, camera, callbacks) {
        this.canvas = canvas;
        this.camera = camera;
        this.callbacks = callbacks;
        this.bindEvents();
    }
    /** Actualiza el mapa de celdas para lookup rápido de hover/click. Opcional. */
    setCells(cells) {
        this.cells.clear();
        for (const c of cells) {
            this.cells.set(`${c.q},${c.r}`, c);
        }
    }
    bindEvents() {
        const c = this.canvas;
        c.addEventListener('mousedown', this.onMouseDown);
        c.addEventListener('mousemove', this.onMouseMove);
        c.addEventListener('mouseup', this.onMouseUp);
        c.addEventListener('mouseleave', this.onMouseLeave);
        c.addEventListener('wheel', this.onWheel, { passive: false });
        c.addEventListener('contextmenu', this.onContextMenu);
        // Touch support básico
        c.addEventListener('touchstart', this.onTouchStart, { passive: false });
        c.addEventListener('touchmove', this.onTouchMove, { passive: false });
        c.addEventListener('touchend', this.onTouchEnd, { passive: false });
    }
    getMousePos(e) {
        const rect = this.canvas.getBoundingClientRect();
        return {
            x: e.clientX - rect.left,
            y: e.clientY - rect.top,
        };
    }
    onMouseDown = (e) => {
        if (e.button !== 0)
            return; // solo click izquierdo
        this.isMouseDown = true;
        this.dragging = false;
        const { x, y } = this.getMousePos(e);
        this.dragStartX = x;
        this.dragStartY = y;
        this.lastX = x;
        this.lastY = y;
    };
    onMouseMove = (e) => {
        const { x, y } = this.getMousePos(e);
        // Hover (siempre activo)
        const world = this.camera.screenToWorld(x, y);
        const { q, r } = pixelToAxial(world.x, world.y);
        const cell = this.cells.get(`${q},${r}`);
        this.callbacks.onHexHover?.(q, r, cell);
        // Solo procesar drag si el botón está presionado
        if (!this.isMouseDown)
            return;
        // Drag pan
        const dist = Math.hypot(x - this.dragStartX, y - this.dragStartY);
        if (dist > this.dragThreshold) {
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
    onMouseUp = (e) => {
        if (!this.dragging && this.isMouseDown) {
            // Fue un click simple
            const { x, y } = this.getMousePos(e);
            const world = this.camera.screenToWorld(x, y);
            const { q, r } = pixelToAxial(world.x, world.y);
            const cell = this.cells.get(`${q},${r}`);
            this.callbacks.onHexClick?.(q, r, cell);
        }
        this.isMouseDown = false;
        this.dragging = false;
    };
    onMouseLeave = () => {
        this.isMouseDown = false;
        this.dragging = false;
    };
    onWheel = (e) => {
        e.preventDefault();
        const { x, y } = this.getMousePos(e);
        // Normalizar delta: wheel up = zoom in (+), wheel down = zoom out (-)
        const delta = -e.deltaY * 0.001;
        this.callbacks.onZoom?.(x, y, delta);
    };
    onContextMenu = (e) => {
        e.preventDefault();
        const { x, y } = this.getMousePos(e);
        const world = this.camera.screenToWorld(x, y);
        const { q, r } = pixelToAxial(world.x, world.y);
        const cell = this.cells.get(`${q},${r}`);
        this.callbacks.onContextMenu?.(q, r, cell);
    };
    // Touch handlers (map to mouse logic)
    activeTouchId = null;
    onTouchStart = (e) => {
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
    onTouchMove = (e) => {
        if (e.touches.length === 1 && this.activeTouchId !== null) {
            const t = e.touches[0];
            if (t.identifier !== this.activeTouchId)
                return;
            const rect = this.canvas.getBoundingClientRect();
            const x = t.clientX - rect.left;
            const y = t.clientY - rect.top;
            const dist = Math.hypot(x - this.dragStartX, y - this.dragStartY);
            if (dist > this.dragThreshold)
                this.dragging = true;
            if (this.dragging) {
                this.callbacks.onPan?.(x - this.lastX, y - this.lastY);
            }
            this.lastX = x;
            this.lastY = y;
        }
    };
    onTouchEnd = (e) => {
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
    destroy() {
        const c = this.canvas;
        c.removeEventListener('mousedown', this.onMouseDown);
        c.removeEventListener('mousemove', this.onMouseMove);
        c.removeEventListener('mouseup', this.onMouseUp);
        c.removeEventListener('mouseleave', this.onMouseLeave);
        c.removeEventListener('wheel', this.onWheel);
        c.removeEventListener('contextmenu', this.onContextMenu);
        c.removeEventListener('touchstart', this.onTouchStart);
        c.removeEventListener('touchmove', this.onTouchMove);
        c.removeEventListener('touchend', this.onTouchEnd);
    }
}
