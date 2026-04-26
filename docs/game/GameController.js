/**
 * GameController.ts — Orquestador principal del juego Sire
 * Une engine (ECS + SphericalWorld), game logic y UI.
 */
import { Registry } from '../engine/ECS.js';
import { MapGenerator } from '../engine/MapGenerator.js';
import { TileFactory, TerrainType } from '../engine/Tile.js';
import { TurnPhase, createGameState, getCurrentPlayer, collectIncome, logEvent, revealCells, } from './GameState.js';
import { getTribe } from './Tribes.js';
import { UnitType, getUnit, canTraverse } from './Units.js';
import { createUnitInstance, resolveCombat, resolveSiege, canAttackTarget, resetUnitForTurn, healUnit, } from './Combat.js';
import { createCity, queueTraining, processTrainingQueue } from './City.js';
import { canAfford, spendResources } from './Resources.js';
import { TECHNOLOGIES, getAvailableTechs, calculateTechCost } from './Technologies.js';
// ─── Utilidades ────────────────────────────────────────────────────────────
function key(q, r) { return `${q},${r}`; }
function axialKey(c) { return `${c.q},${c.r}`; }
function dist(a, b) {
    return (Math.abs(a.q - b.q) + Math.abs(a.r - b.r) + Math.abs(-a.q - a.r + b.q + b.r)) / 2;
}
/** Mapeo de terrenos del engine a terrenos del renderer */
function terrainToRender(t) {
    switch (t) {
        case TerrainType.GRASS: return 'plains';
        case TerrainType.FOREST: return 'forest';
        case TerrainType.DEEP_WATER:
        case TerrainType.SHALLOW_WATER: return 'water';
        case TerrainType.SAND: return 'desert';
        case TerrainType.HILL:
        case TerrainType.MOUNTAIN:
        case TerrainType.VOLCANO: return 'mountain';
        default: return 'unknown';
    }
}
/** Icono para tipo de unidad */
function unitIcon(type) {
    const icons = {
        [UnitType.EXPLORER]: '⚲',
        [UnitType.WARRIOR]: '⚔',
        [UnitType.ARCHER]: '↗',
        [UnitType.RIDER]: '♞',
        [UnitType.KNIGHT]: '♘',
        [UnitType.BOAT]: '⛵',
        [UnitType.WARSHIP]: '⚓',
        [UnitType.CATAPULT]: 'C',
        [UnitType.GIANT]: 'G',
    };
    return icons[type] || '?';
}
// ─── GameController ────────────────────────────────────────────────────────
export class GameController {
    registry;
    world;
    gameState;
    mapGen;
    // Entidades del mapa: key "q,r" -> tile Entity
    tiles = new Map();
    // Unidades: id -> UnitInstance
    units = new Map();
    // Ciudades: id -> City
    cities = new Map();
    // Selección UI
    selectedUnitId = null;
    selectedCityId = null;
    validMoves = [];
    validAttacks = [];
    // Callback para notificar cambios a UI
    onStateChange;
    onLog;
    // Config
    difficulty = 1;
    constructor(mapW = 24, mapH = 16, playerConfigs = []) {
        this.registry = new Registry();
        this.mapGen = new MapGenerator({ width: mapW, height: mapH, seed: Math.floor(Math.random() * 100000) });
        this.world = this.mapGen.generate(this.registry);
        // Indexar tiles
        for (const entity of this.registry.query('coord')) {
            const coord = TileFactory.getCoord(entity);
            if (coord) {
                this.tiles.set(key(coord.q, coord.r), entity);
            }
        }
        // Crear jugadores
        const configs = playerConfigs.length > 0 ? playerConfigs : [
            { name: 'Jugador', tribeId: 'solaris', isHuman: true },
            { name: 'Bot 1', tribeId: 'umbra', isHuman: false },
        ];
        const gsConfigs = configs.map((c, i) => ({
            id: `p${i}`,
            name: c.name,
            tribeId: c.tribeId,
            isHuman: c.isHuman,
        }));
        this.gameState = createGameState(gsConfigs.map(c => ({ id: c.id, name: c.name, tribeId: c.tribeId })), mapW, mapH, 100);
        // Marcar humano/bot
        for (let i = 0; i < configs.length; i++) {
            this.gameState.players[`p${i}`].isHuman = configs[i].isHuman;
        }
        this.placeInitialCitiesAndUnits();
        this.startTurn();
    }
    // ─── Inicialización ──────────────────────────────────────────────────────
    placeInitialCitiesAndUnits() {
        const coords = this.world.allCoordsArray();
        const landTiles = coords.filter(c => {
            const t = this.getTerrainAt(c.q, c.r);
            return t !== TerrainType.DEEP_WATER && t !== TerrainType.SHALLOW_WATER;
        });
        const players = Object.values(this.gameState.players);
        const used = new Set();
        for (let i = 0; i < players.length; i++) {
            const player = players[i];
            const tribe = getTribe(player.tribeId);
            if (!tribe)
                continue;
            // Encontrar tile de tierra aleatoria, lejos de otros
            let attempts = 0;
            let chosen = null;
            while (attempts < 100) {
                const idx = Math.floor(Math.random() * landTiles.length);
                const cand = landTiles[idx];
                const k = key(cand.q, cand.r);
                if (used.has(k)) {
                    attempts++;
                    continue;
                }
                // Verificar distancia mínima con otros
                let minDist = Infinity;
                for (const u of used) {
                    const [uq, ur] = u.split(',').map(Number);
                    const d = this.world.distanceWrapped(cand, { q: uq, r: ur });
                    if (d < minDist)
                        minDist = d;
                }
                if (minDist > 5 || used.size === 0) {
                    chosen = cand;
                    break;
                }
                attempts++;
            }
            if (!chosen)
                chosen = landTiles[i % landTiles.length];
            used.add(key(chosen.q, chosen.r));
            // Crear ciudad
            const city = createCity(`city_${player.id}`, `${tribe.name}`, player.id, chosen.q, chosen.r);
            this.cities.set(city.id, city);
            player.cities.push(city);
            // Unidad inicial
            const unitType = tribe.startingUnit;
            const unit = createUnitInstance(`unit_${player.id}_0`, unitType, player.id, chosen.q, chosen.r);
            this.units.set(unit.id, unit);
            player.units.push(unit);
            // Revelar alrededor
            revealCells(this.gameState, player.id, chosen.q, chosen.r, 3, tribe.ability.effect === 'vision_bonus' ? 1 : 0);
        }
    }
    // ─── Consultas ───────────────────────────────────────────────────────────
    getTerrainAt(q, r) {
        const w = this.world.wrap({ q, r });
        const tile = this.tiles.get(key(w.q, w.r));
        if (!tile)
            return TerrainType.GRASS;
        const terrain = TileFactory.getTerrain(tile);
        return terrain?.type ?? TerrainType.GRASS;
    }
    getTileEntity(q, r) {
        const w = this.world.wrap({ q, r });
        return this.tiles.get(key(w.q, w.r));
    }
    isWater(q, r) {
        const t = this.getTerrainAt(q, r);
        return t === TerrainType.DEEP_WATER || t === TerrainType.SHALLOW_WATER;
    }
    isMountain(q, r) {
        const t = this.getTerrainAt(q, r);
        return t === TerrainType.MOUNTAIN || t === TerrainType.VOLCANO || t === TerrainType.HILL;
    }
    getCityAt(q, r) {
        for (const city of this.cities.values()) {
            if (city.x === q && city.y === r)
                return city;
        }
        return undefined;
    }
    getUnitAt(q, r) {
        for (const unit of this.units.values()) {
            if (unit.x === q && unit.y === r)
                return unit;
        }
        return undefined;
    }
    getUnitsOfPlayer(playerId) {
        return Array.from(this.units.values()).filter(u => u.ownerId === playerId);
    }
    // ─── Turnos ──────────────────────────────────────────────────────────────
    startTurn() {
        const player = getCurrentPlayer(this.gameState);
        this.log(`Turno ${this.gameState.currentTurn} — ${player.name} (${player.tribe.name})`);
        // Resetear unidades
        for (const unit of player.units) {
            const def = getUnit(unit.type);
            resetUnitForTurn(unit, def);
        }
        // Fase de ingreso
        this.gameState.currentPhase = TurnPhase.INCOME;
        this.runIncomePhase();
        // Si es bot, ejecutar IA
        if (!player.isHuman) {
            setTimeout(() => this.runBotTurn(), 500);
        }
        this.notify();
    }
    runIncomePhase() {
        collectIncome(this.gameState);
        const player = getCurrentPlayer(this.gameState);
        // Procesar colas de entrenamiento
        for (const city of player.cities) {
            const completed = processTrainingQueue(city);
            for (const unitType of completed) {
                const unit = createUnitInstance(`unit_${player.id}_${Date.now()}_${Math.random().toString(36).slice(2, 5)}`, unitType, player.id, city.x, city.y);
                this.units.set(unit.id, unit);
                player.units.push(unit);
                this.log(`${city.name} entrena ${getUnit(unitType).name}`);
            }
        }
        // Curar unidades en territorio propio
        for (const unit of player.units) {
            const inOwnTerritory = player.cities.some(c => c.territory.some(t => t.x === unit.x && t.y === unit.y));
            if (inOwnTerritory)
                healUnit(unit, 1);
        }
        this.advancePhase();
    }
    advancePhase() {
        const phases = [
            TurnPhase.INCOME,
            TurnPhase.TECHNOLOGY,
            TurnPhase.MOVE,
            TurnPhase.COMBAT,
            TurnPhase.BUILD,
            TurnPhase.END,
        ];
        const idx = phases.indexOf(this.gameState.currentPhase);
        if (idx < phases.length - 1) {
            this.gameState.currentPhase = phases[idx + 1];
            this.log(`Fase: ${this.phaseLabel(this.gameState.currentPhase)}`);
        }
        else {
            this.nextPlayer();
            return;
        }
        this.selectedUnitId = null;
        this.selectedCityId = null;
        this.validMoves = [];
        this.validAttacks = [];
        this.notify();
    }
    nextPlayer() {
        this.gameState.currentPlayerIndex++;
        if (this.gameState.currentPlayerIndex >= this.gameState.playerOrder.length) {
            this.gameState.currentPlayerIndex = 0;
            this.gameState.currentTurn++;
        }
        this.gameState.currentPhase = TurnPhase.INCOME;
        this.startTurn();
    }
    endTurn() {
        this.selectedUnitId = null;
        this.selectedCityId = null;
        this.validMoves = [];
        this.validAttacks = [];
        this.nextPlayer();
    }
    phaseLabel(phase) {
        const labels = {
            [TurnPhase.INCOME]: 'Ingresos',
            [TurnPhase.TECHNOLOGY]: 'Tecnología',
            [TurnPhase.MOVE]: 'Movimiento',
            [TurnPhase.COMBAT]: 'Combate',
            [TurnPhase.BUILD]: 'Construcción',
            [TurnPhase.END]: 'Fin',
        };
        return labels[phase] ?? phase;
    }
    // ─── Acciones del jugador ────────────────────────────────────────────────
    selectUnit(unitId) {
        if (this.gameState.currentPhase !== TurnPhase.MOVE && this.gameState.currentPhase !== TurnPhase.COMBAT)
            return;
        const unit = this.units.get(unitId);
        if (!unit)
            return;
        const player = getCurrentPlayer(this.gameState);
        if (unit.ownerId !== player.id)
            return;
        if (unit.movementRemaining <= 0 && unit.hasAttackedThisTurn)
            return;
        this.selectedUnitId = unitId;
        this.selectedCityId = null;
        this.computeValidMoves(unit);
        this.notify();
    }
    selectCity(cityId) {
        const city = this.cities.get(cityId);
        if (!city)
            return;
        const player = getCurrentPlayer(this.gameState);
        if (city.ownerId !== player.id)
            return;
        this.selectedCityId = cityId;
        this.selectedUnitId = null;
        this.validMoves = [];
        this.validAttacks = [];
        this.notify();
    }
    computeValidMoves(unit) {
        const def = getUnit(unit.type);
        const moves = [];
        const attacks = [];
        // BFS limitado por movimiento
        const visited = new Map(); // key -> cost
        const queue = [{ q: unit.x, r: unit.y, cost: 0 }];
        visited.set(key(unit.x, unit.y), 0);
        while (queue.length > 0) {
            const curr = queue.shift();
            const neighbors = this.world.neighborsWrapped({ q: curr.q, r: curr.r });
            for (const n of neighbors) {
                const nk = key(n.q, n.r);
                if (visited.has(nk))
                    continue;
                const terrain = this.getTerrainAt(n.q, n.r);
                let terrainName = 'plain';
                if (terrain === TerrainType.DEEP_WATER || terrain === TerrainType.SHALLOW_WATER)
                    terrainName = 'water';
                else if (terrain === TerrainType.MOUNTAIN || terrain === TerrainType.VOLCANO || terrain === TerrainType.HILL)
                    terrainName = 'mountain';
                else if (terrain === TerrainType.FOREST)
                    terrainName = 'forest';
                if (!canTraverse(def, terrainName))
                    continue;
                // Coste de movimiento
                let moveCost = 1;
                if (terrain === TerrainType.FOREST)
                    moveCost = 2;
                if (terrain === TerrainType.HILL)
                    moveCost = 2;
                if (terrain === TerrainType.MOUNTAIN || terrain === TerrainType.VOLCANO)
                    moveCost = 3;
                const newCost = curr.cost + moveCost;
                if (newCost > unit.movementRemaining)
                    continue;
                const occupant = this.getUnitAt(n.q, n.r);
                if (occupant && occupant.ownerId !== unit.ownerId) {
                    // Enemigo: es ataque válido si está en rango
                    if (canAttackTarget(unit, occupant, def)) {
                        attacks.push(n);
                    }
                    continue; // No podemos mover encima
                }
                // Ciudad enemiga
                const city = this.getCityAt(n.q, n.r);
                if (city && city.ownerId !== unit.ownerId) {
                    if (canAttackTarget(unit, { ...unit, x: n.q, y: n.r, ownerId: city.ownerId, id: 'dummy', type: UnitType.WARRIOR, health: 1, maxHealth: 1, attack: 0, defense: 0, movementRemaining: 0, hasAttackedThisTurn: false }, def)) {
                        attacks.push(n);
                    }
                    continue;
                }
                visited.set(nk, newCost);
                moves.push(n);
                queue.push({ q: n.q, r: n.r, cost: newCost });
            }
        }
        this.validMoves = moves;
        this.validAttacks = attacks;
    }
    clickHex(q, r) {
        const player = getCurrentPlayer(this.gameState);
        const w = this.world.wrap({ q, r });
        q = w.q;
        r = w.r;
        // Seleccionar unidad propia
        const unit = this.getUnitAt(q, r);
        if (unit && unit.ownerId === player.id) {
            this.selectUnit(unit.id);
            return true;
        }
        // Seleccionar ciudad propia
        const city = this.getCityAt(q, r);
        if (city && city.ownerId === player.id) {
            this.selectCity(city.id);
            return true;
        }
        // Si hay unidad seleccionada, intentar mover o atacar
        if (this.selectedUnitId) {
            const selUnit = this.units.get(this.selectedUnitId);
            if (selUnit && selUnit.ownerId === player.id) {
                const moveTarget = this.validMoves.find(m => m.q === q && m.r === r);
                const attackTarget = this.validAttacks.find(m => m.q === q && m.r === r);
                if (moveTarget) {
                    this.executeMove(selUnit, q, r);
                    return true;
                }
                if (attackTarget) {
                    const enemy = this.getUnitAt(q, r);
                    if (enemy) {
                        this.executeAttack(selUnit, enemy);
                        return true;
                    }
                    const enemyCity = this.getCityAt(q, r);
                    if (enemyCity) {
                        this.executeSiege(selUnit, enemyCity);
                        return true;
                    }
                }
            }
        }
        // Click vacío: deseleccionar
        this.selectedUnitId = null;
        this.selectedCityId = null;
        this.validMoves = [];
        this.validAttacks = [];
        this.notify();
        return false;
    }
    executeMove(unit, q, r) {
        const player = getCurrentPlayer(this.gameState);
        const oldKey = key(unit.x, unit.y);
        unit.x = q;
        unit.y = r;
        // Revelar terreno
        const tribe = getTribe(player.tribeId);
        const visionBonus = tribe?.ability.effect === 'vision_bonus' ? 1 : 0;
        revealCells(this.gameState, player.id, q, r, 2, visionBonus);
        // Recalcular movimientos si queda movimiento
        if (unit.movementRemaining > 0 && !unit.hasAttackedThisTurn) {
            this.computeValidMoves(unit);
        }
        else {
            this.validMoves = [];
            this.validAttacks = [];
        }
        this.notify();
    }
    executeAttack(attacker, defender) {
        const attackerTerrain = this.terrainNameAt(attacker.x, attacker.y);
        const defenderTerrain = this.terrainNameAt(defender.x, defender.y);
        const attackerPlayer = this.gameState.players[attacker.ownerId];
        const tribe = getTribe(attackerPlayer.tribeId);
        const attackBonus = tribe?.ability.effect === 'combat_bonus' ? tribe.ability.value : 0;
        const result = resolveCombat(attacker, defender, attackerTerrain, defenderTerrain, attackBonus);
        this.log(`${getUnit(attacker.type).name} ataca ${getUnit(defender.type).name}: ${result.attackerDamageDealt} dmg`);
        if (!result.defenderSurvives) {
            // Eliminar defensor
            this.removeUnit(defender);
            attackerPlayer.unitsDefeated++;
            this.log(`${getUnit(defender.type).name} destruido`);
        }
        if (!result.attackerSurvives) {
            this.removeUnit(attacker);
            this.selectedUnitId = null;
            this.log(`${getUnit(attacker.type).name} destruido`);
        }
        this.validMoves = [];
        this.validAttacks = [];
        this.notify();
    }
    executeSiege(attacker, city) {
        const attackerTerrain = this.terrainNameAt(attacker.x, attacker.y);
        const attackerPlayer = this.gameState.players[attacker.ownerId];
        const tribe = getTribe(attackerPlayer.tribeId);
        const attackBonus = tribe?.ability.effect === 'combat_bonus' ? tribe.ability.value : 0;
        const result = resolveSiege(attacker, city, attackerTerrain, attackBonus);
        this.log(`Asedio a ${city.name}: ${result.damageDealt} daño`);
        if (result.cityCaptured) {
            // Cambiar propietario
            const oldOwner = this.gameState.players[city.ownerId];
            if (oldOwner) {
                oldOwner.cities = oldOwner.cities.filter(c => c.id !== city.id);
            }
            city.ownerId = attacker.ownerId;
            attackerPlayer.cities.push(city);
            this.log(`${city.name} capturada por ${attackerPlayer.name}`);
        }
        this.validMoves = [];
        this.validAttacks = [];
        this.notify();
    }
    removeUnit(unit) {
        this.units.delete(unit.id);
        const player = this.gameState.players[unit.ownerId];
        if (player) {
            player.units = player.units.filter(u => u.id !== unit.id);
        }
    }
    terrainNameAt(q, r) {
        const t = this.getTerrainAt(q, r);
        if (t === TerrainType.FOREST)
            return 'forest';
        if (t === TerrainType.MOUNTAIN || t === TerrainType.VOLCANO || t === TerrainType.HILL)
            return 'mountain';
        return 'plain';
    }
    // ─── Construcción / Entrenamiento ────────────────────────────────────────
    trainUnit(cityId, unitType) {
        if (this.gameState.currentPhase !== TurnPhase.BUILD)
            return false;
        const city = this.cities.get(cityId);
        if (!city)
            return false;
        const player = getCurrentPlayer(this.gameState);
        if (city.ownerId !== player.id)
            return false;
        const def = getUnit(unitType);
        const tribe = getTribe(player.tribeId);
        // Aplicar descuentos
        let cost = { ...def.cost };
        if (tribe?.ability.effect === 'discount_wood' && cost.wood) {
            cost.wood = Math.ceil(cost.wood * 0.7);
        }
        if (!canAfford(player.resources, cost)) {
            this.log('Recursos insuficientes');
            return false;
        }
        spendResources(player.resources, cost);
        queueTraining(city, unitType, 1);
        this.log(`Entrenando ${def.name} en ${city.name}`);
        this.notify();
        return true;
    }
    researchTech(techId) {
        if (this.gameState.currentPhase !== TurnPhase.TECHNOLOGY)
            return false;
        const player = getCurrentPlayer(this.gameState);
        const tech = TECHNOLOGIES[techId];
        if (!tech)
            return false;
        if (player.unlockedTechs.has(techId))
            return false;
        if (!tech.prerequisites.every(p => player.unlockedTechs.has(p)))
            return false;
        const tribe = getTribe(player.tribeId);
        const cost = calculateTechCost(tech.cost, tribe?.ability.effect);
        if (player.resources.stars < cost) {
            this.log('Estrellas insuficientes');
            return false;
        }
        player.resources.stars -= cost;
        player.unlockedTechs.add(techId);
        this.log(`Tecnología investigada: ${tech.name}`);
        logEvent(this.gameState, player.id, 'research', { techId, techName: tech.name });
        this.notify();
        return true;
    }
    foundCity(unitId) {
        if (this.gameState.currentPhase !== TurnPhase.BUILD)
            return false;
        const unit = this.units.get(unitId);
        if (!unit)
            return false;
        const player = getCurrentPlayer(this.gameState);
        if (unit.ownerId !== player.id)
            return false;
        const terrain = this.getTerrainAt(unit.x, unit.y);
        if (terrain === TerrainType.DEEP_WATER || terrain === TerrainType.SHALLOW_WATER) {
            this.log('No puedes fundar ciudad en agua');
            return false;
        }
        if (this.getCityAt(unit.x, unit.y)) {
            this.log('Ya hay una ciudad aquí');
            return false;
        }
        if (player.resources.stars < 5) {
            this.log('Necesitas 5 estrellas para fundar ciudad');
            return false;
        }
        player.resources.stars -= 5;
        const tribe = getTribe(player.tribeId);
        const city = createCity(`city_${player.id}_${Date.now()}`, `Ciudad ${player.cities.length + 1}`, player.id, unit.x, unit.y);
        this.cities.set(city.id, city);
        player.cities.push(city);
        // El explorador se consume al fundar ciudad
        this.removeUnit(unit);
        this.selectedUnitId = null;
        this.log(`Ciudad fundada: ${city.name}`);
        logEvent(this.gameState, player.id, 'found_city', { cityId: city.id, x: unit.x, y: unit.y });
        this.notify();
        return true;
    }
    // ─── Bot AI ──────────────────────────────────────────────────────────────
    runBotTurn() {
        const player = getCurrentPlayer(this.gameState);
        if (player.isHuman)
            return;
        // Fase tecnología: investigar primera disponible
        if (this.gameState.currentPhase === TurnPhase.TECHNOLOGY) {
            const available = getAvailableTechs(player.unlockedTechs);
            for (const tech of available) {
                if (this.researchTech(tech.id))
                    break;
            }
            this.advancePhase();
        }
        // Fase movimiento: mover unidades
        if (this.gameState.currentPhase === TurnPhase.MOVE || this.gameState.currentPhase === TurnPhase.COMBAT) {
            const units = this.getUnitsOfPlayer(player.id).filter(u => u.movementRemaining > 0);
            for (const unit of units) {
                this.selectUnit(unit.id);
                if (this.validAttacks.length > 0) {
                    // Atacar
                    const target = this.validAttacks[0];
                    this.clickHex(target.q, target.r);
                }
                else if (this.validMoves.length > 0) {
                    // Mover hacia enemigo o explorar
                    const target = this.pickBestMove(unit, player);
                    if (target)
                        this.clickHex(target.q, target.r);
                }
            }
            this.advancePhase();
        }
        // Fase build: entrenar unidades
        if (this.gameState.currentPhase === TurnPhase.BUILD) {
            for (const city of player.cities) {
                // Entrenar guerrero si hay recursos
                if (canAfford(player.resources, getUnit(UnitType.WARRIOR).cost)) {
                    this.trainUnit(city.id, UnitType.WARRIOR);
                }
            }
            this.advancePhase();
        }
    }
    pickBestMove(unit, player) {
        // Buscar ciudad enemiga más cercana
        let bestTarget = null;
        for (const other of Object.values(this.gameState.players)) {
            if (other.id === player.id)
                continue;
            for (const city of other.cities) {
                const d = this.world.distanceWrapped({ q: unit.x, r: unit.y }, { q: city.x, r: city.y });
                if (!bestTarget || d < bestTarget.dist) {
                    bestTarget = { q: city.x, r: city.y, dist: d };
                }
            }
        }
        if (!bestTarget) {
            // Explorar: mover aleatoriamente
            if (this.validMoves.length > 0) {
                return this.validMoves[Math.floor(Math.random() * this.validMoves.length)];
            }
            return null;
        }
        // Elegir movimiento que minimice distancia al objetivo
        let best = null;
        let bestDist = Infinity;
        for (const m of this.validMoves) {
            const d = this.world.distanceWrapped(m, bestTarget);
            if (d < bestDist) {
                bestDist = d;
                best = m;
            }
        }
        return best;
    }
    // ─── Renderizado ─────────────────────────────────────────────────────────
    getRenderCells() {
        const player = getCurrentPlayer(this.gameState);
        const explored = this.gameState.exploredCells[player.id];
        const cells = [];
        for (const c of this.world.allCoordsArray()) {
            const k = key(c.q, c.r);
            const isExplored = explored.has(`${c.q},${c.r}`);
            const tile = this.tiles.get(k);
            const terrainComp = tile ? TileFactory.getTerrain(tile) : null;
            const terrain = terrainComp ? terrainToRender(terrainComp.type) : 'unknown';
            const cell = {
                q: c.q,
                r: c.r,
                terrain,
                fogged: !isExplored,
            };
            if (isExplored) {
                // Unidad
                const unit = this.getUnitAt(c.q, c.r);
                if (unit) {
                    const owner = this.gameState.players[unit.ownerId];
                    const tribe = owner ? getTribe(owner.tribeId) : null;
                    cell.unit = {
                        tribeColor: tribe?.color ?? '#888',
                        icon: unitIcon(unit.type),
                        ownerId: unit.ownerId,
                        healthPercent: unit.health / unit.maxHealth,
                    };
                }
                // Ciudad
                const city = this.getCityAt(c.q, c.r);
                if (city) {
                    const owner = this.gameState.players[city.ownerId];
                    const tribe = owner ? getTribe(owner.tribeId) : null;
                    cell.city = {
                        name: city.name,
                        ownerId: city.ownerId,
                        level: city.level,
                        color: tribe?.color ?? '#888',
                    };
                }
                // Highlight
                if (this.selectedUnitId) {
                    const sel = this.units.get(this.selectedUnitId);
                    if (sel && sel.x === c.q && sel.y === c.r) {
                        cell.highlight = 'selected';
                    }
                    else if (this.validMoves.some(m => m.q === c.q && m.r === c.r)) {
                        cell.highlight = 'move';
                    }
                    else if (this.validAttacks.some(m => m.q === c.q && m.r === c.r)) {
                        cell.highlight = 'attack';
                    }
                }
                if (this.selectedCityId) {
                    const sel = this.cities.get(this.selectedCityId);
                    if (sel && sel.x === c.q && sel.y === c.r) {
                        cell.highlight = 'city';
                    }
                }
            }
            cells.push(cell);
        }
        return cells;
    }
    getState() {
        const player = getCurrentPlayer(this.gameState);
        return {
            gameState: this.gameState,
            currentPlayer: player,
            phase: this.gameState.currentPhase,
            selectedUnitId: this.selectedUnitId,
            selectedCityId: this.selectedCityId,
            validMoves: this.validMoves,
            validAttacks: this.validAttacks,
            turnMessage: `Turno ${this.gameState.currentTurn} — ${player.name} (${this.phaseLabel(this.gameState.currentPhase)})`,
            worldWidth: this.world.width,
            worldHeight: this.world.height,
            isHumanTurn: !!player.isHuman,
            winner: this.gameState.winner,
        };
    }
    notify() {
        if (this.onStateChange)
            this.onStateChange(this.getState());
    }
    log(msg) {
        if (this.onLog)
            this.onLog(msg);
        console.log(`[Sire] ${msg}`);
    }
}
