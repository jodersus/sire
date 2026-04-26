/**
 * GameController.ts — Orquestador principal del juego Sire
 * Une engine (ECS + SphericalWorld), game logic y UI.
 */

import { Registry, World } from '../engine/ECS.js';
import { SphericalWorld } from '../engine/SphericalWorld.js';
import { MapGenerator } from '../engine/MapGenerator.js';
import { TileFactory, TerrainType, TerrainComponent, CoordComponent, OccupantComponent } from '../engine/Tile.js';
import type { Entity } from '../engine/ECS.js';
import type { AxialCoord } from '../engine/HexGrid.js';

import {
  GameState, Player, PlayerId, TurnPhase,
  createGameState, getCurrentPlayer, advancePhase,
  collectIncome, logEvent, revealCells,
} from './GameState.js';
import { Tribe, TRIBES, TRIBE_LIST, getTribe } from './Tribes.js';
import { UnitType, UnitDefinition, getUnit, canTraverse } from './Units.js';
import {
  UnitInstance, createUnitInstance, resolveCombat, resolveSiege,
  canAttackTarget, resetUnitForTurn, healUnit,
} from './Combat.js';
import { City, createCity, getCityIncome, queueTraining, processTrainingQueue, calculateTerritory } from './City.js';
import { ResourcePouch, createEmptyPouch, canAfford, spendResources, addResources } from './Resources.js';
import { Technology, TECHNOLOGIES, getAvailableTechs, calculateTechCost } from './Technologies.js';

// ─── Utilidades ────────────────────────────────────────────────────────────

function key(q: number, r: number): string { return `${q},${r}`; }

function axialKey(c: AxialCoord): string { return `${c.q},${c.r}`; }

function dist(a: AxialCoord, b: AxialCoord): number {
  return (Math.abs(a.q - b.q) + Math.abs(a.r - b.r) + Math.abs(-a.q - a.r + b.q + b.r)) / 2;
}

