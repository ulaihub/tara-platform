-- Tournée (2c) : plusieurs colis d'un même envoi proposés à un livreur, puis confiés ensemble.
ALTER TABLE "dispatch_offers" ADD COLUMN "bundle_order_ids" UUID[] NOT NULL DEFAULT '{}';
CREATE INDEX "dispatch_offers_bundle_pending_idx"
  ON "dispatch_offers" USING GIN ("bundle_order_ids") WHERE outcome = 'PENDING';

ALTER TABLE "orders"
  ADD COLUMN "tour_id" UUID,
  ADD COLUMN "stop_seq" INTEGER;
CREATE INDEX "orders_tour_id_idx" ON "orders"("tour_id");
