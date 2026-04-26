/**
 * HUD.ts
 * Interfaz en Canvas 2D. Muestra recursos, turno, fase, acciones.
 */

import { Camera } from './Camera.js';
import { TurnPhase } from '../game/GameState.js';
import type { GameControllerState } from '../game/GameController.js';

export class HUD {
  private camera: Camera;
  private state: GameControllerState | null = null;
  private logMessages: string[] = [];
  private maxLogLines = 6;

  // Callbacks para botones
  onEndTurn?: () => void;
  onTrainUnit?: (unitType: string) => void;
  onFoundCity?: () => void;
  onResearchTech?: (techId: string) => void;
  onAdvancePhase?: () => void;

  // Hit areas para clicks
  private buttons: { x: number; y: number; w: number; h: number; action: string; data?: string }[] = [];

  constructor(camera: Camera) {
    this.camera = camera;
  }

  updateState(state: GameControllerState): void {
    this.state = state;
  }

  addLog(msg: string): void {
    this.logMessages.push(msg);
    if (this.logMessages.length > this.maxLogLines) {
      this.logMessages.shift();
    }
  }

  clearButtons(): void {
    this.buttons = [];
  }

  getButtonAt(x: number, y: number): { action: string; data?: string } | null {
    for (const btn of this.buttons) {
      if (x >= btn.x && x <= btn.x + btn.w && y >= btn.y && y <= btn.y + btn.h) {
        return { action: btn.action, data: btn.data };
      }
    }
    return null;
  }

  draw(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    this.buttons = [];
    ctx.save();
    ctx.font = '13px sans-serif';
    ctx.textBaseline = 'middle';

    this.drawTopBar(ctx, width);
    this.drawSidePanel(ctx, width, height);
    this.drawBottomBar(ctx, width, height);
    this.drawTurnBadge(ctx, width);

    ctx.restore();
  }

  private drawTopBar(ctx: CanvasRenderingContext2D, width: number): void {
    const h = 42;
    const p = 12;

    ctx.fillStyle = 'rgba(15,23,42,0.92)';
    ctx.fillRect(0, 0, width, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.12)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, h);
    ctx.lineTo(width, h);
    ctx.stroke();

    if (!this.state) return;
    const player = this.state.currentPlayer;
    const tribe = player.tribe;

    ctx.fillStyle = tribe.color;
    ctx.beginPath();
    ctx.arc(p + 10, h / 2, 8, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#e2e8f0';
    ctx.font = 'bold 13px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(`${player.name} — ${tribe.name}`, p + 26, h / 2);

    const res = player.resources;
    ctx.font = '12px sans-serif';
    let x = p + 26 + ctx.measureText(`${player.name} — ${tribe.name}`).width + 32;

    const items = [
      { label: `⭐ ${res.stars}`, color: '#FFD600' },
      { label: `🌲 ${res.wood}`, color: '#66BB6A' },
      { label: `🪨 ${res.stone}`, color: '#90A4AE' },
      { label: `🍎 ${res.fruits}`, color: '#EF5350' },
      { label: `🐟 ${res.fish}`, color: '#42A5F5' },
    ];

    for (const item of items) {
      ctx.fillStyle = item.color;
      ctx.fillText(item.label, x, h / 2);
      x += ctx.measureText(item.label).width + 20;
    }

    // Unidades y ciudades
    ctx.fillStyle = '#94a3b8';
    ctx.fillText(`⚔ ${player.units.length}  🏛 ${player.cities.length}`, x, h / 2);
  }

