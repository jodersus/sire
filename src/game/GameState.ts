/**
 * Sire — Estado Global de Partida
 *
 * Gestiona jugadores, turnos, puntuación, condiciones
 * de victoria y el flujo de fases del juego.
 */

import { Tribe, TRIBES } from './Tribes.js';
import { City, createCity, getCityIncome } from './City.js';
import { UnitInstance } from './Combat.js';
import { ResourcePouch, createEmptyPouch, addResources } from './Resources.js';
import { Technology, TECHNOLOGIES } from './Technologies.js';

/** Identificador de jugador */
export type PlayerId = string;

/** Jugador en la partida */
export interface Player {
  id: PlayerId;
  name: string;
  tribeId: string;
  tribe: Tribe;

  // Recursos
  resources: ResourcePouch;

  // Tecnologías desbloqueadas
  unlockedTechs: Set<string>;

  // Ciudades y unidades
  cities: City[];
  units: UnitInstance[];

  // Puntuación
  score: number;
  // Número de unidades derrotadas
  unitsDefeated: number;
  // Tamaño del imperio (ciudades + territorio)
  territorySize: number;
}

/** Fases del turno de un jugador */
export enum TurnPhase {
  INCOME = 'income',           // recibir recursos
  TECHNOLOGY = 'technology',   // investigar
  MOVE = 'move',               // mover unidades
  COMBAT = 'combat',           // combatir
  BUILD = 'build',             // construir / entrenar
  END = 'end',                 // finalizar
}

/** Estado completo de la partida */
export interface GameState {
  // Configuración
  mapWidth: number;
  mapHeight: number;
  maxTurns: number; // límite de turnos totales (0 = infinito)

  // Jugadores
  players: Record<PlayerId, Player>;
  playerOrder: PlayerId[];

  // Turno actual
  currentTurn: number; // turno global (incrementa tras cada ronda)
  currentPlayerIndex: number;
  currentPhase: TurnPhase;

  // Estado del mapa
  // Recursos en celdas (por ahora, referencia a un futuro Map.ts)
  // exploredCells: Set de celdas reveladas por cada jugador
  exploredCells: Record<PlayerId, Set<string>>; // "x,y"

  // Condición de victoria
  winner: PlayerId | null;
  victoryCondition: 'domination' | 'score' | 'wonder' | null;

  // Historial de eventos
  eventLog: GameEvent[];
}

/** Evento del juego para el log */
export interface GameEvent {
  turn: number;
  playerId: PlayerId;
  type: 'found_city' | 'conquer_city' | 'research' | 'defeat_unit' | 'build' | 'train' | 'phase_change';
  data: Record<string, unknown>;
  timestamp: number;
}

/** Crear un jugador nuevo */
export function createPlayer(id: PlayerId, name: string, tribeId: string, startingResources: ResourcePouch = createEmptyPouch()): Player {
  const tribe = TRIBES[tribeId];
  if (!tribe) throw new Error(`Tribu no encontrada: ${tribeId}`);

  // Tecnologías de inicio
  const unlockedTechs = new Set<string>();
  for (const t of tribe.startingTechs) {
    unlockedTechs.add(t);
  }
  // Añadir también las que son "starting" por defecto
  for (const [tid, tech] of Object.entries(TECHNOLOGIES)) {
    if (tech.isStarting) unlockedTechs.add(tid);
  }

  return {
    id,
    name,
    tribeId,
    tribe,
    resources: startingResources,
    unlockedTechs,
    cities: [],
    units: [],
    score: 0,
    unitsDefeated: 0,
    territorySize: 0,
  };
}

/** Crear estado inicial de partida */
export function createGameState(playerConfigs: { id: string; name: string; tribeId: string }[], mapW: number, mapH: number, maxTurns: number = 0): GameState {
  const players: Record<PlayerId, Player> = {};
  const exploredCells: Record<PlayerId, Set<string>> = {};

  for (const cfg of playerConfigs) {
    const p = createPlayer(cfg.id, cfg.name, cfg.tribeId);
    players[cfg.id] = p;
    exploredCells[cfg.id] = new Set();
  }

  return {
    mapWidth: mapW,
    mapHeight: mapH,
    maxTurns,
    players,
    playerOrder: playerConfigs.map(c => c.id),
    currentTurn: 1,
    currentPlayerIndex: 0,
    currentPhase: TurnPhase.INCOME,
    exploredCells,
    winner: null,
    victoryCondition: null,
    eventLog: [],
  };
}

