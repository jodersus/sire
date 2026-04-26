// ECS.ts — Sistema ECS ligero propio
// Base de todo el motor: entidades, componentes y sistemas.

export type EntityId = number;

/** Componente base. Todo componente es un objeto plano con datos. */
export interface Component {
  readonly __type: string;
}

/** Entidad: solo un ID y un mapa de componentes. */
export class Entity {
  readonly id: EntityId;
  private components = new Map<string, Component>();

  constructor(id: EntityId) {
    this.id = id;
  }

  add<T extends Component>(component: T): this {
    this.components.set(component.__type, component);
    return this;
  }

  remove(type: string): boolean {
    return this.components.delete(type);
  }

  get<T extends Component>(type: string): T | undefined {
    return this.components.get(type) as T | undefined;
  }

  has(type: string): boolean {
    return this.components.has(type);
  }

  hasAll(types: string[]): boolean {
    return types.every((t) => this.components.has(t));
  }

  /** Itera todos los componentes. */
  all(): IterableIterator<Component> {
    return this.components.values();
  }
}

/** Registro global de entidades. */
export class Registry {
  private nextId: EntityId = 1;
  private entities = new Map<EntityId, Entity>();

  create(): Entity {
    const e = new Entity(this.nextId++);
    this.entities.set(e.id, e);
    return e;
  }

  destroy(id: EntityId): boolean {
    return this.entities.delete(id);
  }

  get(id: EntityId): Entity | undefined {
    return this.entities.get(id);
  }

  /** Todas las entidades que tengan exactamente estos componentes. */
  query(...types: string[]): Entity[] {
    const out: Entity[] = [];
    for (const e of this.entities.values()) {
      if (e.hasAll(types)) out.push(e);
    }
    return out;
  }

  /** Iterador sobre todas las entidades. */
  all(): IterableIterator<Entity> {
    return this.entities.values();
  }

  count(): number {
    return this.entities.size;
  }
}

/** Un System recibe el Registry y actúa sobre las entidades que le interesen. */
export abstract class System {
  abstract update(registry: Registry, dt: number): void;
}

/** Mundo: junta Registry + Systems en un ciclo de update. */
export class World {
  registry = new Registry();
  private systems: System[] = [];

  add(system: System): this {
    this.systems.push(system);
    return this;
  }

  remove(system: System): boolean {
    const i = this.systems.indexOf(system);
    if (i === -1) return false;
    this.systems.splice(i, 1);
    return true;
  }

  update(dt: number = 0): void {
    for (const s of this.systems) {
      s.update(this.registry, dt);
    }
  }
}
