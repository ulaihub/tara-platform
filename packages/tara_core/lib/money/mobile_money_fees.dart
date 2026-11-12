/// Frais Mobile Money payés par le client en plus du montant (même formule que le serveur) :
/// arrondi supérieur de montant × taux / (10 000 − taux), taux en points de base.
int mobileMoneyFee(int amount, int bps) {
  if (bps <= 0 || amount <= 0) return 0;
  return (amount * bps + (10000 - bps) - 1) ~/ (10000 - bps);
}

/// Frais retenus sur un retrait sous le seuil gratuit : arrondi supérieur de
/// montant × taux / (10 000 + taux).
int withdrawalFee(int amount, int bps, int freeFrom) {
  if (bps <= 0 || amount <= 0 || amount >= freeFrom) return 0;
  return (amount * bps + (10000 + bps) - 1) ~/ (10000 + bps);
}
