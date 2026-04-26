// Tile.ts — Entidad tile con componentes
// Cada tile del mapa es una entidad ECS con componentes específicos.
/** Tipos de terreno disponibles. */
export const TerrainType = {
    DEEP_WATER: "deep_water",
    SHALLOW_WATER: "shallow_water",
    SAND: "sand",
    GRASS: "grass",
    FOREST: "forest",
    HILL: "hill",
    MOUNTAIN: "mountain",
    VOLCANO: "volcano",
};
/** Componente de terreno: tipo y elevación base. */
export class TerrainComponent {
    __type = "terrain";
    type;
    elevation;
    constructor(type, elevation = 0) {
        this.type = type;
        this.elevation = elevation;
    }
}
/** Componente de recursos: qué recursos naturales hay en la tile. */
export class ResourceComponent {
    __type = "resources";
    fish;
    wood;
    ore;
    fertility;
    constructor(fish = 0, wood = 0, ore = 0, fertility = 0) {
        this.fish = fish;
        this.wood = wood;
        this.ore = ore;
        this.fertility = fertility;
    }
}
/** Componente de ocupantes: entidades presentes en la tile (unidades, ciudades...). */
export class OccupantComponent {
    __type = "occupants";
    /** IDs de entidades ubicadas en esta tile. */
    ids = [];
    add(id) {
        if (!this.ids.includes(id))
            this.ids.push(id);
    }
    remove(id) {
        const i = this.ids.indexOf(id);
        if (i !== -1)
            this.ids.splice(i, 1);
    }
}
/** Componente de coordenadas: posición en el grid. */
export class CoordComponent {
    __type = "coord";
    q;
    r;
    constructor(q, r) {
        this.q = q;
        this.r = r;
    }
}
/** Factoría para crear tiles como entidades ECS. */
export class TileFactory {
    static create(registry, q, r, terrain = TerrainType.GRASS, elevation = 0) {
        const entity = registry.create();
        entity
            .add(new CoordComponent(q, r))
            .add(new TerrainComponent(terrain, elevation))
            .add(new ResourceComponent())
            .add(new OccupantComponent());
        return entity;
    }
    /** Helper: obtiene el componente de terreno de una entidad tile. */
    static getTerrain(entity) {
        return entity.get("terrain");
    }
    /** Helper: obtiene el componente de coordenadas. */
    static getCoord(entity) {
        return entity.get("coord");
    }
    /** Helper: obtiene el componente de recursos. */
    static getResources(entity) {
        return entity.get("resources");
    }
    /** Helper: obtiene el componente de ocupantes. */
    static getOccupants(entity) {
        return entity.get("occupants");
    }
}
