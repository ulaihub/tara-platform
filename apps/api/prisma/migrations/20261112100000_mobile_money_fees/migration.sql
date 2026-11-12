-- Frais Mobile Money payés par le client à l'encaissement ; frais de retrait retenus sur les
-- reversements, sauf au-delà du seuil de retrait gratuit du bénéficiaire.
ALTER TABLE "payments" ADD COLUMN "surcharge" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "payouts" ADD COLUMN "charge" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "merchant_profiles" ADD COLUMN "free_payout_from" INTEGER;
ALTER TABLE "rider_profiles" ADD COLUMN "free_payout_from" INTEGER;
ALTER TABLE "payments" ADD CONSTRAINT "payments_surcharge_check" CHECK ("surcharge" >= 0);
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_charge_check" CHECK ("charge" >= 0 AND "charge" < "amount");
