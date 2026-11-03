-- CreateEnum
CREATE TYPE "media_kind" AS ENUM ('ADDRESS_PHOTO', 'VOICE_NOTE', 'KYC_DOCUMENT', 'PROOF_PHOTO');

-- AlterTable
ALTER TABLE "order_batches" ADD COLUMN     "idempotency_key" TEXT;

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "idempotency_key" TEXT,
ADD COLUMN     "recipient_available" BOOLEAN,
ADD COLUMN     "recipient_confirmed_at" TIMESTAMPTZ(3),
ADD COLUMN     "recipient_note" TEXT,
ALTER COLUMN "delivery_code_hash" DROP NOT NULL;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "referral_code" TEXT;

-- CreateTable
CREATE TABLE "media_files" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "kind" "media_kind" NOT NULL,
    "storage_key" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "size_bytes" INTEGER NOT NULL,
    "encrypted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_files_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "media_files_storage_key_key" ON "media_files"("storage_key");

-- CreateIndex
CREATE INDEX "media_files_owner_id_kind_idx" ON "media_files"("owner_id", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "order_batches_idempotency_key_key" ON "order_batches"("idempotency_key");

-- CreateIndex
CREATE UNIQUE INDEX "orders_idempotency_key_key" ON "orders"("idempotency_key");

-- CreateIndex
CREATE UNIQUE INDEX "users_referral_code_key" ON "users"("referral_code");

-- AddForeignKey
ALTER TABLE "media_files" ADD CONSTRAINT "media_files_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

