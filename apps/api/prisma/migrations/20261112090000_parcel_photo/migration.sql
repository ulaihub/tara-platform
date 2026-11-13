-- Photo du colis analysée automatiquement (taille, nature, objets interdits proposés).
ALTER TYPE "media_kind" ADD VALUE 'PARCEL_PHOTO';

ALTER TABLE "orders" ADD COLUMN "parcel_photo_key" TEXT,
ADD COLUMN "parcel_ai_warning" TEXT;

CREATE TABLE "parcel_analyses" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "photo_key" TEXT NOT NULL,
    "engine" TEXT NOT NULL,
    "result" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "parcel_analyses_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "parcel_analyses_photo_key_key" ON "parcel_analyses"("photo_key");
CREATE INDEX "parcel_analyses_owner_id_created_at_idx" ON "parcel_analyses"("owner_id", "created_at");

ALTER TABLE "parcel_analyses" ADD CONSTRAINT "parcel_analyses_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
