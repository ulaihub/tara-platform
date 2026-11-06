-- Solde prépayé du livreur (G5, décision 36) : recharge par Mobile Money (frais payés par
-- Tara) et montants mis de côté pour les courses avec encaissement.
ALTER TYPE "payment_purpose" ADD VALUE 'RIDER_TOPUP';

CREATE TABLE "rider_balance_holds" (
    "id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "amount" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "released_at" TIMESTAMPTZ(3),

    CONSTRAINT "rider_balance_holds_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "rider_balance_holds_amount_check" CHECK ("amount" > 0)
);

CREATE INDEX "rider_balance_holds_rider_id_released_at_idx" ON "rider_balance_holds"("rider_id", "released_at");
CREATE INDEX "rider_balance_holds_order_id_idx" ON "rider_balance_holds"("order_id");
-- Une seule réservation active par course.
CREATE UNIQUE INDEX "rider_balance_holds_one_active_per_order"
  ON "rider_balance_holds"("order_id") WHERE "released_at" IS NULL;

ALTER TABLE "rider_balance_holds" ADD CONSTRAINT "rider_balance_holds_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "rider_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "rider_balance_holds" ADD CONSTRAINT "rider_balance_holds_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
