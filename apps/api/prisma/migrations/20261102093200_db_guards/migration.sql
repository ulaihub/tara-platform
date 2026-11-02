-- =============================================================================
-- Protections en base, non exprimables dans le schéma Prisma.
-- Prisma n'introspecte ni les triggers ni les contraintes CHECK : ces objets ne
-- créent pas d'écart de schéma (drift) et restent en place au fil des migrations.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Position PostGIS des adresses, calculée à partir de latitude/longitude
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tara_addresses_set_location() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  RETURN NEW;
END;
$$;

CREATE TRIGGER addresses_set_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON "addresses"
  FOR EACH ROW EXECUTE FUNCTION tara_addresses_set_location();

-- -----------------------------------------------------------------------------
-- 2. Contraintes de cohérence
-- -----------------------------------------------------------------------------
ALTER TABLE "users"
  ADD CONSTRAINT users_phone_e164 CHECK (phone ~ '^\+[1-9][0-9]{7,14}$');

ALTER TABLE "addresses"
  ADD CONSTRAINT addresses_latitude_range CHECK (latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT addresses_longitude_range CHECK (longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT addresses_landmark_required CHECK (char_length(btrim(landmark)) > 0);

ALTER TABLE "rider_profiles"
  ADD CONSTRAINT rider_profiles_amounts_positive
    CHECK (cash_limit >= 0 AND deposit_required >= 0 AND rating_sum >= 0 AND rating_count >= 0);

ALTER TABLE "pricing_grids"
  ADD CONSTRAINT pricing_grids_rider_share_range CHECK (rider_share_bps BETWEEN 0 AND 10000),
  ADD CONSTRAINT pricing_grids_per_km_positive CHECK (per_km_beyond_last_tier >= 0);

ALTER TABLE "pricing_tiers"
  ADD CONSTRAINT pricing_tiers_values_positive CHECK (up_to_meters > 0 AND price >= 0);

-- Un supplément est soit un montant fixe, soit un pourcentage, jamais les deux.
ALTER TABLE "pricing_surcharges"
  ADD CONSTRAINT pricing_surcharges_one_value CHECK ((amount IS NULL) <> (percent_bps IS NULL)),
  ADD CONSTRAINT pricing_surcharges_values_positive
    CHECK (COALESCE(amount, 0) >= 0 AND COALESCE(percent_bps, 0) >= 0);

ALTER TABLE "promo_codes"
  ADD CONSTRAINT promo_codes_value_positive CHECK (value > 0),
  ADD CONSTRAINT promo_codes_percent_range CHECK (kind <> 'PERCENT' OR value <= 10000),
  ADD CONSTRAINT promo_codes_limits_positive
    CHECK (per_user_limit > 0 AND COALESCE(max_redemptions, 1) > 0);

ALTER TABLE "promo_redemptions"
  ADD CONSTRAINT promo_redemptions_discount_positive CHECK (discount >= 0);

-- Prix figé : total = base + suppléments − remises ; part livreur + part Tara = total.
-- La part Tara peut être négative lors d'une promotion financée par Tara.
ALTER TABLE "orders"
  ADD CONSTRAINT orders_amounts_positive CHECK (
    distance_meters >= 0 AND base_price >= 0 AND surcharges_total >= 0
    AND discount_total >= 0 AND total_price >= 0 AND rider_earning >= 0
    AND cod_amount >= 0 AND COALESCE(declared_value, 0) >= 0 AND attempt_count >= 0
  ),
  ADD CONSTRAINT orders_total_consistent
    CHECK (total_price = base_price + surcharges_total - discount_total),
  ADD CONSTRAINT orders_split_consistent CHECK (rider_earning + platform_fee = total_price);

ALTER TABLE "ratings"
  ADD CONSTRAINT ratings_score_range CHECK (score BETWEEN 1 AND 5);

ALTER TABLE "payments"
  ADD CONSTRAINT payments_amount_positive CHECK (amount > 0);

ALTER TABLE "cod_collections"
  ADD CONSTRAINT cod_collections_amounts_positive
    CHECK (expected_amount >= 0 AND collected_amount >= 0 AND fee_amount >= 0);

ALTER TABLE "payouts"
  ADD CONSTRAINT payouts_amounts_positive CHECK (amount > 0 AND fee >= 0),
  ADD CONSTRAINT payouts_beneficiary_consistent CHECK (
    (beneficiary = 'MERCHANT' AND merchant_id IS NOT NULL AND rider_id IS NULL)
    OR (beneficiary = 'RIDER' AND rider_id IS NOT NULL AND merchant_id IS NULL)
  );

ALTER TABLE "ledger_postings"
  ADD CONSTRAINT ledger_postings_amount_not_zero CHECK (amount <> 0);

-- -----------------------------------------------------------------------------
-- 3. Grand livre : chaque écriture compte au moins deux lignes dont la somme est nulle.
--    Contrôle différé à la fin de la transaction, pour permettre d'insérer
--    l'écriture puis ses lignes dans la même transaction.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tara_ledger_check_entry_balanced() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_entry_id uuid;
  v_sum bigint;
  v_count integer;
BEGIN
  IF TG_TABLE_NAME = 'journal_entries' THEN
    v_entry_id := NEW.id;
  ELSE
    v_entry_id := NEW.entry_id;
  END IF;

  SELECT COALESCE(SUM(amount), 0), COUNT(*)
    INTO v_sum, v_count
    FROM ledger_postings
   WHERE entry_id = v_entry_id;

  IF v_count < 2 THEN
    RAISE EXCEPTION 'Écriture % : au moins deux lignes sont requises (% trouvée)', v_entry_id, v_count
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_sum <> 0 THEN
    RAISE EXCEPTION 'Écriture % déséquilibrée : la somme des lignes vaut % FCFA', v_entry_id, v_sum
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER journal_entries_balanced
  AFTER INSERT ON "journal_entries"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION tara_ledger_check_entry_balanced();

CREATE CONSTRAINT TRIGGER ledger_postings_balanced
  AFTER INSERT ON "ledger_postings"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION tara_ledger_check_entry_balanced();

-- -----------------------------------------------------------------------------
-- 4. Tables en ajout seul : aucune modification ni suppression.
--    Une erreur comptable se corrige par une écriture inverse.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tara_forbid_update_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'La table % est en ajout seul : % interdit', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE TRIGGER journal_entries_append_only
  BEFORE UPDATE OR DELETE ON "journal_entries"
  FOR EACH ROW EXECUTE FUNCTION tara_forbid_update_delete();
CREATE TRIGGER journal_entries_no_truncate
  BEFORE TRUNCATE ON "journal_entries"
  FOR EACH STATEMENT EXECUTE FUNCTION tara_forbid_update_delete();

CREATE TRIGGER ledger_postings_append_only
  BEFORE UPDATE OR DELETE ON "ledger_postings"
  FOR EACH ROW EXECUTE FUNCTION tara_forbid_update_delete();
CREATE TRIGGER ledger_postings_no_truncate
  BEFORE TRUNCATE ON "ledger_postings"
  FOR EACH STATEMENT EXECUTE FUNCTION tara_forbid_update_delete();

CREATE TRIGGER order_events_append_only
  BEFORE UPDATE OR DELETE ON "order_events"
  FOR EACH ROW EXECUTE FUNCTION tara_forbid_update_delete();
CREATE TRIGGER order_events_no_truncate
  BEFORE TRUNCATE ON "order_events"
  FOR EACH STATEMENT EXECUTE FUNCTION tara_forbid_update_delete();

CREATE TRIGGER audit_logs_append_only
  BEFORE UPDATE OR DELETE ON "audit_logs"
  FOR EACH ROW EXECUTE FUNCTION tara_forbid_update_delete();
CREATE TRIGGER audit_logs_no_truncate
  BEFORE TRUNCATE ON "audit_logs"
  FOR EACH STATEMENT EXECUTE FUNCTION tara_forbid_update_delete();
