/**
 * Sire — Estado Global de Partida
 *
 * Gestiona jugadores, turnos, puntuación, condiciones
 * de victoria y el flujo de fases del juego.
 */
import { TRIBES } from './Tribes.js';
import { getCityIncome } from './City.js';
import { createEmptyPouch, addResources } from './Resources.js';
import { TECHNOLOGIES } from './Technologies.js';
/** Fases del turno de un jugador */
export var TurnPhase;
(function (TurnPhase) {
    TurnPhase["INCOME"] = "income";
    TurnPhase["TECHNOLOGY"] = "technology";
    TurnPhase["MOVE"] = "move";
    TurnPhase["COMBAT"] = "combat";
    TurnPhase["BUILD"] = "build";
    TurnPhase["END"] = "end";
})(TurnPhase || (TurnPhase = {}));
/** Crear un jugador nuevo */
export function createPlayer(id, name, tribeId, startingResources = createEmptyPouch()) {
    const tribe = TRIBES[tribeId];
    if (!tribe)
        throw new Error(`Tribu no encontrada: ${tribeId}`);
    // Tecnologías de inicio
    const unlockedTechs = new Set();
    for (const t of tribe.startingTechs) {
        unlockedTechs.add(t);
    }
    // Añadir también las que son "starting" por defecto
    for (const [tid, tech] of Object.entries(TECHNOLOGIES)) {
        if (tech.isStarting)
            unlockedTechs.add(tid);
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
export function createGameState(playerConfigs, mapW, mapH, maxTurns = 0) {
    const players = {};
    const exploredCells = {};
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
export function getCurrentPlayer(state) {
    const pid = state.playerOrder[state.currentPlayerIndex];
    return state.players[pid];
}
/** Avanzar a la siguiente fase del turno */
export function advancePhase(state) {
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
    }
    else {
        // Fin de turno del jugador — pasar al siguiente
        nextPlayer(state);
    }
}
/** Pasar al siguiente jugador */
export function nextPlayer(state) {
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
export function calculateScore(player) {
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
export function checkVictory(state) {
    if (state.winner)
        return;
    // Victoria por dominación: solo un jugador con ciudades
    const alive = Object.values(state.players).filter(p => p.cities.length > 0);
    if (alive.length === 1) {
        state.winner = alive[0].id;
        state.victoryCondition = 'domination';
        return;
    }
    // Victoria por puntuación tras límite de turnos
    if (state.maxTurns > 0 && state.currentTurn > state.maxTurns) {
        let best = null;
        for (const p of Object.values(state.players)) {
            if (!best || p.score > best.score)
                best = p;
        }
        if (best) {
            state.winner = best.id;
            state.victoryCondition = 'score';
        }
    }
}
/** Añadir evento al log */
export function logEvent(state, playerId, type, data) {
    state.eventLog.push({
        turn: state.currentTurn,
        playerId,
        type,
        data,
        timestamp: Date.now(),
    });
}
/** Recolectar ingresos del jugador actual */
export function collectIncome(state) {
    const player = getCurrentPlayer(state);
    let totalStars = 0;
    for (const city of player.cities) {
        totalStars += getCityIncome(city);
    }
    addResources(player.resources, { stars: totalStars });
}
/** Reveal cells around a unit or city */
export function revealCells(state, playerId, cx, cy, radius, tribeVisionBonus = 0) {
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
