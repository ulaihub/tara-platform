-- Service client (H6) : numéro lisible, personne concernée et numéro à rappeler.
CREATE SEQUENCE "tickets_number_seq" START WITH 1001;
ALTER TABLE "tickets"
  ADD COLUMN "number" INTEGER NOT NULL DEFAULT nextval('tickets_number_seq'),
  ADD COLUMN "requester_id" UUID,
  ADD COLUMN "contact_phone" TEXT;
ALTER SEQUENCE "tickets_number_seq" OWNED BY "tickets"."number";

-- Demandes déjà ouvertes : la personne concernée est celle qui les a ouvertes.
UPDATE "tickets" t SET "requester_id" = t."opened_by_id", "contact_phone" = u."phone"
  FROM "users" u WHERE u."id" = t."opened_by_id";
ALTER TABLE "tickets" ALTER COLUMN "contact_phone" SET NOT NULL;

CREATE UNIQUE INDEX "tickets_number_key" ON "tickets"("number");
CREATE INDEX "tickets_requester_id_created_at_idx" ON "tickets"("requester_id", "created_at");
CREATE INDEX "tickets_assignee_id_status_idx" ON "tickets"("assignee_id", "status");
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_requester_id_fkey" FOREIGN KEY ("requester_id")
  REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- Un sujet et des messages non vides.
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_subject_not_blank" CHECK (length(btrim("subject")) > 0);
ALTER TABLE "ticket_messages" ADD CONSTRAINT "ticket_messages_body_not_blank" CHECK (length(btrim("body")) > 0);
