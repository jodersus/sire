// HexGrid.ts — Grid hexagonal con coordenadas axiales (q, r)
// Referencia: redblobgames.com/grids/hexagons

export interface AxialCoord {
  q: number;
  r: number;
}

/** Coordenadas cúbicas (q, r, s) donde q + r + s = 0 */
export interface CubeCoord {
  q: number;
  r: number;
  s: number;
}

/** Direcciones axiales de los 6 vecinos en orden: E, SE, SW, W, NW, NE */
export const AXIAL_DIRECTIONS: AxialCoord[] = [
  { q: 1, r: 0 },   // E
  { q: 1, r: -1 },  // SE
  { q: 0, r: -1 },  // SW
  { q: -1, r: 0 },  // W
  { q: -1, r: 1 },  // NW
  { q: 0, r: 1 },   // NE
];

export class HexGrid {
  readonly width: number;
  readonly height: number;

  constructor(width: number, height: number) {
    if (width <= 0 || height <= 0) {
      throw new Error("Grid dimensions must be positive");
    }
    this.width = width;
    this.height = height;
  }

  /** Convierte axial a cúbica (añade s = -q - r). */
  toCube(c: AxialCoord): CubeCoord {
    return { q: c.q, r: c.r, s: -c.q - c.r };
  }

  /** Convierte cúbica a axial. */
  toAxial(c: CubeCoord): AxialCoord {
    return { q: c.q, r: c.r };
  }

  /** Verifica si una coordenada está dentro de los límites del mapa. */
  isInBounds(c: AxialCoord): boolean {
    return c.q >= 0 && c.q < this.width && c.r >= 0 && c.r < this.height;
  }

  /** Devuelve los 6 vecinos de una coordenada axial. */
  neighbors(c: AxialCoord): AxialCoord[] {
    return AXIAL_DIRECTIONS.map((d) => ({
      q: c.q + d.q,
      r: c.r + d.r,
    }));
  }

  /** Vecinos filtrados por límites del mapa. */
  neighborsInBounds(c: AxialCoord): AxialCoord[] {
    return this.neighbors(c).filter((n) => this.isInBounds(n));
  }

  /** Distancia en hexágonos entre dos coordenadas axiales. */
  distance(a: AxialCoord, b: AxialCoord): number {
    const aq = a.q - b.q;
    const ar = a.r - b.r;
    const as = -aq - ar;
    return (Math.abs(aq) + Math.abs(ar) + Math.abs(as)) / 2;
  }

  /** Recorre en anillo alrededor de center con radio radius. */
  ring(center: AxialCoord, radius: number): AxialCoord[] {
    if (radius === 0) return [{ q: center.q, r: center.r }];
    let hex: AxialCoord = {
      q: center.q + AXIAL_DIRECTIONS[4].q * radius,
      r: center.r + AXIAL_DIRECTIONS[4].r * radius,
    };
    const result: AxialCoord[] = [];
    for (let i = 0; i < 6; i++) {
      for (let j = 0; j < radius; j++) {
        result.push({ q: hex.q, r: hex.r });
        hex = {
          q: hex.q + AXIAL_DIRECTIONS[i].q,
          r: hex.r + AXIAL_DIRECTIONS[i].r,
        };
      }
    }
    return result;
  }

  /** Recorre en espiral desde center hasta radius inclusive. */
  spiral(center: AxialCoord, radius: number): AxialCoord[] {
    const result: AxialCoord[] = [];
    for (let k = 0; k <= radius; k++) {
      result.push(...this.ring(center, k));
    }
    return result;
  }

  /** Convierte axial a índice lineal útil para arrays. */
  toIndex(c: AxialCoord): number {
    return c.r * this.width + c.q;
  }

  /** Convierte índice lineal a axial. */
  fromIndex(index: number): AxialCoord {
    return {
      q: index % this.width,
      r: Math.floor(index / this.width),
    };
  }

  /** Itera todas las coordenadas del grid en orden. */
  *allCoords(): Generator<AxialCoord> {
    for (let r = 0; r < this.height; r++) {
      for (let q = 0; q < this.width; q++) {
        yield { q, r };
      }
    }
  }

  totalCells(): number {
    return this.width * this.height;
  }
}
