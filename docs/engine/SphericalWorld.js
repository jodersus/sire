// SphericalWorld.ts — Wrap-around esférico para hex grid
// Si sales por un borde, apareces por el opuesto.
import { HexGrid } from "./HexGrid.js";
export class SphericalWorld extends HexGrid {
    /**
     * Normaliza una coordenada axial aplicando wrap-around.
     * - q se envuelve horizontalmente (columnas).
     * - r se envuelve verticalmente (filas).
     */
    wrap(c) {
        let q = c.q % this.width;
        let r = c.r % this.height;
        if (q < 0)
            q += this.width;
        if (r < 0)
            r += this.height;
        return { q, r };
    }
    /** Suma dirección a coordenada con wrap. */
    addWrapped(c, dq, dr) {
        return this.wrap({ q: c.q + dq, r: c.r + dr });
    }
    /** Vecinos con wrap-around: siempre 6 vecinos válidos. */
    neighborsWrapped(c) {
        const dirs = [
            { q: 1, r: 0 },
            { q: 1, r: -1 },
            { q: 0, r: -1 },
            { q: -1, r: 0 },
            { q: -1, r: 1 },
            { q: 0, r: 1 },
        ];
        return dirs.map((d) => this.wrap({ q: c.q + d.q, r: c.r + d.r }));
    }
    /**
     * Distancia mínima en un mundo esférico.
     * Considera wrap en ambos ejes, eligiendo el camino más corto.
     */
    distanceWrapped(a, b) {
        const direct = super.distance(a, b);
        // Wrap horizontal (q)
        const wrapQ = this.width / 2;
        const dqWrapped = Math.abs(a.q - b.q) > wrapQ
            ? this.width - Math.abs(a.q - b.q)
            : Math.abs(a.q - b.q);
        // Wrap vertical (r)
        const wrapR = this.height / 2;
        const drWrapped = Math.abs(a.r - b.r) > wrapR
            ? this.height - Math.abs(a.r - b.r)
            : Math.abs(a.r - b.r);
        // No podemos usar solo dq/dr crudos en fórmula de distancia hex;
        // evaluamos las 9 combinaciones de desplazamientos wrap posibles
        // y nos quedamos con la mínima distancia hex real.
        const offsets = [
            { dq: b.q - a.q, dr: b.r - a.r },
            { dq: b.q - a.q + this.width, dr: b.r - a.r },
            { dq: b.q - a.q - this.width, dr: b.r - a.r },
            { dq: b.q - a.q, dr: b.r - a.r + this.height },
            { dq: b.q - a.q, dr: b.r - a.r - this.height },
            { dq: b.q - a.q + this.width, dr: b.r - a.r + this.height },
            { dq: b.q - a.q + this.width, dr: b.r - a.r - this.height },
            { dq: b.q - a.q - this.width, dr: b.r - a.r + this.height },
            { dq: b.q - a.q - this.width, dr: b.r - a.r - this.height },
        ];
        let min = direct;
        for (const o of offsets) {
            const ds = -o.dq - o.dr; // s = -q - r => ds = -dq - dr
            const d = (Math.abs(o.dq) + Math.abs(o.dr) + Math.abs(ds)) / 2;
            if (d < min)
                min = d;
        }
        return min;
    }
    /** Verifica si dos coordenadas son la misma tile tras wrap. */
    same(c1, c2) {
        const w1 = this.wrap(c1);
        const w2 = this.wrap(c2);
        return w1.q === w2.q && w1.r === w2.r;
    }
    /** Todas las coordenadas del mapa en un array. */
    allCoordsArray() {
        const out = [];
        for (let r = 0; r < this.height; r++) {
            for (let q = 0; q < this.width; q++) {
                out.push({ q, r });
            }
        }
        return out;
    }
}
