// MapGenerator.ts — Generación procedural básica de mapa
// Crea un mundo con terrenos variados usando ruido simple (sin deps externas).
import { TerrainType, TileFactory } from "./Tile.js";
import { SphericalWorld } from "./SphericalWorld.js";
/** Semilla de ruido: hash 2D + fbm para reproducibilidad. */
class SimpleNoise {
    seed;
    constructor(seed = 0) {
        this.seed = seed === 0 ? 12345 : seed;
    }
    /** Hash 2D basado en bit-mixing. Devuelve valor en [0, 1]. */
    hash2D(x, y) {
        let h = this.seed;
        h ^= Math.imul(Math.floor(x), 0x45d9f3b);
        h ^= Math.imul(Math.floor(y), 0x45d9f3b);
        h = (h ^ (h >>> 16)) * 0x45d9f3b;
        h = (h ^ (h >>> 16)) * 0x45d9f3b;
        h = h ^ (h >>> 16);
        return (h >>> 0) / 0xffffffff;
    }
    /** Interpolación bilineal suave del hash en celda entera. */
    noise2D(x, y) {
        const ix = Math.floor(x);
        const iy = Math.floor(y);
        const fx = x - ix;
        const fy = y - iy;
        const n00 = this.hash2D(ix, iy);
        const n10 = this.hash2D(ix + 1, iy);
        const n01 = this.hash2D(ix, iy + 1);
        const n11 = this.hash2D(ix + 1, iy + 1);
        // Smoothstep para evitar artefactos de bordes
        const sx = fx * fx * (3 - 2 * fx);
        const sy = fy * fy * (3 - 2 * fy);
        const nx0 = n00 + (n10 - n00) * sx;
        const nx1 = n01 + (n11 - n01) * sx;
        return nx0 + (nx1 - nx0) * sy;
    }
    /** Ruido de múltiples octavas (fractional Brownian motion). */
    fbm(x, y, octaves = 4) {
        let value = 0;
        let amplitude = 0.5;
        let frequency = 1;
        let maxValue = 0;
        for (let i = 0; i < octaves; i++) {
            value += this.noise2D(x * frequency, y * frequency) * amplitude;
            maxValue += amplitude;
            amplitude *= 0.5;
            frequency *= 2;
        }
        return value / maxValue;
    }
}
export class MapGenerator {
    noise;
    config;
    constructor(config) {
        this.config = {
            seed: config.seed ?? Math.floor(Math.random() * 100000),
            waterLevel: config.waterLevel ?? 0.35,
            mountainLevel: config.mountainLevel ?? 0.75,
            width: config.width,
            height: config.height,
        };
        this.noise = new SimpleNoise(this.config.seed);
    }
    /** Genera un mundo esférico con tiles y terreno. */
    generate(registry) {
        const world = new SphericalWorld(this.config.width, this.config.height);
        for (const c of world.allCoords()) {
            // Normalizar coordenadas a [0, 1] para el ruido
            const nx = c.q / this.config.width;
            const ny = c.r / this.config.height;
            // Ruido fractal para terreno
            const elevation = this.noise.fbm(nx * 3, ny * 3, 4);
            // Ruido adicional para variación local
            const moisture = this.noise.fbm(nx * 5 + 100, ny * 5 + 100, 3);
            const terrain = this.pickTerrain(elevation, moisture);
            const tile = TileFactory.create(registry, c.q, c.r, terrain, elevation);
            // Asignar recursos según terreno
            const res = TileFactory.getResources(tile);
            if (res)
                this.assignResources(res, terrain, moisture);
        }
        return world;
    }
    pickTerrain(e, m) {
        if (e < this.config.waterLevel * 0.5)
            return TerrainType.DEEP_WATER;
        if (e < this.config.waterLevel)
            return TerrainType.SHALLOW_WATER;
        if (e < this.config.waterLevel + 0.05)
            return TerrainType.SAND;
        if (e > this.config.mountainLevel + 0.1)
            return TerrainType.VOLCANO;
        if (e > this.config.mountainLevel)
            return TerrainType.MOUNTAIN;
        if (e > this.config.mountainLevel - 0.15 && m < 0.3)
            return TerrainType.HILL;
        if (m > 0.6)
            return TerrainType.FOREST;
        return TerrainType.GRASS;
    }
    assignResources(res, terrain, moisture) {
        switch (terrain) {
            case TerrainType.DEEP_WATER:
            case TerrainType.SHALLOW_WATER:
                res.fish = Math.floor(moisture * 10);
                break;
            case TerrainType.FOREST:
                res.wood = Math.floor(5 + moisture * 8);
                break;
            case TerrainType.HILL:
            case TerrainType.MOUNTAIN:
                res.ore = Math.floor(3 + moisture * 5);
                break;
            case TerrainType.GRASS:
                res.fertility = Math.floor(4 + moisture * 6);
                break;
            default:
                break;
        }
    }
    get seed() {
        return this.config.seed;
    }
}
