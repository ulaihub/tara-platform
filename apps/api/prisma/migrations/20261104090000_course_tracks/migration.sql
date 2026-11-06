-- Trajet des courses (sécurité, litiges, fraude) : points de l'acceptation à la fin de la
-- course, résumé à la fin, alertes au support. Conservation : 90 jours pour les points
-- détaillés (sauf litige ou incident ouvert), le résumé reste avec la commande.
-- CreateEnum
CREATE TYPE "course_alert_kind" AS ENUM ('ACTION_FAR', 'LONG_STOP', 'MOCK_LOCATION', 'TRACK_GAP');

-- CreateTable
CREATE TABLE "course_track_points" (
    "id" BIGSERIAL NOT NULL,
    "order_id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "recorded_at" TIMESTAMPTZ(3) NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "speed" DOUBLE PRECISION,
    "mocked" BOOLEAN NOT NULL DEFAULT false,
    "late" BOOLEAN NOT NULL DEFAULT false,
    "received_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "course_track_points_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "course_tracks" (
    "order_id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "point_count" INTEGER NOT NULL,
    "distance_meters" INTEGER NOT NULL,
    "started_at" TIMESTAMPTZ(3),
    "ended_at" TIMESTAMPTZ(3),
    "longest_gap_seconds" INTEGER NOT NULL,
    "longest_stop_seconds" INTEGER NOT NULL,
    "mocked_points" INTEGER NOT NULL,
    "computed_at" TIMESTAMPTZ(3) NOT NULL,
    "points_purged_at" TIMESTAMPTZ(3),

    CONSTRAINT "course_tracks_pkey" PRIMARY KEY ("order_id","rider_id")
);

-- CreateTable
CREATE TABLE "course_alerts" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "kind" "course_alert_kind" NOT NULL,
    "dedupe_key" TEXT NOT NULL,
    "details" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acknowledged_at" TIMESTAMPTZ(3),
    "acknowledged_by_id" UUID,
    "note" TEXT,

    CONSTRAINT "course_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "course_track_points_recorded_at_idx" ON "course_track_points"("recorded_at");

-- CreateIndex
CREATE UNIQUE INDEX "course_track_points_order_id_rider_id_recorded_at_key" ON "course_track_points"("order_id", "rider_id", "recorded_at");

-- CreateIndex
CREATE INDEX "course_alerts_acknowledged_at_created_at_idx" ON "course_alerts"("acknowledged_at", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "course_alerts_order_id_dedupe_key_key" ON "course_alerts"("order_id", "dedupe_key");

-- AddForeignKey
ALTER TABLE "course_track_points" ADD CONSTRAINT "course_track_points_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_track_points" ADD CONSTRAINT "course_track_points_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "rider_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_tracks" ADD CONSTRAINT "course_tracks_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_tracks" ADD CONSTRAINT "course_tracks_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "rider_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_alerts" ADD CONSTRAINT "course_alerts_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_alerts" ADD CONSTRAINT "course_alerts_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "rider_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_alerts" ADD CONSTRAINT "course_alerts_acknowledged_by_id_fkey" FOREIGN KEY ("acknowledged_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Coordonnées plausibles uniquement.
ALTER TABLE "course_track_points" ADD CONSTRAINT "course_track_points_coordinates_check"
  CHECK ("latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180);

-- Points jamais modifiés par l'API : seulement ajoutés, puis effacés à la fin de la
-- conservation (preuve de trajet fiable en cas de litige).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tara_app') THEN
    REVOKE UPDATE, TRUNCATE ON "course_track_points" FROM tara_app;
  END IF;
END
$$;
