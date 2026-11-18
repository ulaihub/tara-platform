-- Attente au point d'enlèvement : arrivée signalée par le livreur, frais pris à l'enlèvement.
ALTER TYPE "journal_entry_kind" ADD VALUE 'WAITING_FEE_CHARGED';

ALTER TABLE "orders"
  ADD COLUMN "arrived_pickup_at" TIMESTAMPTZ(3),
  ADD COLUMN "waiting_fee" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "orders" ADD CONSTRAINT orders_waiting_fee_positive CHECK (waiting_fee >= 0);
