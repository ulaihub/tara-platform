-- Échec de livraison (E6) : heure et motif du dernier échec, pour le délai laissé à
-- l'expéditeur (retour automatique) et l'écran de retour de l'app livreur.
ALTER TABLE "orders"
  ADD COLUMN "failed_at" TIMESTAMPTZ(3),
  ADD COLUMN "failure_reason" "failure_reason";

-- Balayage des échecs sans décision.
CREATE INDEX "orders_failure_pending_idx" ON "orders" ("failed_at")
  WHERE "status" = 'DELIVERY_FAILED' AND "failure_decision" IS NULL;
