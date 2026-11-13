-- Gros objets : taille dédiée (tricycle ou camionnette), aide au chargement facturée,
-- colis refusé à l'enlèvement quand il ne correspond pas à la déclaration.
ALTER TYPE "package_size" ADD VALUE 'BULKY';
ALTER TYPE "surcharge_code" ADD VALUE 'HANDLING';
ALTER TYPE "proof_kind" ADD VALUE 'PICKUP_REFUSED';

ALTER TABLE "orders" ADD COLUMN "loading_help" BOOLEAN NOT NULL DEFAULT false;
