// tests.ts — Tests unitarios básicos del motor
// Sin dependencias externas. Ejecuta con: node --experimental-strip-types --test src/engine/tests.ts
import assert from "node:assert";
import test from "node:test";
import { Entity, Registry, World } from "./ECS.js";
import { HexGrid } from "./HexGrid.js";
import { SphericalWorld } from "./SphericalWorld.js";
import { TerrainType, TileFactory, } from "./Tile.js";
import { MapGenerator } from "./MapGenerator.js";
// ─── ECS ─────────────────────────────────────────────────────────────────────
test("ECS: Entity add/get/has/remove", () => {
    const e = new Entity(1);
    const comp = { __type: "health", value: 100 };
    e.add(comp);
    assert.strictEqual(e.has("health"), true);
    assert.strictEqual(e.get("health")?.value, 100);
    e.remove("health");
    assert.strictEqual(e.has("health"), false);
});
test("ECS: Registry create/query/destroy", () => {
    const reg = new Registry();
    const e1 = reg.create();
    const e2 = reg.create();
    e1.add({ __type: "pos", x: 0 });
    e1.add({ __type: "vel", vx: 1 });
    e2.add({ __type: "pos", x: 5 });
    assert.strictEqual(reg.count(), 2);
    assert.strictEqual(reg.query("pos", "vel").length, 1);
    assert.strictEqual(reg.query("pos").length, 2);
    reg.destroy(e1.id);
    assert.strictEqual(reg.count(), 1);
});
test("ECS: World update runs systems", () => {
    let calls = 0;
    class CountSystem {
        update() { calls++; }
    }
    const w = new World();
    w.add(new CountSystem());
    w.update(1);
    assert.strictEqual(calls, 1);
});
// ─── HexGrid ─────────────────────────────────────────────────────────────────
test("HexGrid: bounds", () => {
    const g = new HexGrid(10, 10);
    assert.strictEqual(g.isInBounds({ q: 0, r: 0 }), true);
    assert.strictEqual(g.isInBounds({ q: 9, r: 9 }), true);
    assert.strictEqual(g.isInBounds({ q: 10, r: 5 }), false);
    assert.strictEqual(g.isInBounds({ q: -1, r: 5 }), false);
});
test("HexGrid: distance", () => {
    const g = new HexGrid(20, 20);
    assert.strictEqual(g.distance({ q: 0, r: 0 }, { q: 0, r: 0 }), 0);
    assert.strictEqual(g.distance({ q: 0, r: 0 }, { q: 3, r: 0 }), 3);
    assert.strictEqual(g.distance({ q: 0, r: 0 }, { q: 1, r: -1 }), 1);
    assert.strictEqual(g.distance({ q: 0, r: 0 }, { q: 2, r: -1 }), 2);
});
test("HexGrid: neighbors count", () => {
    const g = new HexGrid(20, 20);
    const center = { q: 5, r: 5 };
    const n = g.neighbors(center);
    assert.strictEqual(n.length, 6);
    const nb = g.neighborsInBounds(center);
    assert.strictEqual(nb.length, 6);
});
test("HexGrid: neighbors at edge filtered", () => {
    const g = new HexGrid(5, 5);
    const corner = { q: 0, r: 0 };
    const n = g.neighborsInBounds(corner);
    // En axial (0,0) solo E=(1,0) y NE=(0,1) están dentro
    assert.strictEqual(n.length, 2);
});
test("HexGrid: ring and spiral", () => {
    const g = new HexGrid(20, 20);
    const r1 = g.ring({ q: 10, r: 10 }, 1);
    assert.strictEqual(r1.length, 6);
    const r2 = g.ring({ q: 10, r: 10 }, 2);
    assert.strictEqual(r2.length, 12);
    const spiral = g.spiral({ q: 10, r: 10 }, 2);
    assert.strictEqual(spiral.length, 1 + 6 + 12);
});
test("HexGrid: index roundtrip", () => {
    const g = new HexGrid(10, 10);
    for (const c of g.allCoords()) {
        const idx = g.toIndex(c);
        const back = g.fromIndex(idx);
        assert.deepStrictEqual(back, c);
    }
});
// ─── SphericalWorld ──────────────────────────────────────────────────────────
test("SphericalWorld: wrap coordinates", () => {
    const w = new SphericalWorld(10, 10);
    assert.deepStrictEqual(w.wrap({ q: 10, r: 5 }), { q: 0, r: 5 });
    assert.deepStrictEqual(w.wrap({ q: -1, r: 5 }), { q: 9, r: 5 });
    assert.deepStrictEqual(w.wrap({ q: 3, r: 10 }), { q: 3, r: 0 });
    assert.deepStrictEqual(w.wrap({ q: 3, r: -1 }), { q: 3, r: 9 });
});
test("SphericalWorld: always 6 neighbors", () => {
    const w = new SphericalWorld(5, 5);
    const corner = { q: 0, r: 0 };
    const n = w.neighborsWrapped(corner);
    assert.strictEqual(n.length, 6);
    for (const c of n) {
        assert.strictEqual(w.isInBounds(c), true);
    }
});
test("SphericalWorld: distance wrapped shorter than direct", () => {
    const w = new SphericalWorld(20, 20);
    const a = { q: 0, r: 0 };
    const b = { q: 19, r: 0 };
    // Direct distance = 19; wrapped distance = 1 (se tocan por el borde)
    const direct = w.distance(a, b);
    const wrapped = w.distanceWrapped(a, b);
    assert.strictEqual(direct, 19);
    assert.strictEqual(wrapped, 1);
});
test("SphericalWorld: same after wrap", () => {
    const w = new SphericalWorld(10, 10);
    assert.strictEqual(w.same({ q: 0, r: 0 }, { q: 10, r: 0 }), true);
    assert.strictEqual(w.same({ q: 0, r: 0 }, { q: 0, r: 10 }), true);
    assert.strictEqual(w.same({ q: 1, r: 2 }, { q: 1, r: 2 }), true);
    assert.strictEqual(w.same({ q: 1, r: 2 }, { q: 2, r: 1 }), false);
});
// ─── Tile ────────────────────────────────────────────────────────────────────
test("Tile: factory creates entity with all components", () => {
    const reg = new Registry();
    const tile = TileFactory.create(reg, 3, 4, TerrainType.MOUNTAIN, 0.8);
    assert.strictEqual(tile.has("coord"), true);
    assert.strictEqual(tile.has("terrain"), true);
    assert.strictEqual(tile.has("resources"), true);
    assert.strictEqual(tile.has("occupants"), true);
    const coord = TileFactory.getCoord(tile);
    assert.strictEqual(coord.q, 3);
    assert.strictEqual(coord.r, 4);
    const terr = TileFactory.getTerrain(tile);
    assert.strictEqual(terr.type, TerrainType.MOUNTAIN);
    assert.strictEqual(terr.elevation, 0.8);
});
test("Tile: occupants add/remove", () => {
    const reg = new Registry();
    const tile = TileFactory.create(reg, 0, 0);
    const occ = TileFactory.getOccupants(tile);
    occ.add(42);
    occ.add(43);
    assert.deepStrictEqual(occ.ids, [42, 43]);
    occ.remove(42);
    assert.deepStrictEqual(occ.ids, [43]);
});
// ─── MapGenerator ─────────────────────────────────────────────────────────────
test("MapGenerator: generates correct grid size", () => {
    const reg = new Registry();
    const gen = new MapGenerator({ width: 10, height: 8, seed: 12345 });
    const world = gen.generate(reg);
    assert.strictEqual(world.width, 10);
    assert.strictEqual(world.height, 8);
    assert.strictEqual(world.totalCells(), 80);
    assert.strictEqual(reg.count(), 80);
});
test("MapGenerator: all tiles have terrain and resources", () => {
    const reg = new Registry();
    const gen = new MapGenerator({ width: 5, height: 5, seed: 999 });
    gen.generate(reg);
    for (const e of reg.all()) {
        assert.strictEqual(e.has("coord"), true);
        assert.strictEqual(e.has("terrain"), true);
        assert.strictEqual(e.has("resources"), true);
        const terr = TileFactory.getTerrain(e);
        assert.ok(Object.values(TerrainType).includes(terr.type));
    }
});
test("MapGenerator: deterministic with same seed", () => {
    const reg1 = new Registry();
    const reg2 = new Registry();
    const gen1 = new MapGenerator({ width: 5, height: 5, seed: 777 });
    const gen2 = new MapGenerator({ width: 5, height: 5, seed: 777 });
    const w1 = gen1.generate(reg1);
    const w2 = gen2.generate(reg2);
    const tiles1 = reg1.query("terrain").map((e) => TileFactory.getTerrain(e).type);
    const tiles2 = reg2.query("terrain").map((e) => TileFactory.getTerrain(e).type);
    assert.deepStrictEqual(tiles1, tiles2);
});
test("MapGenerator: different seeds produce different maps", () => {
    const reg1 = new Registry();
    const reg2 = new Registry();
    const gen1 = new MapGenerator({ width: 10, height: 10, seed: 111 });
    const gen2 = new MapGenerator({ width: 10, height: 10, seed: 222 });
    gen1.generate(reg1);
    gen2.generate(reg2);
    const tiles1 = reg1.query("terrain").map((e) => TileFactory.getTerrain(e).type);
    const tiles2 = reg2.query("terrain").map((e) => TileFactory.getTerrain(e).type);
    assert.notDeepStrictEqual(tiles1, tiles2);
});
// ─── Integración ─────────────────────────────────────────────────────────────
test("Integration: spherical world + tiles + ECS", () => {
    const reg = new Registry();
    const world = new SphericalWorld(6, 6);
    const gen = new MapGenerator({ width: 6, height: 6, seed: 42 });
    gen.generate(reg);
    // Verificar que podemos consultar tiles por coordenadas
    const tiles = reg.query("coord");
    assert.strictEqual(tiles.length, 36);
    // Tomar una tile de borde y verificar wrap de vecinos
    const edgeTile = tiles.find((e) => {
        const c = TileFactory.getCoord(e);
        return c.q === 0 && c.r === 0;
    });
    const coord = TileFactory.getCoord(edgeTile);
    const wrappedNeighbors = world.neighborsWrapped(coord);
    assert.strictEqual(wrappedNeighbors.length, 6);
    // Uno de los vecinos debe aparecer por el otro lado
    const neighborQs = wrappedNeighbors.map((n) => n.q);
    assert.ok(neighborQs.includes(5), "Vecino debería wrap desde q=5");
});
