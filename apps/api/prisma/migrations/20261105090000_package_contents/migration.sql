-- Nature du contenu d'un colis (C1) : catégorie et précision libre, montrées au livreur.
CREATE TYPE "package_contents" AS ENUM (
  'DOCUMENTS',
  'CLOTHING',
  'MEDICINE',
  'LAUNDRY',
  'HOUSEHOLD',
  'ELECTRONICS',
  'FOOD',
  'BEAUTY',
  'SECONDHAND',
  'OTHER'
);

ALTER TABLE "orders"
  ADD COLUMN "package_contents" "package_contents",
  ADD COLUMN "package_description" TEXT;
