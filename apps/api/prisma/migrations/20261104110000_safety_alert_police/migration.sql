-- Alerte SOS (E8) : précision et quartier de la position, alerte renvoyée sans doublon au
-- retour du réseau, et appel de la police par un agent Tara (heure, agent, ce qui a été dit).
ALTER TABLE "safety_alerts"
  ADD COLUMN "accuracy" DOUBLE PRECISION,
  ADD COLUMN "neighborhood" TEXT,
  ADD COLUMN "client_event_id" TEXT,
  ADD COLUMN "police_called_at" TIMESTAMPTZ(3),
  ADD COLUMN "police_called_by_id" UUID,
  ADD COLUMN "police_note" TEXT;

CREATE UNIQUE INDEX "safety_alerts_rider_id_client_event_id_key"
  ON "safety_alerts" ("rider_id", "client_event_id");

ALTER TABLE "safety_alerts"
  ADD CONSTRAINT "safety_alerts_police_called_by_id_fkey" FOREIGN KEY ("police_called_by_id")
  REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE;
