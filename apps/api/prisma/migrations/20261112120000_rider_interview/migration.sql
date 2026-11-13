-- Entretien au bureau (H3) : exigé réussi avant la validation d'un livreur.
ALTER TABLE "rider_profiles"
  ADD COLUMN "interview_at" TIMESTAMPTZ(3),
  ADD COLUMN "interview_by_id" UUID,
  ADD COLUMN "interview_passed" BOOLEAN,
  ADD COLUMN "interview_note" TEXT;

ALTER TABLE "rider_profiles"
  ADD CONSTRAINT "rider_profiles_interview_by_id_fkey" FOREIGN KEY ("interview_by_id")
  REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Un entretien enregistré a toujours sa date, son résultat et son auteur.
ALTER TABLE "rider_profiles"
  ADD CONSTRAINT "rider_profiles_interview_complete"
  CHECK ("interview_passed" IS NULL OR ("interview_at" IS NOT NULL AND "interview_note" IS NOT NULL));

-- Livreurs déjà validés avant cette règle : l'entretien est réputé fait à la validation.
UPDATE "rider_profiles"
  SET "interview_at" = "approved_at",
      "interview_by_id" = "approved_by_id",
      "interview_passed" = TRUE,
      "interview_note" = 'Validé avant l''enregistrement des entretiens.'
  WHERE "approved_at" IS NOT NULL;