/** Obtener jugador actual */
export function getCurrentPlayer(state: GameState): Player {
  const pid = state.playerOrder[state.currentPlayerIndex];
  return state.players[pid];
}

/** Avanzar a la siguiente fase del turno */
export function advancePhase(state: GameState): void {
  const phases = [
    TurnPhase.INCOME,
    TurnPhase.TECHNOLOGY,
    TurnPhase.MOVE,
    TurnPhase.COMBAT,
    TurnPhase.BUILD,
    TurnPhase.END,
  ];
  const idx = phases.indexOf(state.currentPhase);
  if (idx < phases.length - 1) {
    state.currentPhase = phases[idx + 1];
  } else {
    // Fin de turno del jugador — pasar al siguiente
    nextPlayer(state);
  }
}

/** Pasar al siguiente jugador */
export function nextPlayer(state: GameState): void {
  state.currentPlayerIndex++;
  if (state.currentPlayerIndex >= state.playerOrder.length) {
    state.currentPlayerIndex = 0;
    state.currentTurn++;
  }
  state.currentPhase = TurnPhase.INCOME;

  // Verificar victoria por abandono (solo queda 1 jugador con ciudades)
  checkVictory(state);
}

/** Calcular puntuación de un jugador */
export function calculateScore(player: Player): number {
  let score = 0;
  // Ciudades: 100 por nivel
  for (const city of player.cities) {
    score += city.level * 100;
  }
  // Tecnologías: 50 cada una
  score += player.unlockedTechs.size * 50;
  // Unidades derrotadas: 10 cada una
  score += player.unitsDefeated * 10;
  // Territorio: 1 por celda
  score += player.territorySize;
  // Unidades vivas: 5 cada una
  score += player.units.length * 5;
  return score;
}

/** Verificar condiciones de victoria */
export function checkVictory(state: GameState): void {
  if (state.winner) return;

  // Victoria por dominación: solo un jugador con ciudades
  const alive = Object.values(state.players).filter(p => p.cities.length > 0);
  if (alive.length === 1) {
    state.winner = alive[0].id;
    state.victoryCondition = 'domination';
    return;
  }

  // Victoria por puntuación tras límite de turnos
  if (state.maxTurns > 0 && state.currentTurn > state.maxTurns) {
    let best: Player | null = null;
    for (const p of Object.values(state.players)) {
      if (!best || p.score > best.score) best = p;
    }
    if (best) {
      state.winner = best.id;
      state.victoryCondition = 'score';
    }
  }
}

/** Añadir evento al log */
export function logEvent(state: GameState, playerId: PlayerId, type: GameEvent['type'], data: Record<string, unknown>): void {
  state.eventLog.push({
    turn: state.currentTurn,
    playerId,
    type,
    data,
    timestamp: Date.now(),
  });
}

/** Recolectar ingresos del jugador actual */
export function collectIncome(state: GameState): void {
  const player = getCurrentPlayer(state);
  let totalStars = 0;

  for (const city of player.cities) {
    totalStars += getCityIncome(city);
  }

  addResources(player.resources, { stars: totalStars });
}

/** Reveal cells around a unit or city */
export function revealCells(state: GameState, playerId: PlayerId, cx: number, cy: number, radius: number, tribeVisionBonus: number = 0): void {
  const set = state.exploredCells[playerId];
  const r = radius + tribeVisionBonus;
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      if (Math.abs(dx) + Math.abs(dy) <= r) {
        const x = cx + dx;
        const y = cy + dy;
        if (x >= 0 && x < state.mapWidth && y >= 0 && y < state.mapHeight) {
          set.add(`${x},${y}`);
        }
      }
    }
  }
}
