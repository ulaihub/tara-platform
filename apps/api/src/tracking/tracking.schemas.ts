import { z } from 'zod';
import { Latitude, Longitude } from '../geo/geo.schemas.js';

/** Position gardée sur le téléphone faute de réseau, envoyée plus tard. */
export const TrackPointBody = z.object({
  latitude: Latitude,
  longitude: Longitude,
  accuracy: z.number().min(0).max(10_000).optional(),
  speed: z.number().min(0).max(100).optional(),
  /** Heure de la mesure sur le téléphone. */
  recordedAt: z.iso.datetime(),
  mocked: z.boolean().optional(),
});

/** Au plus deux heures de positions (une toutes les 10 s) par envoi. */
export const TrackBatchBody = z.object({ points: z.array(TrackPointBody).min(1).max(720) });

export const TrackBatchDto = z
  .object({
    accepted: z.int(),
    /** Points hors de la course (avant l'acceptation, après la fin) : ignorés. */
    ignored: z.int(),
  })
  .meta({ id: 'TrackBatchResult' });

export const CourseAlertKindEnum = z
  .enum([
    'ACTION_FAR',
    'LONG_STOP',
    'MOCK_LOCATION',
    'TRACK_GAP',
    'APPROACH_BONUS',
    'OVERDUE',
    'MOVING_AWAY',
    'RIDER_SILENT',
  ])
  .meta({ id: 'CourseAlertKind' });

export const CourseAlertDto = z
  .object({
    id: z.uuid(),
    orderId: z.uuid(),
    reference: z.string(),
    riderId: z.uuid(),
    kind: CourseAlertKindEnum,
    details: z.record(z.string(), z.unknown()),
    createdAt: z.iso.datetime(),
    acknowledgedAt: z.iso.datetime().nullable(),
    note: z.string().nullable(),
  })
  .meta({ id: 'CourseAlert' });

export const CourseAlertListQuery = z.object({ status: z.enum(['open', 'all']).default('open') });
export const AcknowledgeCourseAlertBody = z.object({ note: z.string().trim().max(300).optional() });

const TrackSummaryDto = z.object({
  riderId: z.uuid(),
  pointCount: z.int(),
  distanceMeters: z.int(),
  startedAt: z.iso.datetime().nullable(),
  endedAt: z.iso.datetime().nullable(),
  longestGapSeconds: z.int(),
  longestStopSeconds: z.int(),
  mockedPoints: z.int(),
  /** Points détaillés effacés (fin de la conservation de 90 jours). */
  pointsPurgedAt: z.iso.datetime().nullable(),
});

/** Trajet d'une course pour l'équipe (litige, incident, alerte) : consultation tracée. */
export const CourseTrackDto = z
  .object({
    orderId: z.uuid(),
    reference: z.string(),
    status: z.string(),
    summaries: z.array(TrackSummaryDto),
    points: z.array(
      z.object({
        riderId: z.uuid(),
        at: z.iso.datetime(),
        latitude: z.number(),
        longitude: z.number(),
        accuracy: z.number().nullable(),
        speed: z.number().nullable(),
        mocked: z.boolean(),
        late: z.boolean(),
      }),
    ),
    alerts: z.array(CourseAlertDto),
  })
  .meta({ id: 'CourseTrack' });
