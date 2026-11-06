-- Livraison sans code : nom de la personne qui a reçu le colis, pour l'appel du support (E4).
ALTER TABLE "delivery_proofs" ADD COLUMN "received_by" TEXT;
