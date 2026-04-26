/**
 * Sire — Definición de Tribus
 *
 * Cada tribu tiene un nombre, color identificativo, una habilidad
 * especial pasiva y una unidad inicial modificada.
 */

import { UnitType } from './Units';
import { ResourceCost } from './Resources';

export interface TribeAbility {
  name: string;
  description: string;
  // Efecto clave para lógica posterior
  effect: 'discount_stars' | 'discount_wood' | 'discount_stone' | 'movement_bonus' |
          'combat_bonus' | 'vision_bonus' | 'city_growth_bonus' | 'naval_bonus';
  value: number; // valor numérico del bono (porcentaje o absoluto)
}

export interface Tribe {
  id: string;
  name: string;
  color: string; // hex color
  secondaryColor: string;
  ability: TribeAbility;
  startingUnit: UnitType;
  // Tecnologías iniciales desbloqueadas
  startingTechs: string[];
}

export const TRIBES: Record<string, Tribe> = {
  solaris: {
    id: 'solaris',
    name: 'Solaris',
    color: '#F4D03F',
    secondaryColor: '#D4AC0D',
    ability: {
      name: 'Avance Rápido',
      description: '-20% de coste en tecnologías.',
      effect: 'discount_stars',
      value: 20,
    },
    startingUnit: UnitType.EXPLORER,
    startingTechs: ['navigation'],
  },

  umbra: {
    id: 'umbra',
    name: 'Umbra',
    color: '#2C3E50',
    secondaryColor: '#1A252F',
    ability: {
      name: 'Sombras',
      description: '+1 de visión para todas las unidades.',
      effect: 'vision_bonus',
      value: 1,
    },
    startingUnit: UnitType.WARRIOR,
    startingTechs: ['archery'],
  },

  sylva: {
    id: 'sylva',
    name: 'Sylva',
    color: '#27AE60',
    secondaryColor: '#1E8449',
    ability: {
      name: 'Bosque Frondoso',
      description: '-30% de coste en unidades de madera.',
      effect: 'discount_wood',
      value: 30,
    },
    startingUnit: UnitType.EXPLORER,
    startingTechs: ['forestry'],
  },

  ferrum: {
    id: 'ferrum',
    name: 'Ferrum',
    color: '#922B21',
    secondaryColor: '#641E16',
    ability: {
      name: 'Acero Forjado',
      description: '+1 de ataque para todas las unidades terrestres.',
      effect: 'combat_bonus',
      value: 1,
    },
    startingUnit: UnitType.WARRIOR,
    startingTechs: ['smithing'],
  },

  maris: {
    id: 'maris',
    name: 'Maris',
    color: '#3498DB',
    secondaryColor: '#2471A3',
    ability: {
      name: 'Dominio Marino',
      description: '+1 de movimiento en agua. -20% de coste en barcos.',
      effect: 'naval_bonus',
      value: 20,
    },
    startingUnit: UnitType.BOAT,
    startingTechs: ['sailing'],
  },

  equus: {
    id: 'equus',
    name: 'Equus',
    color: '#E67E22',
    secondaryColor: '#BA4A00',
    ability: {
      name: 'Crianza',
      description: '+1 de movimiento para unidades a caballo.',
      effect: 'movement_bonus',
      value: 1,
    },
    startingUnit: UnitType.RIDER,
    startingTechs: ['riding'],
  },

  nomad: {
    id: 'nomad',
    name: 'Nomad',
    color: '#8E44AD',
    secondaryColor: '#6C3483',
    ability: {
      name: 'Crecimiento Expansivo',
      description: 'Las ciudades crecen un 25% más rápido.',
      effect: 'city_growth_bonus',
      value: 25,
    },
    startingUnit: UnitType.EXPLORER,
    startingTechs: ['organization'],
  },
};

/** Lista ordenada de tribus disponibles */
export const TRIBE_LIST = Object.values(TRIBES);

/** Obtener una tribu por ID */
export function getTribe(id: string): Tribe | undefined {
  return TRIBES[id];
}

/** Calcular coste con posible descuento de tribu */
export function applyTribeDiscount(
  tribe: Tribe,
  cost: ResourceCost,
  effectType: TribeAbility['effect']
): ResourceCost {
  if (tribe.ability.effect !== effectType) return { ...cost };

  const discounted: ResourceCost = {};
  const multiplier = 1 - tribe.ability.value / 100;

  for (const [type, amount] of Object.entries(cost)) {
    discounted[type as keyof ResourceCost] = Math.ceil((amount ?? 0) * multiplier);
  }
  return discounted;
}
