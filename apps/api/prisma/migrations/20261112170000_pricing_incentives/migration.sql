-- Modèle de prix validé (H4) : tarif pro des boutiques, prime d'approche et primes de renfort
-- des livreurs, payées par Tara.
ALTER TABLE "orders"
  ADD COLUMN "pro_discount_bps" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "approach_bonus" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "boost_bonus" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "dispatch_offers"
  ADD COLUMN "approach_bonus" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "boost_bonus" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "pricing_settings" (
    "city" TEXT NOT NULL,
    "volume_discounts" JSONB NOT NULL,
    "approach_bonus_amount" INTEGER NOT NULL,
    "approach_bonus_from_meters" INTEGER NOT NULL,
    "updated_by_id" UUID,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pricing_settings_pkey" PRIMARY KEY ("city"),
    CONSTRAINT "pricing_settings_amounts_check" CHECK (
      "approach_bonus_amount" >= 0 AND "approach_bonus_from_meters" >= 0
    )
);

CREATE TABLE "rider_boosts" (
    "id" UUID NOT NULL,
    "city" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cancelled_at" TIMESTAMPTZ(3),

    CONSTRAINT "rider_boosts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "rider_boosts_period_check" CHECK ("ends_at" > "starts_at" AND "amount" > 0)
);

CREATE INDEX "rider_boosts_city_ends_at_idx" ON "rider_boosts"("city", "ends_at");
