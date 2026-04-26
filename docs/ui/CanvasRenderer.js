/**
 * CanvasRenderer.ts
 * Loop de renderizado con soporte para wrap-around esférico.
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
        this.ctx.setTransform(1, 0, 0, 1, 0, 0);
        this.ctx.scale(this.dpr, this.dpr);
    };
    start() {
        if (this.running)
            return;
        this.running = true;
        this.loop();
    }
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
        const { cells, camera, hud, worldWidth, worldHeight } = this.state;
        this.ctx.save();
        this.ctx.setTransform(1, 0, 0, 1, 0, 0);
        this.ctx.clearRect(0, 0, width, height);
        this.ctx.restore();
        // Fondo
        this.ctx.save();
        this.ctx.fillStyle = '#0f172a';
        this.ctx.fillRect(0, 0, width / this.dpr, height / this.dpr);
        this.ctx.restore();
        // Capa mundo
        this.ctx.save();
        camera.apply(this.ctx);
        drawHexGrid(this.ctx, camera, cells, worldWidth, worldHeight);
        this.ctx.restore();
        // Capa UI
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
