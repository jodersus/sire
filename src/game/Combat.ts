/**
 * Sire — Sistema de Combate
 *
 * Define la resolución de combates por turnos entre unidades,
 * con soporte para bonos de terreno, flanqueo y asedios.
 */

import { UnitDefinition, UnitType, getUnit } from './Units.js';
import { City, getCityDefense } from './City.js';

/** Resultado de un combate */
export interface CombatResult {
  attackerWins: boolean;
  attackerDamageDealt: number;
  defenderDamageDealt: number;
  attackerSurvives: boolean;
  defenderSurvives: boolean;
}

/** Estado mutable de una unidad en combate */
export interface UnitInstance {
  id: string;
  type: UnitType;
  ownerId: string;
  health: number;
  maxHealth: number;
  attack: number;
  defense: number;
  movementRemaining: number;
  hasAttackedThisTurn: boolean;

  // Posición
  x: number;
  y: number;
}

/** Crear instancia de unidad desde definición */
export function createUnitInstance(
  id: string,
  type: UnitType,
  ownerId: string,
  x: number,
  y: number
): UnitInstance {
  const def = getUnit(type);
  return {
    id,
    type,
    ownerId,
    health: def.health,
    maxHealth: def.health,
    attack: def.attack,
    defense: def.defense,
    movementRemaining: def.movement,
    hasAttackedThisTurn: false,
    x,
    y,
  };
}

/** Modificadores de terreno */
export const TERRAIN_MODIFIERS: Record<string, { attack?: number; defense?: number }> = {
  forest: { defense: 1 },
  mountain: { defense: 2 },
  water: { defense: 0 },
  plain: {},
  city: { defense: 2 },
};

/** Calcular daño de un atacante contra un defensor */
export function calculateDamage(
  attacker: UnitInstance,
  defender: UnitInstance,
  attackerTerrain?: string,
  defenderTerrain?: string,
  // Bono de tribu Ferrum
  tribeAttackBonus: number = 0
): { attackerDealt: number; defenderDealt: number } {
  const def = getUnit(attacker.type);
  const isRanged = def.attackRange > 1;

  // Ataque del atacante
  let attackPower = attacker.attack + tribeAttackBonus;
  if (attackerTerrain) {
    attackPower += TERRAIN_MODIFIERS[attackerTerrain]?.attack ?? 0;
  }

  // Defensa del defensor
  let defensePower = defender.defense;
  if (defenderTerrain) {
    defensePower += TERRAIN_MODIFIERS[defenderTerrain]?.defense ?? 0;
  }

  // Fórmula base: ataque - defensa, mínimo 0
  let attackerDealt = Math.max(0, attackPower - defensePower);
  // Garantizar al menos 1 de daño si el ataque es mayor que 0
  if (attacker.attack > 0 && attackerDealt === 0) {
    attackerDealt = 1;
  }

  // Contraataque: el defensor golpea de vuelta si es cuerpo a cuerpo
  let defenderDealt = 0;
  if (!isRanged && !defender.hasAttackedThisTurn) {
    const defDef = getUnit(defender.type);
    const isDefenderRanged = defDef.attackRange > 1;

    if (!isDefenderRanged) {
      let defAttackPower = defender.attack;
      if (defenderTerrain) {
        defAttackPower += TERRAIN_MODIFIERS[defenderTerrain]?.attack ?? 0;
      }
      let atkDefense = attacker.defense;
      if (attackerTerrain) {
        atkDefense += TERRAIN_MODIFIERS[attackerTerrain]?.defense ?? 0;
      }
      defenderDealt = Math.max(0, defAttackPower - atkDefense);
      if (defender.attack > 0 && defenderDealt === 0) {
        defenderDealt = 1;
      }
    }
  }

  return { attackerDealt, defenderDealt };
}

/** Resolver un combate unidad vs unidad */
export function resolveCombat(
  attacker: UnitInstance,
  defender: UnitInstance,
  attackerTerrain?: string,
  defenderTerrain?: string,
  tribeAttackBonus: number = 0
): CombatResult {
  const { attackerDealt, defenderDealt } = calculateDamage(
    attacker, defender, attackerTerrain, defenderTerrain, tribeAttackBonus
  );

  defender.health -= attackerDealt;
  attacker.health -= defenderDealt;

  const attackerSurvives = attacker.health > 0;
  const defenderSurvives = defender.health > 0;

  attacker.hasAttackedThisTurn = true;

  return {
    attackerWins: attackerSurvives && !defenderSurvives,
    attackerDamageDealt: attackerDealt,
    defenderDamageDealt: defenderDealt,
    attackerSurvives,
    defenderSurvives,
  };
}

/** Resolver asedio: unidad atacante vs ciudad */
export function resolveSiege(
  attacker: UnitInstance,
  city: City,
  attackerTerrain?: string,
  tribeAttackBonus: number = 0
): { cityCaptured: boolean; damageDealt: number } {
  const cityDefense = getCityDefense(city);

  let attackPower = attacker.attack + tribeAttackBonus;
  if (attackerTerrain) {
    attackPower += TERRAIN_MODIFIERS[attackerTerrain]?.attack ?? 0;
  }

  // Daño al "defensa de ciudad" — simplificación: cada golpe reduce defensa
  const damageDealt = Math.max(1, attackPower - Math.floor(cityDefense / 2));

  // La ciudad se captura si el defensa cae a 0 (requiere múltiples turnos)
  // En esta simplificación, un ataque directo captura si el atacante supera defensa total
  const cityCaptured = attackPower > cityDefense;

  return { cityCaptured, damageDealt };
}

/** Verificar si una unidad puede atacar a otra (rango) */
export function canAttackTarget(
  attacker: UnitInstance,
  defender: UnitInstance,
  attackerDef: UnitDefinition
): boolean {
  const dx = Math.abs(attacker.x - defender.x);
  const dy = Math.abs(attacker.y - defender.y);
  const distance = Math.max(dx, dy);
  return distance <= attackerDef.attackRange && !attacker.hasAttackedThisTurn;
}

/** Resetear estado de unidad para nuevo turno */
export function resetUnitForTurn(unit: UnitInstance, def: UnitDefinition): void {
  unit.movementRemaining = def.movement;
  unit.hasAttackedThisTurn = false;
}

/** Curar unidad al final del turno si está en territorio propio */
export function healUnit(unit: UnitInstance, amount: number = 1): void {
  unit.health = Math.min(unit.maxHealth, unit.health + amount);
}
