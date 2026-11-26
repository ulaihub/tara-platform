-- Repères de Douala ajoutés par l'équipe (carrefours, ronds-points, lieux connus).
CREATE TABLE "landmarks" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "city" TEXT NOT NULL DEFAULT 'Douala',
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "landmarks_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "landmarks_city_active_idx" ON "landmarks"("city", "active");
