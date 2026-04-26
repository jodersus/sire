/**
 * Sire — Tipos de Unidades
 *
 * Define todas las unidades jugables con sus estadísticas,
 * costes de entrenamiento y capacidades especiales.
 */
export var UnitType;
(function (UnitType) {
    UnitType["EXPLORER"] = "explorer";
    UnitType["WARRIOR"] = "warrior";
    UnitType["ARCHER"] = "archer";
    UnitType["RIDER"] = "rider";
    UnitType["KNIGHT"] = "knight";
    UnitType["BOAT"] = "boat";
    UnitType["WARSHIP"] = "warship";
    // Unidades especiales
    UnitType["CATAPULT"] = "catapult";
    UnitType["GIANT"] = "giant";
})(UnitType || (UnitType = {}));
export var UnitClass;
(function (UnitClass) {
    UnitClass["INFANTRY"] = "infantry";
    UnitClass["RANGED"] = "ranged";
    UnitClass["CAVALRY"] = "cavalry";
    UnitClass["NAVAL"] = "naval";
    UnitClass["SIEGE"] = "siege";
    UnitClass["SPECIAL"] = "special";
})(UnitClass || (UnitClass = {}));
export const UNITS = {
    [UnitType.EXPLORER]: {
        type: UnitType.EXPLORER,
        name: 'Explorador',
        class: UnitClass.INFANTRY,
        health: 10,
        attack: 1,
        defense: 1,
        movement: 2,
        terrain: ['land'],
        cost: { stars: 2 },
        abilities: ['explore', 'gather'],
        attackRange: 1,
    },
    [UnitType.WARRIOR]: {
        type: UnitType.WARRIOR,
        name: 'Guerrero',
        class: UnitClass.INFANTRY,
        health: 15,
        attack: 2,
        defense: 2,
        movement: 1,
        terrain: ['land'],
        cost: { stars: 3, wood: 1 },
        abilities: ['fortify'],
        attackRange: 1,
        upgradeTo: UnitType.KNIGHT,
    },
    [UnitType.ARCHER]: {
        type: UnitType.ARCHER,
        name: 'Arquero',
        class: UnitClass.RANGED,
        health: 10,
        attack: 2,
        defense: 1,
        movement: 1,
        terrain: ['land'],
        cost: { stars: 3, wood: 2 },
        abilities: ['ranged_attack'],
        attackRange: 2,
    },
    [UnitType.RIDER]: {
        type: UnitType.RIDER,
        name: 'Jinete',
        class: UnitClass.CAVALRY,
        health: 12,
        attack: 2,
        defense: 1,
        movement: 3,
        terrain: ['land'],
        cost: { stars: 4, wood: 1, fruits: 1 },
        abilities: ['flanking'],
        attackRange: 1,
    },
    [UnitType.KNIGHT]: {
        type: UnitType.KNIGHT,
        name: 'Caballero',
        class: UnitClass.CAVALRY,
        health: 20,
        attack: 4,
        defense: 3,
        movement: 3,
        terrain: ['land'],
        cost: { stars: 8, stone: 2, wood: 1 },
        abilities: ['flanking', 'charge'],
        attackRange: 1,
    },
    [UnitType.BOAT]: {
        type: UnitType.BOAT,
        name: 'Barco',
        class: UnitClass.NAVAL,
        health: 15,
        attack: 2,
        defense: 2,
        movement: 3,
        terrain: ['water'],
        cost: { stars: 4, wood: 2 },
        abilities: ['transport'],
        attackRange: 1,
        upgradeTo: UnitType.WARSHIP,
    },
    [UnitType.WARSHIP]: {
        type: UnitType.WARSHIP,
        name: 'Buque de Guerra',
        class: UnitClass.NAVAL,
        health: 25,
        attack: 4,
        defense: 3,
        movement: 3,
        terrain: ['water'],
        cost: { stars: 8, wood: 4 },
        abilities: ['bombard'],
        attackRange: 2,
    },
    [UnitType.CATAPULT]: {
        type: UnitType.CATAPULT,
        name: 'Catapulta',
        class: UnitClass.SIEGE,
        health: 10,
        attack: 4,
        defense: 0,
        movement: 1,
        terrain: ['land'],
        cost: { stars: 6, stone: 3, wood: 2 },
        abilities: ['siege', 'splash_damage'],
        attackRange: 3,
    },
    [UnitType.GIANT]: {
        type: UnitType.GIANT,
        name: 'Gigante',
        class: UnitClass.SPECIAL,
        health: 40,
        attack: 5,
        defense: 4,
        movement: 1,
        terrain: ['land'],
        cost: { stars: 20 },
        abilities: ['crushing'],
        attackRange: 1,
    },
};
/** Lista de todas las unidades */
export const UNIT_LIST = Object.values(UNITS);
/** Obtener definición de unidad */
export function getUnit(type) {
    return UNITS[type];
}
/** Verificar si una unidad puede moverse por un terreno */
export function canTraverse(unit, terrain) {
    return unit.terrain.includes('all') || unit.terrain.includes(terrain);
}
/** Verificar si una unidad puede atacar a distancia */
export function isRanged(unit) {
    return unit.attackRange > 1;
}
