-- Code secret à 4 chiffres (comme Orange Money et MTN MoMo) et empreinte digitale par
-- téléphone. Code oublié : un code reçu par SMS ou WhatsApp permet d'en choisir un nouveau.
ALTER TYPE "otp_purpose" ADD VALUE 'PIN_RESET';

ALTER TABLE "users" ADD COLUMN     "pin_failed_attempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "pin_hash" TEXT,
ADD COLUMN     "pin_locked_at" TIMESTAMPTZ(3),
ADD COLUMN     "pin_set_at" TIMESTAMPTZ(3);

CREATE TABLE "pin_device_keys" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "installation_id" TEXT NOT NULL,
    "key_hash" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pin_device_keys_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "pin_device_keys_key_hash_key" ON "pin_device_keys"("key_hash");

CREATE UNIQUE INDEX "pin_device_keys_user_id_installation_id_key" ON "pin_device_keys"("user_id", "installation_id");

ALTER TABLE "pin_device_keys" ADD CONSTRAINT "pin_device_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
