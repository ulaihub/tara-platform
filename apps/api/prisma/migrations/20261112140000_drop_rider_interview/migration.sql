-- Entretien au bureau abandonné (choix du fondateur) : la validation d'un livreur repose sur
-- ses pièces. Les entretiens déjà enregistrés restent au journal d'audit.
ALTER TABLE "rider_profiles" DROP CONSTRAINT "rider_profiles_interview_complete";
ALTER TABLE "rider_profiles" DROP CONSTRAINT "rider_profiles_interview_by_id_fkey";
ALTER TABLE "rider_profiles"
  DROP COLUMN "interview_at",
  DROP COLUMN "interview_by_id",
  DROP COLUMN "interview_passed",
  DROP COLUMN "interview_note";
