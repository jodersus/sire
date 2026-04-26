/**
 * Sire — Sistema de Recursos
 *
 * Define los recursos disponibles en el juego, la economía base
 * y las fórmulas de producción/consumo.
 */
/** Tipos de recursos recolectables en el mapa */
export var ResourceType;
(function (ResourceType) {
    ResourceType["FRUITS"] = "fruits";
    ResourceType["FISH"] = "fish";
    ResourceType["WOOD"] = "wood";
    ResourceType["STONE"] = "stone";
    ResourceType["STARS"] = "stars";
})(ResourceType || (ResourceType = {}));
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
};
/** Crear una bolsa de recursos vacía */
export function createEmptyPouch() {
    return {
        stars: 0,
        wood: 0,
        stone: 0,
        fruits: 0,
        fish: 0,
    };
}
/** Verificar si hay recursos suficientes */
export function canAfford(pouch, cost) {
    for (const [type, amount] of Object.entries(cost)) {
        if ((pouch[type] ?? 0) < (amount ?? 0)) {
            return false;
        }
    }
    return true;
}
/** Gastar recursos (muta la bolsa) */
export function spendResources(pouch, cost) {
    if (!canAfford(pouch, cost))
        return false;
    for (const [type, amount] of Object.entries(cost)) {
        const key = type;
        pouch[key] -= (amount ?? 0);
    }
    return true;
}
/** Añadir recursos (muta la bolsa) */
export function addResources(pouch, gain) {
    for (const [type, amount] of Object.entries(gain)) {
        const key = type;
        pouch[key] += (amount ?? 0);
    }
}
/** Obtener la producción de estrellas de una ciudad según su nivel y población */
export function calculateCityIncome(cityLevel, population) {
    return Math.floor(ECONOMY.CITY_BASE_PRODUCTION +
        (cityLevel - 1) * 1 +
        population * ECONOMY.POPULATION_TO_PRODUCTION);
}
