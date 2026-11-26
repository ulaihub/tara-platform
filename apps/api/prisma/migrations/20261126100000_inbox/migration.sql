-- Boîte de réception des notifications de l'app (cloche).
CREATE TABLE "inbox_items" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "template" TEXT NOT NULL,
    "params" JSONB NOT NULL,
    "order_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "read_at" TIMESTAMPTZ(3),
    CONSTRAINT "inbox_items_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "inbox_items_user_id_created_at_idx" ON "inbox_items"("user_id", "created_at");
ALTER TABLE "inbox_items" ADD CONSTRAINT "inbox_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
