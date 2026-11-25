-- Livreur muet pendant une course : course retirée avant l'enlèvement (compte dans sa fiabilité).
ALTER TYPE "course_alert_kind" ADD VALUE 'RIDER_SILENT';
