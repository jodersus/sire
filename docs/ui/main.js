/**
 * main.ts — Punto de entrada del juego Sire
 * Integra auth, game controller, renderer e input.
 */
import { Camera } from './Camera.js';
import { CanvasRenderer } from './CanvasRenderer.js';
import { InputHandler } from './InputHandler.js';
import { HUD } from './HUD.js';
import { GameController } from '../game/GameController.js';
import { TurnPhase } from '../game/GameState.js';
import { UnitType } from '../game/Units.js';
// ─── Auth (protección básica) ─────────────────────────────────────────────
const AUTH_KEY = 'sire_auth_token';
const ACCESS_TOKEN = 'REDACTED_TOKEN'; // token simple para pruebas privadas
function checkAuth() {
    try {
        return localStorage.getItem(AUTH_KEY) === ACCESS_TOKEN ||
            sessionStorage.getItem(AUTH_KEY) === ACCESS_TOKEN;
    }
    catch {
        return false;
    }
}
function setAuth(persistent) {
    try {
        if (persistent)
            localStorage.setItem(AUTH_KEY, ACCESS_TOKEN);
        else
            sessionStorage.setItem(AUTH_KEY, ACCESS_TOKEN);
    }
    catch { /* noop */ }
}
function showAuthScreen(onSuccess) {
    // Limpiar auth previo para forzar re-login
    try {
        localStorage.removeItem(AUTH_KEY);
        sessionStorage.removeItem(AUTH_KEY);
    }
    catch { /* noop */ }
    const container = document.getElementById('game-container');
    if (!container)
        return;
    container.innerHTML = '';
    const overlay = document.createElement('div');
    overlay.style.cssText = `
    display:flex;flex-direction:column;align-items:center;justify-content:center;
    width:100%;height:100%;background:#0f172a;color:#e2e8f0;font-family:sans-serif;
  `;
    const title = document.createElement('h1');
    title.textContent = 'SIRE';
    title.style.cssText = 'font-size:48px;margin-bottom:8px;letter-spacing:8px;color:#FFD54F;';
    const subtitle = document.createElement('p');
    subtitle.textContent = 'Estrategia por turnos en un mundo esférico';
    subtitle.style.cssText = 'color:#94a3b8;margin-bottom:32px;';
    const input = document.createElement('input');
    input.type = 'password';
    input.placeholder = 'Token de acceso';
    input.style.cssText = `
    padding:12px 16px;font-size:16px;border:1px solid rgba(255,255,255,0.2);
    border-radius:4px;background:rgba(255,255,255,0.05);color:#fff;width:240px;text-align:center;
  `;
    const error = document.createElement('p');
    error.style.cssText = 'color:#ef5350;height:20px;font-size:12px;margin-top:8px;';
    const btn = document.createElement('button');
    btn.textContent = 'Entrar';
    btn.style.cssText = `
    margin-top:16px;padding:12px 32px;font-size:14px;border:none;border-radius:4px;
    background:#FFD54F;color:#1a1a2e;cursor:pointer;font-weight:bold;
  `;
    const remember = document.createElement('label');
    remember.style.cssText = 'margin-top:16px;font-size:12px;color:#64748b;display:flex;align-items:center;gap:6px;';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    remember.appendChild(cb);
    remember.appendChild(document.createTextNode('Recordar en este dispositivo'));
    const tryAuth = () => {
        if (input.value.trim() === ACCESS_TOKEN) {
            setAuth(cb.checked);
            container.innerHTML = '';
            onSuccess();
        }
        else {
            error.textContent = 'Token inválido';
            input.style.borderColor = '#ef5350';
        }
    };
    btn.addEventListener('click', tryAuth);
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter')
        tryAuth(); });
    overlay.appendChild(title);
    overlay.appendChild(subtitle);
    overlay.appendChild(input);
    overlay.appendChild(error);
    overlay.appendChild(btn);
    overlay.appendChild(remember);
    container.appendChild(overlay);
    input.focus();
}
// ─── Setup Screen ──────────────────────────────────────────────────────────
function showSetupScreen(onStart) {
    const container = document.getElementById('game-container');
    if (!container)
        return;
    container.innerHTML = '';
    const overlay = document.createElement('div');
    overlay.style.cssText = `
    display:flex;flex-direction:column;align-items:center;justify-content:center;
    width:100%;height:100%;background:#0f172a;color:#e2e8f0;font-family:sans-serif;
  `;
    const title = document.createElement('h1');
    title.textContent = 'SIRE';
    title.style.cssText = 'font-size:48px;margin-bottom:8px;letter-spacing:8px;color:#FFD54F;';
    const subtitle = document.createElement('p');
    subtitle.textContent = 'Nueva partida';
    subtitle.style.cssText = 'color:#94a3b8;margin-bottom:32px;';
    // Selección de tribu
    const tribeLabel = document.createElement('p');
    tribeLabel.textContent = 'Elige tu tribu:';
    tribeLabel.style.cssText = 'margin-bottom:12px;color:#cbd5e1;';
    overlay.appendChild(tribeLabel);
    const tribes = [
        { id: 'solaris', name: 'Solaris', color: '#F4D03F', desc: '-20% coste tecnologías' },
        { id: 'umbra', name: 'Umbra', color: '#2C3E50', desc: '+1 visión' },
        { id: 'sylva', name: 'Sylva', color: '#27AE60', desc: '-30% coste madera' },
        { id: 'ferrum', name: 'Ferrum', color: '#922B21', desc: '+1 ataque' },
        { id: 'maris', name: 'Maris', color: '#3498DB', desc: 'Bono naval' },
        { id: 'equus', name: 'Equus', color: '#E67E22', desc: '+1 movimiento caballería' },
        { id: 'nomad', name: 'Nomad', color: '#8E44AD', desc: '+25% crecimiento ciudades' },
    ];
    let selectedTribe = 'solaris';
    const tribeButtons = [];
    const tribeRow = document.createElement('div');
    tribeRow.style.cssText = 'display:flex;gap:8px;flex-wrap:wrap;justify-content:center;max-width:500px;margin-bottom:24px;';
    for (const t of tribes) {
        const btn = document.createElement('button');
        btn.style.cssText = `
      padding:10px 16px;border:2px solid ${t.color};border-radius:4px;background:rgba(255,255,255,0.05);
      color:#e2e8f0;cursor:pointer;font-size:13px;min-width:100px;
    `;
        btn.innerHTML = `<div style="font-weight:bold;color:${t.color}">${t.name}</div><div style="font-size:10px;color:#94a3b8">${t.desc}</div>`;
        btn.addEventListener('click', () => {
            selectedTribe = t.id;
            for (const b of tribeButtons) {
                b.style.background = 'rgba(255,255,255,0.05)';
            }
            btn.style.background = `${t.color}22`;
        });
        tribeButtons.push(btn);
        tribeRow.appendChild(btn);
    }
    // Seleccionar primera por defecto
    tribeButtons[0].style.background = `${tribes[0].color}22`;
    overlay.appendChild(tribeRow);
    // Número de bots
    const botLabel = document.createElement('p');
    botLabel.textContent = 'Oponentes:';
    botLabel.style.cssText = 'margin-bottom:12px;color:#cbd5e1;';
    overlay.appendChild(botLabel);
    let numBots = 1;
    const botRow = document.createElement('div');
    botRow.style.cssText = 'display:flex;gap:8px;margin-bottom:32px;';
    const botOptions = [1, 2, 3];
    const botBtns = [];
    for (const n of botOptions) {
        const btn = document.createElement('button');
        btn.textContent = n === 1 ? '1 Bot' : `${n} Bots`;
        btn.style.cssText = `
      padding:8px 20px;border:1px solid rgba(255,255,255,0.2);border-radius:4px;
      background:rgba(255,255,255,0.05);color:#e2e8f0;cursor:pointer;font-size:13px;
    `;
        btn.addEventListener('click', () => {
            numBots = n;
            for (const b of botBtns)
                b.style.background = 'rgba(255,255,255,0.05)';
            btn.style.background = 'rgba(255,255,255,0.2)';
        });
        botBtns.push(btn);
        botRow.appendChild(btn);
    }
    botBtns[0].style.background = 'rgba(255,255,255,0.2)';
    overlay.appendChild(botRow);
    const startBtn = document.createElement('button');
    startBtn.textContent = 'Comenzar Partida';
    startBtn.style.cssText = `
    padding:14px 40px;font-size:16px;border:none;border-radius:4px;
    background:#FFD54F;color:#1a1a2e;cursor:pointer;font-weight:bold;
  `;
    startBtn.addEventListener('click', () => onStart(numBots, selectedTribe));
    overlay.appendChild(title);
    overlay.appendChild(subtitle);
    overlay.appendChild(startBtn);
    container.appendChild(overlay);
}
// ─── Game Loop ─────────────────────────────────────────────────────────────
let game = null;
let renderer = null;
let input = null;
let hud = null;
function startGame(numBots, humanTribe) {
    const container = document.getElementById('game-container');
    if (!container)
        return;
    container.innerHTML = '';
    // Configurar jugadores
    const configs = [{ name: 'Jugador', tribeId: humanTribe, isHuman: true }];
    const botTribes = ['umbra', 'ferrum', 'maris', 'equus', 'nomad', 'sylva'];
    for (let i = 0; i < numBots; i++) {
        configs.push({
            name: `Bot ${i + 1}`,
            tribeId: botTribes[i % botTribes.length],
            isHuman: false,
        });
    }
    // Crear juego
    game = new GameController(28, 20, configs);
    const camera = new Camera({ x: 0, y: 0, zoom: 1.0 });
    camera.setBounds(-10000, -10000, 10000, 10000);
    hud = new HUD(camera);
    const renderState = {
        cells: game.getRenderCells(),
        camera,
        hud,
        worldWidth: game.world.width,
        worldHeight: game.world.height,
    };
    renderer = new CanvasRenderer(container, renderState);
    // Callbacks HUD
    hud.onEndTurn = () => game?.endTurn();
    hud.onAdvancePhase = () => game?.advancePhase();
    hud.onTrainUnit = () => {
        if (game?.selectedCityId)
            game.trainUnit(game.selectedCityId, UnitType.WARRIOR);
    };
    hud.onFoundCity = () => {
        if (game?.selectedUnitId)
            game.foundCity(game.selectedUnitId);
    };
    // Input
    input = new InputHandler(renderer.getCanvas(), camera, {
        onHexClick: (q, r) => {
            if (!game)
                return;
            const state = game.getState();
            if (!state.isHumanTurn || state.winner)
                return;
            game.clickHex(q, r);
        },
        onHexHover: (q, r) => {
            // hover visual se maneja en render cells
        },
        onPan: (dx, dy) => camera.pan(dx, dy),
        onZoom: (sx, sy, delta) => camera.zoomAt(sx, sy, delta),
        onContextMenu: () => { },
    });
    // Click en HUD (botones)
    renderer.getCanvas().addEventListener('click', (e) => {
        if (!hud || !game)
            return;
        const rect = renderer.getCanvas().getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const btn = hud.getButtonAt(x, y);
        if (btn) {
            if (btn.action === 'advance') {
                if (game.getState().phase === TurnPhase.END) {
                    game.endTurn();
                }
                else {
                    game.advancePhase();
                }
            }
            else if (btn.action === 'train_warrior') {
                if (game.selectedCityId)
                    game.trainUnit(game.selectedCityId, UnitType.WARRIOR);
            }
            else if (btn.action === 'found_city') {
                if (game.selectedUnitId)
                    game.foundCity(game.selectedUnitId);
            }
            else if (btn.action === 'research_tech' && btn.data) {
                game.researchTech(btn.data);
            }
        }
    });
    // State change callback
    game.onStateChange = (state) => {
        renderState.cells = game.getRenderCells();
        hud.updateState(state);
    };
    game.onLog = (msg) => {
        hud.addLog(msg);
    };
    // Inicializar estado
    hud.updateState(game.getState());
    // Build cell lookup para input (wrap-aware)
    const cellMap = new Map();
    const updateCellMap = () => {
        cellMap.clear();
        for (const c of renderState.cells) {
            cellMap.set(`${c.q},${c.r}`, c);
        }
    };
    updateCellMap();
    // Override input cell lookup para wrap
    input.getCellAt = (q, r) => {
        if (!game)
            return undefined;
        const w = game.world.wrap({ q, r });
        return cellMap.get(`${w.q},${w.r}`);
    };
    // Update cell map per frame
    const origLoop = renderer.loop;
    renderer.loop = function () {
        updateCellMap();
        origLoop.call(this);
    };
    renderer.start();
    // Exponer para debug
    window.__sire__ = { game, camera, renderer, hud };
    console.log('Sire iniciado.');
}
// ─── Init ──────────────────────────────────────────────────────────────────
function init() {
    if (checkAuth()) {
        showSetupScreen((numBots, tribe) => startGame(numBots, tribe));
    }
    else {
        showAuthScreen(() => {
            showSetupScreen((numBots, tribe) => startGame(numBots, tribe));
        });
    }
}
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
}
else {
    init();
}
