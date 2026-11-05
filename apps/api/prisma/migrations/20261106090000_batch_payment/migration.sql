-- Paiement Mobile Money d'un lot de livraisons (C4) : un seul paiement pour toutes les
-- commandes du lot, réparti ensuite sur chacune.
ALTER TABLE "payments" ADD COLUMN "batch_id" UUID;

-- CreateIndex
CREATE INDEX "payments_batch_id_idx" ON "payments"("batch_id");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_batch_id_fkey" FOREIGN KEY ("batch_id") REFERENCES "order_batches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Une seule demande en attente par lot (pas deux invites Mobile Money simultanées).
CREATE UNIQUE INDEX payments_one_pending_per_batch ON "payments" (batch_id, purpose)
  WHERE batch_id IS NOT NULL AND status = 'PENDING';
