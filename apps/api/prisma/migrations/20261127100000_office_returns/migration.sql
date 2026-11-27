-- Retour du colis sans dette : retour payé d'avance, sinon garde au bureau Tara.
-- AlterEnum
ALTER TYPE "failure_decision" ADD VALUE 'OFFICE';

-- AlterEnum

ALTER TYPE "journal_entry_kind" ADD VALUE 'OFFICE_RETURN_PAID';
ALTER TYPE "journal_entry_kind" ADD VALUE 'OFFICE_RETURN_WRITTEN_OFF';

-- AlterEnum

ALTER TYPE "order_status" ADD VALUE 'HELD_AT_OFFICE';
ALTER TYPE "order_status" ADD VALUE 'UNCLAIMED';

-- AlterEnum
ALTER TYPE "proof_kind" ADD VALUE 'OFFICE_DROP';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "office_at" TIMESTAMPTZ(3),
ADD COLUMN     "office_due" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "office_paid_at" TIMESTAMPTZ(3),
ADD COLUMN     "office_reminders" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "office_until" TIMESTAMPTZ(3),
ADD COLUMN     "return_paid_at" TIMESTAMPTZ(3),
ADD COLUMN     "unclaimed_at" TIMESTAMPTZ(3);

-- CreateIndex
CREATE INDEX "orders_status_office_until_idx" ON "orders"("status", "office_until");

