-- Solde Tara des boutiques : les recharges y arrivent et paient les livraisons avant les
-- ventes. Réserve choisie par la boutique, gardée chaque soir de ses ventes sur ce solde
-- au lieu d'être reversée (0 : tout est reversé, comme avant).
ALTER TYPE "journal_entry_kind" ADD VALUE 'RESERVE_KEPT';

ALTER TABLE "merchant_profiles" ADD COLUMN "payout_reserve" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "merchant_profiles" ADD CONSTRAINT "merchant_profiles_payout_reserve_check"
  CHECK ("payout_reserve" >= 0 AND "payout_reserve" <= 100000);
