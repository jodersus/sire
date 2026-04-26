// ECS.ts — Sistema ECS ligero propio
// Base de todo el motor: entidades, componentes y sistemas.
/** Entidad: solo un ID y un mapa de componentes. */
export class Entity {
    id;
    components = new Map();
    constructor(id) {
        this.id = id;
    }
    add(component) {
        this.components.set(component.__type, component);
        return this;
    }
    remove(type) {
        return this.components.delete(type);
    }
    get(type) {
        return this.components.get(type);
    }
    has(type) {
        return this.components.has(type);
    }
    hasAll(types) {
        return types.every((t) => this.components.has(t));
    }
    /** Itera todos los componentes. */
    all() {
        return this.components.values();
    }
}
/** Registro global de entidades. */
export class Registry {
    nextId = 1;
    entities = new Map();
    create() {
        const e = new Entity(this.nextId++);
        this.entities.set(e.id, e);
        return e;
    }
    destroy(id) {
        return this.entities.delete(id);
    }
    get(id) {
        return this.entities.get(id);
    }
    /** Todas las entidades que tengan exactamente estos componentes. */
    query(...types) {
        const out = [];
        for (const e of this.entities.values()) {
            if (e.hasAll(types))
                out.push(e);
        }
        return out;
    }
    /** Iterador sobre todas las entidades. */
    all() {
        return this.entities.values();
    }
    count() {
        return this.entities.size;
    }
}
/** Un System recibe el Registry y actúa sobre las entidades que le interesen. */
export class System {
}
/** Mundo: junta Registry + Systems en un ciclo de update. */
export class World {
    registry = new Registry();
    systems = [];
    add(system) {
        this.systems.push(system);
        return this;
    }
    remove(system) {
        const i = this.systems.indexOf(system);
        if (i === -1)
            return false;
        this.systems.splice(i, 1);
        return true;
    }
    update(dt = 0) {
        for (const s of this.systems) {
            s.update(this.registry, dt);
        }
    }
}
