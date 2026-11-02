-- Garde-fous financiers de la phase 3 (non décrits par Prisma). Migration séparée : les
-- valeurs ajoutées aux types énumérés ne sont utilisables qu'après validation de la
-- migration qui les crée.

-- Bénéficiaire d'un reversement : exactement un, cohérent avec son type.
ALTER TABLE "payouts" DROP CONSTRAINT payouts_beneficiary_consistent;
ALTER TABLE "payouts" ADD CONSTRAINT payouts_beneficiary_consistent CHECK (
  (beneficiary = 'MERCHANT' AND merchant_id IS NOT NULL AND rider_id IS NULL AND user_id IS NULL)
  OR (beneficiary = 'RIDER' AND rider_id IS NOT NULL AND merchant_id IS NULL AND user_id IS NULL)
  OR (beneficiary = 'CUSTOMER' AND user_id IS NOT NULL AND merchant_id IS NULL AND rider_id IS NULL)
);

-- Un seul reversement en cours par bénéficiaire : deux demandes simultanées (double clic,
-- tâche relancée) ne peuvent pas vider deux fois le même portefeuille.
CREATE UNIQUE INDEX payouts_one_open_per_merchant ON "payouts" (merchant_id)
  WHERE merchant_id IS NOT NULL AND status IN ('PENDING', 'AWAITING_APPROVAL', 'PROCESSING');
CREATE UNIQUE INDEX payouts_one_open_per_rider ON "payouts" (rider_id)
  WHERE rider_id IS NOT NULL AND status IN ('PENDING', 'AWAITING_APPROVAL', 'PROCESSING');
CREATE UNIQUE INDEX payouts_one_open_per_customer ON "payouts" (user_id)
  WHERE user_id IS NOT NULL AND status IN ('PENDING', 'AWAITING_APPROVAL', 'PROCESSING');

-- Une seule demande de paiement en attente par commande et par objet (pas deux invites
-- Mobile Money simultanées sur le téléphone du client).
CREATE UNIQUE INDEX payments_one_pending_per_order ON "payments" (order_id, purpose)
  WHERE order_id IS NOT NULL AND status = 'PENDING';

ALTER TABLE "payments" ADD CONSTRAINT payments_fee_valid CHECK (fee >= 0 AND fee <= amount);
