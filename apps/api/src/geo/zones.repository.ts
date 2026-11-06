import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import { AppError } from '../common/errors/app-error.js';
import { uuidv7 } from '../common/crypto.js';
import type { ZoneKind } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { ZoneBody } from './geo.schemas.js';

export interface ZoneRow {
  id: string;
  name: string;
  city: string;
  kind: ZoneKind;
  active: boolean;
}

/**
 * Requêtes spatiales sur les zones (B6). Seul endroit où les polygones sont lus ou écrits :
 * Prisma ne sait pas manipuler les colonnes PostGIS.
 */
@Injectable()
export class ZonesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(body: z.output<typeof ZoneBody>): Promise<ZoneRow> {
    const geojson = JSON.stringify(body.geometry);
    let check: { valid: boolean; reason: string }[];
    try {
      check = await this.prisma.$queryRaw<{ valid: boolean; reason: string }[]>`
        SELECT ST_IsValid(g) AS valid, ST_IsValidReason(g) AS reason
          FROM (SELECT ST_SetSRID(ST_GeomFromGeoJSON(${geojson}), 4326) AS g) AS input`;
    } catch {
      throw AppError.unprocessable('ZONE_GEOMETRY_INVALID');
    }
    if (!check[0]?.valid) {
      throw AppError.unprocessable('ZONE_GEOMETRY_INVALID', {}, { reason: check[0]?.reason });
    }

    const id = uuidv7();
    await this.prisma.$executeRaw`
      INSERT INTO zones (id, name, city, kind, area, updated_at)
      VALUES (
        ${id}::uuid, ${body.name}, ${body.city}, CAST(${body.kind} AS zone_kind),
        ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(${geojson}), 4326))::geography, now()
      )`;
    return { id, name: body.name, city: body.city, kind: body.kind, active: true };
  }

  /** Zones actives d'un type contenant un point, de la plus petite à la plus grande. */
  findContaining(latitude: number, longitude: number, kind: ZoneKind): Promise<ZoneRow[]> {
    return this.prisma.$queryRaw<ZoneRow[]>`
      SELECT id, name, city, kind, active
        FROM zones
       WHERE active
         AND kind = CAST(${kind} AS zone_kind)
         AND ST_Covers(area, ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography)
       ORDER BY ST_Area(area) ASC`;
  }

  /**
   * Contours des zones actives d'une ville, simplifiés à environ 5 m et arrondis à 6
   * décimales : assez précis pour la carte, assez légers pour un réseau mobile.
   */
  async mapFeatures(
    city: string | undefined,
  ): Promise<{ id: string; name: string; kind: ZoneKind; geometry: string; updatedAt: Date }[]> {
    return this.prisma.$queryRaw`
      SELECT id, name, kind, updated_at AS "updatedAt",
             ST_AsGeoJSON(ST_SimplifyPreserveTopology(area::geometry, 0.00005), 6) AS geometry
        FROM zones
       WHERE active
         AND kind IN ('NO_MOTORBIKE', 'SERVICE_AREA')
         AND (${city ?? null}::text IS NULL OR city = ${city ?? null})
       ORDER BY kind, name`;
  }

  /** Identifiants des adresses situées dans une zone interdite aux motos. */
  async restrictedAddressIds(addressIds: string[]): Promise<Set<string>> {
    if (addressIds.length === 0) return new Set();
    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT a.id
        FROM addresses a
       WHERE a.id = ANY(${addressIds}::uuid[])
         AND EXISTS (
           SELECT 1 FROM zones z
            WHERE z.active AND z.kind = 'NO_MOTORBIKE' AND ST_Covers(z.area, a.location)
         )`;
    return new Set(rows.map((row) => row.id));
  }
}
