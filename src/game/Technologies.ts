/**
 * Sire — Árbol Tecnológico
 *
 * Define las tecnologías desbloqueables, sus costes en estrellas,
 * prerequisitos y los desbloqueos que proporcionan (unidades,
 * edificios, habilidades pasivas).
 */

import { ResourceCost } from './Resources';
import { UnitType } from './Units';

export interface Technology {
  id: string;
  name: string;
  description: string;
  cost: number; // estrellas
  prerequisites: string[]; // ids de tecnologías previas
  unlocks: {
    units?: UnitType[];
    buildings?: string[];
    abilities?: string[];
  };
  // Si es tecnología de inicio (no requiere investigación)
  isStarting?: boolean;
}

export const TECHNOLOGIES: Record<string, Technology> = {
  // ─── Rama de Organización ───
  organization: {
    id: 'organization',
    name: 'Organización',
    description: 'Permite fundar ciudades.',
    cost: 0,
    prerequisites: [],
    isStarting: true,
    unlocks: {},
  },

  climbing: {
    id: 'climbing',
    name: 'Escalada',
    description: 'Las unidades pueden moverse por montañas.',
    cost: 3,
    prerequisites: ['organization'],
    unlocks: {},
  },

  mining: {
    id: 'mining',
    name: 'Minería',
    description: 'Permite recolectar piedra y construir minas.',
    cost: 5,
    prerequisites: ['climbing'],
    unlocks: { buildings: ['mine'] },
  },

  // ─── Rama de Caza ───
  hunting: {
    id: 'hunting',
    name: 'Caza',
    description: 'Permite recolectar frutas y pescado con mayor eficiencia.',
    cost: 0,
    prerequisites: [],
    isStarting: true,
    unlocks: {},
  },

  archery: {
    id: 'archery',
    name: 'Tiro con Arco',
    description: 'Desbloquea al Arquero.',
    cost: 6,
    prerequisites: ['hunting'],
    unlocks: { units: [UnitType.ARCHER] },
  },

  forestry: {
    id: 'forestry',
    name: 'Silvicultura',
    description: 'Permite recolectar madera y construir aserraderos.',
    cost: 5,
    prerequisites: ['hunting'],
    unlocks: { buildings: ['lumber_mill'] },
  },

  // ─── Rama de Equitación ───
  riding: {
    id: 'riding',
    name: 'Equitación',
    description: 'Desbloquea al Jinete.',
    cost: 5,
    prerequisites: ['hunting'],
    unlocks: { units: [UnitType.RIDER] },
  },

  chivalry: {
    id: 'chivalry',
    name: 'Caballería',
    description: 'Desbloquea al Caballero (unidad de élite a caballo).',
    cost: 12,
    prerequisites: ['riding', 'smithing'],
    unlocks: { units: [UnitType.KNIGHT] },
  },

  // ─── Rama de Navegación ───
  navigation: {
    id: 'navigation',
    name: 'Navegación',
    description: 'Permite mover unidades por el agua.',
    cost: 0,
    prerequisites: [],
    isStarting: true,
    unlocks: {},
  },

  sailing: {
    id: 'sailing',
    name: 'Navegación Costera',
    description: 'Desbloquea el Barco.',
    cost: 5,
    prerequisites: ['navigation'],
    unlocks: { units: [UnitType.BOAT] },
  },

  navigation_deep: {
    id: 'navigation_deep',
    name: 'Navegación Profunda',
    description: 'Desbloquea el Buque de Guerra.',
    cost: 10,
    prerequisites: ['sailing', 'archery'],
    unlocks: { units: [UnitType.WARSHIP] },
  },

  // ─── Rama de Herrería ───
  smithing: {
    id: 'smithing',
    name: 'Herrería',
    description: 'Mejora la defensa de unidades y desbloquea la Forja.',
    cost: 6,
    prerequisites: ['organization'],
    unlocks: { buildings: ['forge'] },
  },

  shields: {
    id: 'shields',
    name: 'Escudos',
    description: '+1 de defensa para Guerreros y Caballeros.',
    cost: 6,
    prerequisites: ['smithing'],
    unlocks: {},
  },

  // ─── Rama de Construcción ───
  construction: {
    id: 'construction',
    name: 'Construcción',
    description: 'Permite construir muros alrededor de ciudades.',
    cost: 5,
    prerequisites: ['organization'],
    unlocks: { buildings: ['wall'] },
  },

  architecture: {
    id: 'architecture',
    name: 'Arquitectura',
    description: 'Las ciudades pueden alcanzar nivel máximo.',
    cost: 10,
    prerequisites: ['construction', 'mining'],
    unlocks: {},
  },
};

/** Lista ordenada alfabéticamente */
export const TECH_LIST = Object.values(TECHNOLOGIES);

/** Verificar si una tecnología puede investigarse */
export function canResearch(techId: string, unlocked: Set<string>): boolean {
  const tech = TECHNOLOGIES[techId];
  if (!tech) return false;
  if (unlocked.has(techId)) return false;
  if (tech.isStarting) return true;
  return tech.prerequisites.every(prereq => unlocked.has(prereq));
}

/** Obtener tecnologías disponibles para investigar */
export function getAvailableTechs(unlocked: Set<string>): Technology[] {
  return TECH_LIST.filter(t => canResearch(t.id, unlocked));
}

/** Calcular coste con bono de tribu Solaris */
export function calculateTechCost(baseCost: number, tribeAbility?: string): number {
  if (tribeAbility === 'discount_stars') {
    return Math.ceil(baseCost * 0.8);
  }
  return baseCost;
}
