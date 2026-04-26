/**
 * HUD.ts
 * Interfaz de usuario: panel superior (recursos), panel lateral (acciones), minimapa, tecnologías.
 * Todo dibujado en Canvas 2D. Paneles oscuros semitransparentes.
 */

import { Camera } from './Camera.js';

export interface HUDState {
  turn: number;
  resources: Record<string, number>;
  selectedHex: { q: number; r: number } | null;
  availableActions: string[];
  techsUnlocked: string[];
  techsAvailable: string[];
}

export class HUD {
  private state: HUDState;
  private camera: Camera;
  private minimapSize = 120;
  private padding = 12;
  private panelAlpha = 0.85;

  constructor(initial: Partial<HUDState> = {}, camera: Camera) {
    this.state = {
      turn: 1,
      resources: {},
      selectedHex: null,
      availableActions: [],
      techsUnlocked: [],
      techsAvailable: [],
      ...initial,
    };
    this.camera = camera;
  }

  update(partial: Partial<HUDState>): void {
    this.state = { ...this.state, ...partial };
  }

  /** Dibuja todo el HUD sobre el canvas. */
  draw(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    ctx.save();
    ctx.font = '14px sans-serif';
    ctx.textBaseline = 'middle';

    this.drawTopBar(ctx, width);
    this.drawSidePanel(ctx, width, height);
    this.drawMinimap(ctx, width, height);
    this.drawTurnIndicator(ctx, width);

    ctx.restore();
  }

  private drawTopBar(ctx: CanvasRenderingContext2D, width: number): void {
    const h = 40;
    const p = this.padding;

    // Fondo
    ctx.fillStyle = `rgba(15,23,42,${this.panelAlpha})`;
    ctx.fillRect(0, 0, width, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, h);
    ctx.lineTo(width, h);
    ctx.stroke();

    // Recursos
    ctx.fillStyle = '#e2e8f0';
    const resources = this.state.resources;
    let x = p;
    const items = Object.entries(resources);
    for (const [name, val] of items) {
      const label = `${name}: ${val}`;
      ctx.fillText(label, x, h / 2);
      x += ctx.measureText(label).width + 24;
    }

    if (items.length === 0) {
      ctx.fillText('Sin recursos visibles', x, h / 2);
    }
  }

  private drawSidePanel(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    const w = 180;
    const top = 48;
    const p = this.padding;

    // Panel
    ctx.fillStyle = `rgba(15,23,42,${this.panelAlpha})`;
    ctx.fillRect(width - w, top, w, height - top - this.minimapSize - 8);
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    ctx.strokeRect(width - w, top, w, height - top - this.minimapSize - 8);

    ctx.fillStyle = '#e2e8f0';
    let y = top + p + 10;

    // Título selección
    if (this.state.selectedHex) {
      const { q, r } = this.state.selectedHex;
      ctx.font = 'bold 14px sans-serif';
      ctx.fillText(`Hex (${q},${r})`, width - w + p, y);
      y += 24;

      // Acciones disponibles
      ctx.font = '12px sans-serif';
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('Acciones:', width - w + p, y);
      y += 18;

      ctx.fillStyle = '#e2e8f0';
      for (const action of this.state.availableActions) {
        // Fondo de botón sutil
        ctx.fillStyle = 'rgba(255,255,255,0.08)';
        const btnH = 26;
        ctx.fillRect(width - w + p, y - 10, w - p * 2, btnH);
        ctx.strokeStyle = 'rgba(255,255,255,0.12)';
        ctx.strokeRect(width - w + p, y - 10, w - p * 2, btnH);

        ctx.fillStyle = '#e2e8f0';
        ctx.fillText(`▸ ${action}`, width - w + p + 6, y + 3);
        y += 34;
      }

      if (this.state.availableActions.length === 0) {
        ctx.fillStyle = '#64748b';
        ctx.fillText('Ninguna', width - w + p + 6, y + 3);
        y += 20;
      }
    } else {
      ctx.font = '13px sans-serif';
      ctx.fillStyle = '#64748b';
      ctx.fillText('Selecciona un hex', width - w + p, y);
    }
  }

  private drawMinimap(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    const size = this.minimapSize;
    const x = width - size - this.padding;
    const y = height - size - this.padding;

    // Fondo
    ctx.fillStyle = `rgba(15,23,42,${this.panelAlpha})`;
    ctx.fillRect(x, y, size, size);
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, size, size);

    // Marco de vista de cámara (placeholder: centrado)
    const cam = this.camera.getState();
    const inner = size - 8;
    const vpW = inner / (cam.zoom * 2);
    const vpH = inner / (cam.zoom * 2);
    const vpX = x + 4 + (inner - vpW) / 2;
    const vpY = y + 4 + (inner - vpH) / 2;

    ctx.strokeStyle = 'rgba(255,255,255,0.6)';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(vpX, vpY, vpW, vpH);

    ctx.fillStyle = '#94a3b8';
    ctx.font = '10px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('minimapa', x + size / 2, y + size / 2);
    ctx.textAlign = 'left';
  }

  private drawTurnIndicator(ctx: CanvasRenderingContext2D, width: number): void {
    const turn = this.state.turn;
    const label = `Turno ${turn}`;
    ctx.font = 'bold 14px sans-serif';
    const tw = ctx.measureText(label).width;
    const x = (width - tw) / 2;
    const y = 64;

    // Badge
    const pad = 8;
    ctx.fillStyle = `rgba(15,23,42,${this.panelAlpha})`;
    ctx.fillRect(x - pad, y - 12, tw + pad * 2, 24);
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x - pad, y - 12, tw + pad * 2, 24);

    ctx.fillStyle = '#e2e8f0';
    ctx.textAlign = 'center';
    ctx.fillText(label, width / 2, y);
    ctx.textAlign = 'left';
  }
}
