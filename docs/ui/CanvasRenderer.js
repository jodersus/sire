/**
 * CanvasRenderer.ts
 * Setup del canvas, loop de renderizado, resize y limpieza.
 */
import { drawHexGrid } from './HexRenderer.js';
export class CanvasRenderer {
    canvas;
    ctx;
    state;
    running = false;
    animFrameId = 0;
    dpr;
    constructor(container, state) {
        this.canvas = document.createElement('canvas');
        this.canvas.style.display = 'block';
        this.canvas.style.width = '100%';
        this.canvas.style.height = '100%';
        container.appendChild(this.canvas);
        const ctx = this.canvas.getContext('2d');
        if (!ctx)
            throw new Error('Canvas 2D not supported');
        this.ctx = ctx;
        this.state = state;
        this.dpr = window.devicePixelRatio || 1;
        this.resize();
        window.addEventListener('resize', this.resize);
    }
    /** Ajusta el tamaño interno del canvas al contenedor y DPR. */
    resize = () => {
        const parent = this.canvas.parentElement;
        if (!parent)
            return;
        const w = parent.clientWidth;
        const h = parent.clientHeight;
        this.canvas.width = Math.floor(w * this.dpr);
        this.canvas.height = Math.floor(h * this.dpr);
        this.canvas.style.width = `${w}px`;
        this.canvas.style.height = `${h}px`;
        // Reset transform para no acumular
        this.ctx.setTransform(1, 0, 0, 1, 0, 0);
        this.ctx.scale(this.dpr, this.dpr);
    };
    /** Inicia el loop de renderizado. */
    start() {
        if (this.running)
            return;
        this.running = true;
        this.loop();
    }
    /** Detiene el loop. */
    stop() {
        this.running = false;
        cancelAnimationFrame(this.animFrameId);
    }
    loop = () => {
        if (!this.running)
            return;
        this.render();
        this.animFrameId = requestAnimationFrame(this.loop);
    };
    render() {
        const { width, height } = this.canvas;
        const { cells, camera, hud } = this.state;
        // Limpiar
        this.ctx.save();
        this.ctx.setTransform(1, 0, 0, 1, 0, 0);
        this.ctx.clearRect(0, 0, width, height);
        this.ctx.restore();
        // Fondo oscuro base
        this.ctx.save();
        this.ctx.fillStyle = '#1a1a2e';
        this.ctx.fillRect(0, 0, width / this.dpr, height / this.dpr);
        this.ctx.restore();
        // Capa mundo (cámara transforma)
        this.ctx.save();
        camera.apply(this.ctx);
        drawHexGrid(this.ctx, camera, cells);
        this.ctx.restore();
        // Capa UI (sin transformación de cámara)
        hud.draw(this.ctx, width / this.dpr, height / this.dpr);
    }
    getCanvas() {
        return this.canvas;
    }
    destroy() {
        this.stop();
        window.removeEventListener('resize', this.resize);
        this.canvas.remove();
    }
}
