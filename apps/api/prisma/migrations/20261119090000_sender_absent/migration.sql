-- Expéditeur absent après l'attente maximale : preuve du livreur, avertissement à 25 min.
ALTER TYPE "proof_kind" ADD VALUE 'SENDER_ABSENT';

ALTER TABLE "orders" ADD COLUMN "waiting_warned_at" TIMESTAMPTZ(3);
