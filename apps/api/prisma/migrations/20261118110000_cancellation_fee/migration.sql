-- Annulation par l'expéditeur quand le livreur est déjà en route : déplacement payé.
ALTER TYPE "journal_entry_kind" ADD VALUE 'CANCELLATION_FEE_CHARGED';
