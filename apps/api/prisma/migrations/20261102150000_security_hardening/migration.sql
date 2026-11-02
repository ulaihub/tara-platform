-- AlterEnum
ALTER TYPE "otp_purpose" ADD VALUE 'ACCOUNT_DELETION';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "pii_masked_at" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "refresh_tokens" ADD COLUMN     "mfa_at" TIMESTAMPTZ(3);

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "totp_enabled_at" TIMESTAMPTZ(3),
ADD COLUMN     "totp_failed_attempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "totp_last_used_step" INTEGER,
ADD COLUMN     "totp_locked_until" TIMESTAMPTZ(3),
ADD COLUMN     "totp_secret_enc" TEXT;


-- Comptes supprimés : le numéro est remplacé par un identifiant non téléphonique,
-- ce qui libère le numéro et ne laisse aucune donnée personnelle (loi n° 2024/017).
ALTER TABLE "users" DROP CONSTRAINT users_phone_e164;
ALTER TABLE "users"
  ADD CONSTRAINT users_phone_e164
  CHECK (phone ~ '^\+[1-9][0-9]{7,14}$' OR (status = 'DELETED' AND phone ~ '^deleted:[0-9a-f-]{36}$'));

-- Index du travail quotidien de masquage des données des destinataires.
CREATE INDEX orders_pii_retention_idx ON "orders" (updated_at) WHERE pii_masked_at IS NULL;
