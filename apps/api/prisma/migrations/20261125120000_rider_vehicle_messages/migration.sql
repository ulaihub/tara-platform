-- Marque et couleur du véhicule du livreur ; messages entre l'expéditeur et le livreur.
ALTER TABLE "rider_profiles" ADD COLUMN     "vehicle_brand" TEXT,
ADD COLUMN     "vehicle_color" TEXT;
CREATE TABLE "order_messages" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "author_role" "actor_role" NOT NULL,
    "body" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "read_at" TIMESTAMPTZ(3),
    CONSTRAINT "order_messages_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "order_messages_order_id_created_at_idx" ON "order_messages"("order_id", "created_at");
ALTER TABLE "order_messages" ADD CONSTRAINT "order_messages_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "order_messages" ADD CONSTRAINT "order_messages_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
