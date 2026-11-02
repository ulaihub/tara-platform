-- CreateEnum
CREATE TYPE "reconciliation_status" AS ENUM ('BALANCED', 'DISCREPANCIES');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "journal_entry_kind" ADD VALUE 'ORDER_CHARGED';
ALTER TYPE "journal_entry_kind" ADD VALUE 'ORDER_RELEASED';
ALTER TYPE "journal_entry_kind" ADD VALUE 'PAYOUT_REQUESTED';
ALTER TYPE "journal_entry_kind" ADD VALUE 'CASH_COMPENSATED';
ALTER TYPE "journal_entry_kind" ADD VALUE 'CREDIT_GRANTED';

-- AlterEnum
ALTER TYPE "payout_beneficiary" ADD VALUE 'CUSTOMER';

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "payout_status" ADD VALUE 'AWAITING_APPROVAL';
ALTER TYPE "payout_status" ADD VALUE 'CANCELLED';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "fee_paid_at" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "fee" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "last_checked_at" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "payouts" ADD COLUMN     "approved_at" TIMESTAMPTZ(3),
ADD COLUMN     "approved_by_id" UUID,
ADD COLUMN     "last_checked_at" TIMESTAMPTZ(3),
ADD COLUMN     "user_id" UUID;

-- CreateTable
CREATE TABLE "reconciliation_reports" (
    "id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "status" "reconciliation_status" NOT NULL,
    "totals" JSONB NOT NULL,
    "discrepancies" JSONB NOT NULL,
    "ran_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "reconciliation_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "reconciliation_reports_day_key" ON "reconciliation_reports"("day");

-- AddForeignKey
ALTER TABLE "reconciliation_reports" ADD CONSTRAINT "reconciliation_reports_ran_by_id_fkey" FOREIGN KEY ("ran_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_approved_by_id_fkey" FOREIGN KEY ("approved_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