/** Mapeo de terrenos del engine a terrenos del renderer */
function terrainToRender(t: TerrainType): 'plains' | 'mountain' | 'water' | 'desert' | 'forest' | 'unknown' {
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
function unitIcon(type: UnitType): string {
  const icons: Record<UnitType, string> = {
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

// ─── Interfaces para UI ────────────────────────────────────────────────────

export interface RenderHexCell {
  q: number;
  r: number;
  terrain: 'plains' | 'mountain' | 'water' | 'desert' | 'forest' | 'unknown';
  unit?: {
    tribeColor: string;
    icon: string;
    ownerId: string;
    healthPercent: number;
  };
  city?: {
    name: string;
    ownerId: string;
    level: number;
    color: string;
  };
  highlight?: 'hover' | 'selected' | 'move' | 'attack' | 'city';
  fogged?: boolean;
}

export interface GameControllerState {
  gameState: GameState;
  currentPlayer: Player;
  phase: TurnPhase;
  selectedUnitId: string | null;
  selectedCityId: string | null;
  validMoves: AxialCoord[];
  validAttacks: AxialCoord[];
  turnMessage: string;
  worldWidth: number;
  worldHeight: number;
  isHumanTurn: boolean;
  winner: PlayerId | null;
}

// ─── GameController ────────────────────────────────────────────────────────

export class GameController {
  readonly registry: Registry;
  readonly world: SphericalWorld;
  readonly gameState: GameState;
  private mapGen: MapGenerator;

  // Entidades del mapa: key "q,r" -> tile Entity
  private tiles = new Map<string, Entity>();

  // Unidades: id -> UnitInstance
  units = new Map<string, UnitInstance>();
  // Ciudades: id -> City
  cities = new Map<string, City>();

  // Selección UI
  selectedUnitId: string | null = null;
  selectedCityId: string | null = null;
  validMoves: AxialCoord[] = [];
  validAttacks: AxialCoord[] = [];

  // Callback para notificar cambios a UI
  onStateChange?: (state: GameControllerState) => void;
  onLog?: (msg: string) => void;

  // Config
  private difficulty: number = 1;

  constructor(
    mapW: number = 24,
    mapH: number = 16,
    playerConfigs: { name: string; tribeId: string; isHuman: boolean }[] = []
  ) {
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

    this.gameState = createGameState(
      gsConfigs.map(c => ({ id: c.id, name: c.name, tribeId: c.tribeId })),
      mapW, mapH, 100
    );

    // Marcar humano/bot
    for (let i = 0; i < configs.length; i++) {
      (this.gameState.players[`p${i}`] as any).isHuman = configs[i].isHuman;
    }

    this.placeInitialCitiesAndUnits();
    this.startTurn();
  }

  // ─── Inicialización ──────────────────────────────────────────────────────

  private placeInitialCitiesAndUnits(): void {
    const coords = this.world.allCoordsArray();
    const landTiles = coords.filter(c => {
      const t = this.getTerrainAt(c.q, c.r);
      return t !== TerrainType.DEEP_WATER && t !== TerrainType.SHALLOW_WATER;
    });

    const players = Object.values(this.gameState.players);
    const used = new Set<string>();

    for (let i = 0; i < players.length; i++) {
      const player = players[i];
      const tribe = getTribe(player.tribeId);
      if (!tribe) continue;

      // Encontrar tile de tierra aleatoria, lejos de otros
      let attempts = 0;
      let chosen: AxialCoord | null = null;
      while (attempts < 100) {
        const idx = Math.floor(Math.random() * landTiles.length);
        const cand = landTiles[idx];
        const k = key(cand.q, cand.r);
        if (used.has(k)) { attempts++; continue; }

        // Verificar distancia mínima con otros
        let minDist = Infinity;
        for (const u of used) {
          const [uq, ur] = u.split(',').map(Number);
          const d = this.world.distanceWrapped(cand, { q: uq, r: ur });
          if (d < minDist) minDist = d;
        }
        if (minDist > 5 || used.size === 0) {
          chosen = cand;
          break;
        }
        attempts++;
      }

      if (!chosen) chosen = landTiles[i % landTiles.length];
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

  private getTerrainAt(q: number, r: number): TerrainType {
    const w = this.world.wrap({ q, r });
    const tile = this.tiles.get(key(w.q, w.r));
    if (!tile) return TerrainType.GRASS;
    const terrain = TileFactory.getTerrain(tile);
    return terrain?.type ?? TerrainType.GRASS;
  }

  private getTileEntity(q: number, r: number): Entity | undefined {
    const w = this.world.wrap({ q, r });
    return this.tiles.get(key(w.q, w.r));
  }

  private isWater(q: number, r: number): boolean {
    const t = this.getTerrainAt(q, r);
    return t === TerrainType.DEEP_WATER || t === TerrainType.SHALLOW_WATER;
  }

  private isMountain(q: number, r: number): boolean {
    const t = this.getTerrainAt(q, r);
    return t === TerrainType.MOUNTAIN || t === TerrainType.VOLCANO || t === TerrainType.HILL;
  }

  getCityAt(q: number, r: number): City | undefined {
    for (const city of this.cities.values()) {
      if (city.x === q && city.y === r) return city;
    }
    return undefined;
  }

  getUnitAt(q: number, r: number): UnitInstance | undefined {
    for (const unit of this.units.values()) {
      if (unit.x === q && unit.y === r) return unit;
    }
    return undefined;
  }

  getUnitsOfPlayer(playerId: PlayerId): UnitInstance[] {
    return Array.from(this.units.values()).filter(u => u.ownerId === playerId);
  }

  // ─── Turnos ──────────────────────────────────────────────────────────────

  startTurn(): void {
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
    if (!(player as any).isHuman) {
      setTimeout(() => this.runBotTurn(), 500);
    }

    this.notify();
  }

  private runIncomePhase(): void {
    collectIncome(this.gameState);
    const player = getCurrentPlayer(this.gameState);

    // Procesar colas de entrenamiento
    for (const city of player.cities) {
      const completed = processTrainingQueue(city);
      for (const unitType of completed) {
        const unit = createUnitInstance(
          `unit_${player.id}_${Date.now()}_${Math.random().toString(36).slice(2, 5)}`,
          unitType, player.id, city.x, city.y
        );
        this.units.set(unit.id, unit);
        player.units.push(unit);
        this.log(`${city.name} entrena ${getUnit(unitType).name}`);
      }
    }

    // Curar unidades en territorio propio
    for (const unit of player.units) {
      const inOwnTerritory = player.cities.some(c =>
        c.territory.some(t => t.x === unit.x && t.y === unit.y)
      );
      if (inOwnTerritory) healUnit(unit, 1);
    }

    this.advancePhase();
  }

  advancePhase(): void {
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
    } else {
      this.nextPlayer();
      return;
    }

    this.selectedUnitId = null;
    this.selectedCityId = null;
    this.validMoves = [];
    this.validAttacks = [];

    this.notify();
  }

  private nextPlayer(): void {
    this.gameState.currentPlayerIndex++;
    if (this.gameState.currentPlayerIndex >= this.gameState.playerOrder.length) {
      this.gameState.currentPlayerIndex = 0;
      this.gameState.currentTurn++;
    }
    this.gameState.currentPhase = TurnPhase.INCOME;
    this.startTurn();
  }

  endTurn(): void {
    this.selectedUnitId = null;
    this.selectedCityId = null;
    this.validMoves = [];
    this.validAttacks = [];
    this.nextPlayer();
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

  // ─── Acciones del jugador ────────────────────────────────────────────────

  selectUnit(unitId: string): void {
    if (this.gameState.currentPhase !== TurnPhase.MOVE && this.gameState.currentPhase !== TurnPhase.COMBAT) return;
    const unit = this.units.get(unitId);
    if (!unit) return;
    const player = getCurrentPlayer(this.gameState);
    if (unit.ownerId !== player.id) return;
    if (unit.movementRemaining <= 0 && unit.hasAttackedThisTurn) return;

    this.selectedUnitId = unitId;
    this.selectedCityId = null;
    this.computeValidMoves(unit);
    this.notify();
  }

  selectCity(cityId: string): void {
    const city = this.cities.get(cityId);
    if (!city) return;
    const player = getCurrentPlayer(this.gameState);
    if (city.ownerId !== player.id) return;

    this.selectedCityId = cityId;
    this.selectedUnitId = null;
    this.validMoves = [];
    this.validAttacks = [];
    this.notify();
  }

  private computeValidMoves(unit: UnitInstance): void {
    const def = getUnit(unit.type);
    const moves: AxialCoord[] = [];
    const attacks: AxialCoord[] = [];

    // BFS limitado por movimiento
    const visited = new Map<string, number>(); // key -> cost
    const queue: { q: number; r: number; cost: number }[] = [{ q: unit.x, r: unit.y, cost: 0 }];
    visited.set(key(unit.x, unit.y), 0);

    while (queue.length > 0) {
      const curr = queue.shift()!;
      const neighbors = this.world.neighborsWrapped({ q: curr.q, r: curr.r });

      for (const n of neighbors) {
        const nk = key(n.q, n.r);
        if (visited.has(nk)) continue;

        const terrain = this.getTerrainAt(n.q, n.r);
        let terrainName = 'plain';
        if (terrain === TerrainType.DEEP_WATER || terrain === TerrainType.SHALLOW_WATER) terrainName = 'water';
        else if (terrain === TerrainType.MOUNTAIN || terrain === TerrainType.VOLCANO || terrain === TerrainType.HILL) terrainName = 'mountain';
        else if (terrain === TerrainType.FOREST) terrainName = 'forest';

        if (!canTraverse(def, terrainName)) continue;

        // Coste de movimiento
        let moveCost = 1;
        if (terrain === TerrainType.FOREST) moveCost = 2;
        if (terrain === TerrainType.HILL) moveCost = 2;
        if (terrain === TerrainType.MOUNTAIN || terrain === TerrainType.VOLCANO) moveCost = 3;

        const newCost = curr.cost + moveCost;
        if (newCost > unit.movementRemaining) continue;

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

  clickHex(q: number, r: number): boolean {
    const player = getCurrentPlayer(this.gameState);
    const w = this.world.wrap({ q, r });
    q = w.q; r = w.r;

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

  private executeMove(unit: UnitInstance, q: number, r: number): void {
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
    } else {
      this.validMoves = [];
      this.validAttacks = [];
    }

    this.notify();
  }

  private executeAttack(attacker: UnitInstance, defender: UnitInstance): void {
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

  private executeSiege(attacker: UnitInstance, city: City): void {
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

  private removeUnit(unit: UnitInstance): void {
    this.units.delete(unit.id);
    const player = this.gameState.players[unit.ownerId];
    if (player) {
      player.units = player.units.filter(u => u.id !== unit.id);
    }
  }

  private terrainNameAt(q: number, r: number): string {
    const t = this.getTerrainAt(q, r);
    if (t === TerrainType.FOREST) return 'forest';
    if (t === TerrainType.MOUNTAIN || t === TerrainType.VOLCANO || t === TerrainType.HILL) return 'mountain';
    return 'plain';
  }

  // ─── Construcción / Entrenamiento ────────────────────────────────────────

  trainUnit(cityId: string, unitType: UnitType): boolean {
    if (this.gameState.currentPhase !== TurnPhase.BUILD) return false;
    const city = this.cities.get(cityId);
    if (!city) return false;
    const player = getCurrentPlayer(this.gameState);
    if (city.ownerId !== player.id) return false;

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

  researchTech(techId: string): boolean {
    if (this.gameState.currentPhase !== TurnPhase.TECHNOLOGY) return false;
    const player = getCurrentPlayer(this.gameState);
    const tech = TECHNOLOGIES[techId];
    if (!tech) return false;
    if (player.unlockedTechs.has(techId)) return false;
    if (!tech.prerequisites.every(p => player.unlockedTechs.has(p))) return false;

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

  foundCity(unitId: string): boolean {
    if (this.gameState.currentPhase !== TurnPhase.BUILD) return false;
    const unit = this.units.get(unitId);
    if (!unit) return false;
    const player = getCurrentPlayer(this.gameState);
    if (unit.ownerId !== player.id) return false;

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
    const city = createCity(
      `city_${player.id}_${Date.now()}`,
      `Ciudad ${player.cities.length + 1}`,
      player.id,
      unit.x,
      unit.y
    );
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

  runBotTurn(): void {
    const player = getCurrentPlayer(this.gameState);
    if ((player as any).isHuman) return;

    // Fase tecnología: investigar primera disponible
    if (this.gameState.currentPhase === TurnPhase.TECHNOLOGY) {
      const available = getAvailableTechs(player.unlockedTechs);
      for (const tech of available) {
        if (this.researchTech(tech.id)) break;
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
        } else if (this.validMoves.length > 0) {
          // Mover hacia enemigo o explorar
          const target = this.pickBestMove(unit, player);
          if (target) this.clickHex(target.q, target.r);
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

  private pickBestMove(unit: UnitInstance, player: Player): AxialCoord | null {
    // Buscar ciudad enemiga más cercana
    let bestTarget: { q: number; r: number; dist: number } | null = null;
    for (const other of Object.values(this.gameState.players)) {
      if (other.id === player.id) continue;
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
    let best: AxialCoord | null = null;
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

  getRenderCells(): RenderHexCell[] {
    const player = getCurrentPlayer(this.gameState);
    const explored = this.gameState.exploredCells[player.id];
    const cells: RenderHexCell[] = [];

    for (const c of this.world.allCoordsArray()) {
      const k = key(c.q, c.r);
      const isExplored = explored.has(`${c.q},${c.r}`);

      const tile = this.tiles.get(k);
      const terrainComp = tile ? TileFactory.getTerrain(tile) : null;
      const terrain = terrainComp ? terrainToRender(terrainComp.type) : 'unknown';

      const cell: RenderHexCell = {
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
          } else if (this.validMoves.some(m => m.q === c.q && m.r === c.r)) {
            cell.highlight = 'move';
          } else if (this.validAttacks.some(m => m.q === c.q && m.r === c.r)) {
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

  getState(): GameControllerState {
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
      isHumanTurn: !!(player as any).isHuman,
      winner: this.gameState.winner,
    };
  }

  private notify(): void {
    if (this.onStateChange) this.onStateChange(this.getState());
  }

  private log(msg: string): void {
    if (this.onLog) this.onLog(msg);
    console.log(`[Sire] ${msg}`);
  }
}
