-- Phase 4 : compléments de l'API pour l'app livreur.

-- Motif d'échec « refus de payer » (E6).
ALTER TYPE "failure_reason" ADD VALUE 'PAYMENT_REFUSED' BEFORE 'OTHER';

-- Contact d'urgence facultatif du livreur, prévenu par SMS en cas d'alerte (E8).
ALTER TABLE "rider_profiles"
  ADD COLUMN "emergency_contact_name" TEXT,
  ADD COLUMN "emergency_contact_phone" TEXT;

-- Alerte annulée par le livreur : gardée, visible du dispatch.
ALTER TABLE "safety_alerts" ADD COLUMN "cancelled_at" TIMESTAMPTZ(3);

-- Temps passé en ligne (E9).
CREATE TABLE "rider_online_sessions" (
    "id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "started_at" TIMESTAMPTZ(3) NOT NULL,
    "last_seen_at" TIMESTAMPTZ(3) NOT NULL,
    "ended_at" TIMESTAMPTZ(3),

    CONSTRAINT "rider_online_sessions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "rider_online_sessions_rider_id_fkey" FOREIGN KEY ("rider_id")
      REFERENCES "rider_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "rider_online_sessions_order_check"
      CHECK ("last_seen_at" >= "started_at" AND ("ended_at" IS NULL OR "ended_at" >= "started_at"))
);

CREATE INDEX "rider_online_sessions_rider_id_started_at_idx"
  ON "rider_online_sessions"("rider_id", "started_at");

-- Une seule session ouverte par livreur.
CREATE UNIQUE INDEX "rider_online_sessions_one_open_idx"
  ON "rider_online_sessions"("rider_id") WHERE "ended_at" IS NULL;
