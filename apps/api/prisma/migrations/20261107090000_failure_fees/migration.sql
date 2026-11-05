-- Frais d'échec figés à la commande (E6) : nouvelle tentative et retour à l'expéditeur.
ALTER TABLE "orders"
  ADD COLUMN "retry_fee" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "return_fee" INTEGER NOT NULL DEFAULT 0,
  ADD CONSTRAINT orders_failure_fees_positive CHECK (retry_fee >= 0 AND return_fee >= 0);

-- Écriture du grand livre : frais d'échec pris à l'expéditeur.
ALTER TYPE "journal_entry_kind" ADD VALUE 'FAILURE_FEE_CHARGED';
