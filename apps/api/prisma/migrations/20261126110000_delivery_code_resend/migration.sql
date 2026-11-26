-- Renvoi du code de livraison depuis la page de suivi du destinataire (3 fois au plus).
ALTER TABLE "orders" ADD COLUMN "delivery_code_resends" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "orders" ADD COLUMN "delivery_code_sent_at" TIMESTAMPTZ(3);
