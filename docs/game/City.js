/**
 * Sire — Sistema de Ciudades
 *
 * Define los niveles de ciudad, población, producción,
 * territorio y los edificios disponibles.
 */
import { calculateCityIncome } from './Resources.js';
/** Nivel máximo de ciudad */
export const MAX_CITY_LEVEL = 5;
/** Población necesaria para subir de nivel */
export const POPULATION_PER_LEVEL = 3;
/** Expansión de territorio por nivel */
export const TERRITORY_RADIUS_PER_LEVEL = 2;
export const BUILDINGS = {
    port: {
        id: 'port',
        name: 'Puerto',
        cost: { stars: 5, wood: 2 },
        effect: 'Permite construir barcos. +2 de producción si hay agua adyacente.',
        bonus: { type: 'production', value: 2 },
    },
    mine: {
        id: 'mine',
        name: 'Mina',
        cost: { stars: 5, wood: 1 },
        effect: '+1 de producción por cada celda de montaña o piedra en el territorio.',
        bonus: { type: 'production', value: 1 },
    },
    lumber_mill: {
        id: 'lumber_mill',
        name: 'Aserradero',
        cost: { stars: 5, wood: 1 },
        effect: '+1 de producción por cada celda de bosque en el territorio.',
        bonus: { type: 'production', value: 1 },
    },
    forge: {
        id: 'forge',
        name: 'Forja',
        cost: { stars: 6, stone: 2, wood: 1 },
        effect: '+1 de defensa a las unidades entrenadas aquí.',
        bonus: { type: 'defense', value: 1 },
    },
    wall: {
        id: 'wall',
        name: 'Muralla',
        cost: { stars: 5, stone: 3 },
        effect: '+2 de defensa a la ciudad.',
        bonus: { type: 'defense', value: 2 },
    },
    temple: {
        id: 'temple',
        name: 'Templo',
        cost: { stars: 8, stone: 2 },
        effect: '+3 de población. +1 de visión.',
        bonus: { type: 'population', value: 3 },
    },
    park: {
        id: 'park',
        name: 'Parque',
        cost: { stars: 4, wood: 2, fruits: 1 },
        effect: '+2 de población.',
        bonus: { type: 'population', value: 2 },
    },
};
/** Crear una nueva ciudad nivel 1 */
export function createCity(id, name, ownerId, x, y) {
    return {
        id,
        name,
        ownerId,
        level: 1,
        population: 1,
        maxPopulation: POPULATION_PER_LEVEL * MAX_CITY_LEVEL,
        x,
        y,
        buildings: [],
        trainingQueue: [],
        territory: calculateTerritory(x, y, 1),
        storedProduction: 0,
    };
}
/** Calcular territorio según nivel */
export function calculateTerritory(cx, cy, level) {
    const radius = TERRITORY_RADIUS_PER_LEVEL + (level - 1);
    const cells = [];
    for (let dy = -radius; dy <= radius; dy++) {
        for (let dx = -radius; dx <= radius; dx++) {
            if (Math.abs(dx) + Math.abs(dy) <= radius) {
                cells.push({ x: cx + dx, y: cy + dy });
            }
        }
    }
    return cells;
}
/** Añadir población a una ciudad */
export function growPopulation(city, amount) {
    city.population = Math.min(city.population + amount, city.maxPopulation);
}
/** Subir de nivel si hay suficiente población */
export function checkLevelUp(city) {
    const required = city.level * POPULATION_PER_LEVEL;
    if (city.population >= required && city.level < MAX_CITY_LEVEL) {
        city.level++;
        city.territory = calculateTerritory(city.x, city.y, city.level);
        return true;
    }
    return false;
}
/** Obtener ingresos de estrellas de una ciudad */
export function getCityIncome(city) {
    const base = calculateCityIncome(city.level, city.population);
    let bonus = 0;
    for (const bId of city.buildings) {
        const building = BUILDINGS[bId];
        if (building?.bonus?.type === 'production') {
            bonus += building.bonus.value;
        }
    }
    return base + bonus;
}
/** Añadir unidad a cola de entrenamiento */
export function queueTraining(city, unitType, turns) {
    city.trainingQueue.push({ unitType, turnsRemaining: turns });
}
/** Procesar cola de entrenamiento (llamar al final del turno) */
export function processTrainingQueue(city) {
    const completed = [];
    for (const entry of city.trainingQueue) {
        entry.turnsRemaining--;
        if (entry.turnsRemaining <= 0) {
            completed.push(entry.unitType);
        }
    }
    city.trainingQueue = city.trainingQueue.filter(e => e.turnsRemaining > 0);
    return completed;
}
/** Verificar si una celda está dentro del territorio */
export function isInTerritory(city, x, y) {
    return city.territory.some(t => t.x === x && t.y === y);
}
/** Calcular defensa de la ciudad (para asedios) */
export function getCityDefense(city) {
    let defense = city.level; // base: nivel de ciudad
    for (const bId of city.buildings) {
        const building = BUILDINGS[bId];
        if (building?.bonus?.type === 'defense') {
            defense += building.bonus.value;
        }
    }
    return defense;
}