  private drawSidePanel(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    const w = 200;
    const top = 50;
    const p = 12;

    ctx.fillStyle = 'rgba(15,23,42,0.90)';
    ctx.fillRect(width - w, top, w, height - top - 100);
    ctx.strokeStyle = 'rgba(255,255,255,0.10)';
    ctx.lineWidth = 1;
    ctx.strokeRect(width - w, top, w, height - top - 100);

    if (!this.state) return;

    let y = top + p + 8;
    ctx.fillStyle = '#e2e8f0';
    ctx.font = 'bold 13px sans-serif';
    ctx.textAlign = 'left';

    // Info selección
    if (this.state.selectedUnitId) {
      const unit = this.state.gameState.players[this.state.currentPlayer.id]?.units.find(u => u.id === this.state!.selectedUnitId);
      if (unit) {
        const def = { name: 'Unidad', attack: 0, defense: 0, movement: 0 }; // simplificado
        ctx.fillText(`Unidad seleccionada`, width - w + p, y);
        y += 22;
        ctx.font = '11px sans-serif';
        ctx.fillStyle = '#94a3b8';
        ctx.fillText(`Vida: ${unit.health}/${unit.maxHealth}`, width - w + p, y);
        y += 18;
        ctx.fillText(`Mov: ${unit.movementRemaining}`, width - w + p, y);
        y += 22;
      }
    } else if (this.state.selectedCityId) {
      const city = this.state.gameState.players[this.state.currentPlayer.id]?.cities.find(c => c.id === this.state!.selectedCityId);
      if (city) {
        ctx.fillText(city.name, width - w + p, y);
        y += 22;
        ctx.font = '11px sans-serif';
        ctx.fillStyle = '#94a3b8';
        ctx.fillText(`Nivel ${city.level} — ${city.population} pob`, width - w + p, y);
        y += 18;
        ctx.fillText(`Ingreso: ${city.level * 2 + city.population}⭐`, width - w + p, y);
        y += 22;

        // Botón entrenar
        if (this.state.phase === TurnPhase.BUILD) {
          this.drawButton(ctx, width - w + p, y, w - p * 2, 28, 'Entrenar Guerrero', 'train_warrior');
          y += 36;
        }
      }
    } else {
      ctx.fillStyle = '#64748b';
      ctx.font = '12px sans-serif';
      ctx.fillText('Selecciona unidad o ciudad', width - w + p, y);
      y += 20;
    }

    // Botón fundar ciudad (si unidad exploradora seleccionada)
    if (this.state.phase === TurnPhase.BUILD && this.state.selectedUnitId) {
      const unit = this.state.gameState.players[this.state.currentPlayer.id]?.units.find(u => u.id === this.state!.selectedUnitId);
      if (unit && unit.type === 'explorer') {
        this.drawButton(ctx, width - w + p, y, w - p * 2, 28, 'Fundar Ciudad (5⭐)', 'found_city');
        y += 36;
      }
    }
  }

  private drawBottomBar(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    const h = 90;
    const p = 12;
    const y = height - h;

    ctx.fillStyle = 'rgba(15,23,42,0.92)';
    ctx.fillRect(0, y, width, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.10)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();

    // Log de eventos
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'left';
    let ly = y + 16;
    for (const msg of this.logMessages) {
      ctx.fillStyle = '#94a3b8';
      ctx.fillText(`› ${msg}`, p, ly);
      ly += 16;
    }

    // Botón fin de turno / siguiente fase
    const btnW = 120;
    const btnH = 32;
    const btnX = width - btnW - p;
    const btnY = y + (h - btnH) / 2;

    if (this.state?.isHumanTurn) {
      const label = this.state.phase === TurnPhase.END ? 'Fin de Turno' : 'Siguiente Fase';
      this.drawButton(ctx, btnX, btnY, btnW, btnH, label, 'advance');
    } else {
      ctx.fillStyle = '#64748b';
      ctx.font = '12px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('Turno del oponente...', btnX + btnW / 2, btnY + btnH / 2);
      ctx.textAlign = 'left';
    }
  }

  private drawTurnBadge(ctx: CanvasRenderingContext2D, width: number): void {
    if (!this.state) return;
    const label = `Turno ${this.state.gameState.currentTurn} — ${this.phaseLabel(this.state.phase)}`;
    ctx.font = 'bold 13px sans-serif';
    const tw = ctx.measureText(label).width;
    const pad = 10;
    const h = 26;
    const x = (width - tw) / 2 - pad;
    const y = 52;

    ctx.fillStyle = 'rgba(15,23,42,0.90)';
    ctx.fillRect(x, y, tw + pad * 2, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, tw + pad * 2, h);

    ctx.fillStyle = '#e2e8f0';
    ctx.textAlign = 'center';
    ctx.fillText(label, width / 2, y + h / 2 + 1);
    ctx.textAlign = 'left';
  }

  private drawButton(
    ctx: CanvasRenderingContext2D,
    x: number, y: number, w: number, h: number,
    text: string, action: string, data?: string
  ): void {
    ctx.fillStyle = 'rgba(255,255,255,0.10)';
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.20)';
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, h);

    ctx.fillStyle = '#e2e8f0';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, x + w / 2, y + h / 2);
    ctx.textAlign = 'left';

    this.buttons.push({ x, y, w, h, action, data });
  }

  private phaseLabel(phase: TurnPhase): string {
    const labels: Record<TurnPhase, string> = {
      [TurnPhase.INCOME]: 'Ingresos',
      [TurnPhase.TECHNOLOGY]: 'Tecnología',
      [TurnPhase.MOVE]: 'Movimiento',
      [TurnPhase.COMBAT]: 'Combate',
      [TurnPhase.BUILD]: 'Construcción',
      [TurnPhase.END]: 'Fin',
    };
    return labels[phase] ?? phase;
  }
}
