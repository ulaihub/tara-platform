-- Espèces encaissées (G5) : dépôt sous 24 h, retard suivi, suspension faute de dépôt, et
-- plafond de départ de 25 000 FCFA pour les nouveaux livreurs (50 000 après 20 courses
-- sans retard). Les livreurs déjà inscrits gardent leur plafond.
ALTER TABLE "rider_profiles"
  ALTER COLUMN "cash_limit" SET DEFAULT 25000,
  ADD COLUMN "cash_overdue_since" TIMESTAMPTZ(3),
  ADD COLUMN "last_cash_late_at" TIMESTAMPTZ(3),
  ADD COLUMN "cash_suspended_at" TIMESTAMPTZ(3);
