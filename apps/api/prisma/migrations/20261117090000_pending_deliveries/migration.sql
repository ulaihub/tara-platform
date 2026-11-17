-- Envoi en masse (C4, B3) : colis dont le client n'a pas encore placé son point. Tara lui
-- envoie un lien ; la commande est créée dans le même envoi, sous le numéro réservé, quand le
-- point arrive. Le code d'enlèvement de l'envoi est gardé chiffré pour ces colis tardifs.


-- AlterTable
ALTER TABLE "order_batches" ADD COLUMN     "pickup_code_sealed" TEXT;

-- CreateTable
CREATE TABLE "pending_deliveries" (
    "id" UUID NOT NULL,
    "batch_id" UUID NOT NULL,
    "batch_number" INTEGER NOT NULL,
    "sender_id" UUID NOT NULL,
    "location_link_id" UUID NOT NULL,
    "recipient_name" TEXT NOT NULL,
    "recipient_phone" TEXT NOT NULL,
    "item" JSONB NOT NULL,
    "order_id" UUID,
    "blocked_reason" TEXT,
    "cancelled_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pending_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pending_deliveries_location_link_id_key" ON "pending_deliveries"("location_link_id");

-- CreateIndex
CREATE UNIQUE INDEX "pending_deliveries_order_id_key" ON "pending_deliveries"("order_id");

-- CreateIndex
CREATE INDEX "pending_deliveries_sender_id_created_at_idx" ON "pending_deliveries"("sender_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "pending_deliveries_batch_id_batch_number_key" ON "pending_deliveries"("batch_id", "batch_number");

-- AddForeignKey
ALTER TABLE "pending_deliveries" ADD CONSTRAINT "pending_deliveries_batch_id_fkey" FOREIGN KEY ("batch_id") REFERENCES "order_batches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pending_deliveries" ADD CONSTRAINT "pending_deliveries_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pending_deliveries" ADD CONSTRAINT "pending_deliveries_location_link_id_fkey" FOREIGN KEY ("location_link_id") REFERENCES "location_links"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pending_deliveries" ADD CONSTRAINT "pending_deliveries_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

