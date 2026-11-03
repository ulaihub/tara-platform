-- CreateEnum
CREATE TYPE "failure_decision" AS ENUM ('RETRY', 'RETURN');

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "delivery_code_failures" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "dispatch_alerted_at" TIMESTAMPTZ(3),
ADD COLUMN     "failure_decision" "failure_decision",
ADD COLUMN     "pickup_code_failures" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "searching_since" TIMESTAMPTZ(3);

-- CreateTable
CREATE TABLE "safety_alerts" (
    "id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "order_id" UUID,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acknowledged_at" TIMESTAMPTZ(3),
    "resolved_at" TIMESTAMPTZ(3),
    "handled_by_id" UUID,
    "resolution" TEXT,

    CONSTRAINT "safety_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "safety_alerts_resolved_at_created_at_idx" ON "safety_alerts"("resolved_at", "created_at");

-- CreateIndex
CREATE INDEX "safety_alerts_rider_id_created_at_idx" ON "safety_alerts"("rider_id", "created_at");

-- CreateIndex
CREATE INDEX "notifications_provider_provider_reference_idx" ON "notifications"("provider", "provider_reference");

-- AddForeignKey
ALTER TABLE "safety_alerts" ADD CONSTRAINT "safety_alerts_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "rider_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "safety_alerts" ADD CONSTRAINT "safety_alerts_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "safety_alerts" ADD CONSTRAINT "safety_alerts_handled_by_id_fkey" FOREIGN KEY ("handled_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Garde-fous en base (non décrits par Prisma).
ALTER TABLE "orders"
  ADD CONSTRAINT orders_code_failures_positive
    CHECK (pickup_code_failures >= 0 AND delivery_code_failures >= 0);

ALTER TABLE "safety_alerts"
  ADD CONSTRAINT safety_alerts_latitude_range CHECK (latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT safety_alerts_longitude_range CHECK (longitude BETWEEN -180 AND 180);

-- Un livreur n'a qu'une proposition de course en attente à la fois (un seul écran qui sonne).
CREATE UNIQUE INDEX dispatch_offers_one_pending_per_rider
  ON "dispatch_offers" ("rider_id") WHERE outcome = 'PENDING';
