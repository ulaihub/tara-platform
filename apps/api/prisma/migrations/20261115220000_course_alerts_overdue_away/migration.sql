-- Colis à bord : course bien plus longue que prévu, livreur qui s'éloigne de la destination.
ALTER TYPE "course_alert_kind" ADD VALUE 'OVERDUE';
ALTER TYPE "course_alert_kind" ADD VALUE 'MOVING_AWAY';
