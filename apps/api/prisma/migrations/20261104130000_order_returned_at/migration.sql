-- Heure du retour du colis à l'expéditeur (historique des courses du livreur, E9).
ALTER TABLE "orders" ADD COLUMN "returned_at" TIMESTAMPTZ(3);

-- Commandes déjà rendues : heure de l'événement de retour.
UPDATE "orders" o
   SET "returned_at" = e."occurred_at"
  FROM (
    SELECT "order_id", MAX("occurred_at") AS "occurred_at"
      FROM "order_events"
     WHERE "to_status" = 'RETURNED'
     GROUP BY "order_id"
  ) e
 WHERE o."id" = e."order_id" AND o."status" = 'RETURNED';
