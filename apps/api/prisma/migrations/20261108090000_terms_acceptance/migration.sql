-- Acceptation des conditions « signée » : code SMS dédié et preuve sur le consentement.
ALTER TYPE "otp_purpose" ADD VALUE 'TERMS';

ALTER TABLE "consents"
  ADD COLUMN "ip" TEXT,
  ADD COLUMN "user_agent" TEXT,
  ADD COLUMN "installation_id" TEXT;
