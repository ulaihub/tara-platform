-- Garantie payante (déclaration de valeur) : 1 % de la valeur déclarée au-delà de 25 000 F,
-- comprise dans le total de la course, hors part du livreur.
ALTER TABLE "orders" ADD COLUMN "value_fee" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "orders"
  ADD CONSTRAINT orders_value_fee_positive CHECK (value_fee >= 0),
  DROP CONSTRAINT orders_total_consistent,
  ADD CONSTRAINT orders_total_consistent
    CHECK (total_price = base_price + surcharges_total - discount_total + value_fee);
