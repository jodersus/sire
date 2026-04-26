/**
 * Sire — Sistema de Recursos
 *
 * Define los recursos disponibles en el juego, la economía base
 * y las fórmulas de producción/consumo.
 */

/** Tipos de recursos recolectables en el mapa */
export enum ResourceType {
  FRUITS = 'fruits',
  FISH = 'fish',
  WOOD = 'wood',
  STONE = 'stone',
  STARS = 'stars',
}

/** Recurso en una celda del mapa */
export interface CellResource {
  type: ResourceType;
  amount: number; // cantidad disponible en la celda
}

/** Bolsa de recursos de un jugador */
export interface ResourcePouch {
  stars: number;
  wood: number;
  stone: number;
  fruits: number;
  fish: number;
}

/** Coste de algo en recursos */
export type ResourceCost = Partial<Record<ResourceType, number>>;

/** Configuración económica del juego */
export const ECONOMY = {
  // Coste base de mantenimiento por unidad
  UNIT_MAINTENANCE: 1, // estrellas por turno

  // Coste base de fundar una ciudad
  CITY_FOUND_COST: 5, // estrellas

  // Produción base de una ciudad nivel 1
  CITY_BASE_PRODUCTION: 2, // estrellas por turno

  // Multiplicador de población → producción
  POPULATION_TO_PRODUCTION: 0.5,

  // Recolección manual por explorador
  EXPLORER_GATHER_AMOUNT: 2,
} as const;

/** Crear una bolsa de recursos vacía */
export function createEmptyPouch(): ResourcePouch {
  return {
    stars: 0,
    wood: 0,
    stone: 0,
    fruits: 0,
    fish: 0,
  };
}

/** Verificar si hay recursos suficientes */
export function canAfford(pouch: ResourcePouch, cost: ResourceCost): boolean {
  for (const [type, amount] of Object.entries(cost)) {
    if ((pouch[type as keyof ResourcePouch] ?? 0) < (amount ?? 0)) {
      return false;
    }
  }
  return true;
}

/** Gastar recursos (muta la bolsa) */
export function spendResources(pouch: ResourcePouch, cost: ResourceCost): boolean {
  if (!canAfford(pouch, cost)) return false;

  for (const [type, amount] of Object.entries(cost)) {
    const key = type as keyof ResourcePouch;
    (pouch[key] as number) -= (amount ?? 0);
  }
  return true;
}

/** Añadir recursos (muta la bolsa) */
export function addResources(pouch: ResourcePouch, gain: ResourceCost): void {
  for (const [type, amount] of Object.entries(gain)) {
    const key = type as keyof ResourcePouch;
    (pouch[key] as number) += (amount ?? 0);
  }
}

/** Obtener la producción de estrellas de una ciudad según su nivel y población */
export function calculateCityIncome(cityLevel: number, population: number): number {
  return Math.floor(
    ECONOMY.CITY_BASE_PRODUCTION +
    (cityLevel - 1) * 1 +
    population * ECONOMY.POPULATION_TO_PRODUCTION
  );
}
