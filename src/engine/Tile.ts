// Tile.ts — Entidad tile con componentes
// Cada tile del mapa es una entidad ECS con componentes específicos.

import { Entity, Registry } from "./ECS.js";
import type { Component, EntityId } from "./ECS.js";

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
} as const;

export type TerrainType = (typeof TerrainType)[keyof typeof TerrainType];

/** Componente de terreno: tipo y elevación base. */
export class TerrainComponent implements Component {
  readonly __type = "terrain";
  type: TerrainType;
  elevation: number;
  constructor(type: TerrainType, elevation: number = 0) {
    this.type = type;
    this.elevation = elevation;
  }
}

/** Componente de recursos: qué recursos naturales hay en la tile. */
export class ResourceComponent implements Component {
  readonly __type = "resources";
  fish: number;
  wood: number;
  ore: number;
  fertility: number;
  constructor(fish: number = 0, wood: number = 0, ore: number = 0, fertility: number = 0) {
    this.fish = fish;
    this.wood = wood;
    this.ore = ore;
    this.fertility = fertility;
  }
}

/** Componente de ocupantes: entidades presentes en la tile (unidades, ciudades...). */
export class OccupantComponent implements Component {
  readonly __type = "occupants";
  /** IDs de entidades ubicadas en esta tile. */
  public ids: EntityId[] = [];
  add(id: EntityId): void {
    if (!this.ids.includes(id)) this.ids.push(id);
  }
  remove(id: EntityId): void {
    const i = this.ids.indexOf(id);
    if (i !== -1) this.ids.splice(i, 1);
  }
}

/** Componente de coordenadas: posición en el grid. */
export class CoordComponent implements Component {
  readonly __type = "coord";
  q: number;
  r: number;
  constructor(q: number, r: number) {
    this.q = q;
    this.r = r;
  }
}

/** Factoría para crear tiles como entidades ECS. */
export class TileFactory {
  static create(
    registry: Registry,
    q: number,
    r: number,
    terrain: TerrainType = TerrainType.GRASS,
    elevation: number = 0
  ): Entity {
    const entity = registry.create();
    entity
      .add(new CoordComponent(q, r))
      .add(new TerrainComponent(terrain, elevation))
      .add(new ResourceComponent())
      .add(new OccupantComponent());
    return entity;
  }

  /** Helper: obtiene el componente de terreno de una entidad tile. */
  static getTerrain(entity: Entity): TerrainComponent | undefined {
    return entity.get<TerrainComponent>("terrain");
  }

  /** Helper: obtiene el componente de coordenadas. */
  static getCoord(entity: Entity): CoordComponent | undefined {
    return entity.get<CoordComponent>("coord");
  }

  /** Helper: obtiene el componente de recursos. */
  static getResources(entity: Entity): ResourceComponent | undefined {
    return entity.get<ResourceComponent>("resources");
  }

  /** Helper: obtiene el componente de ocupantes. */
  static getOccupants(entity: Entity): OccupantComponent | undefined {
    return entity.get<OccupantComponent>("occupants");
  }
}
