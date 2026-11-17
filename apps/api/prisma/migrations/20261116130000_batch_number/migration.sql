-- Numéro du colis dans son envoi groupé (1, 2, 3… dans l'ordre de saisie), écrit sur le
-- colis par l'expéditeur et lu par le livreur à l'enlèvement.
ALTER TABLE "orders" ADD COLUMN "batch_number" INTEGER;

-- Envois déjà passés : numérotés dans l'ordre de création.
UPDATE "orders" AS o
SET "batch_number" = n.rang
FROM (
  SELECT "id", ROW_NUMBER() OVER (PARTITION BY "batch_id" ORDER BY "created_at", "id") AS rang
  FROM "orders"
  WHERE "batch_id" IS NOT NULL
) AS n
WHERE o."id" = n."id";

CREATE UNIQUE INDEX "orders_batch_id_batch_number_key" ON "orders"("batch_id", "batch_number");
