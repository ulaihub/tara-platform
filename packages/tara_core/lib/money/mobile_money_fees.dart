/// Frais Mobile Money payés par le client en plus du montant (même formule que le serveur) :
/// arrondi supérieur de montant × taux / (10 000 − taux), taux en points de base.
int mobileMoneyFee(int amount, int bps) {
  if (bps <= 0 || amount <= 0) return 0;
  return (amount * bps + (10000 - bps) - 1) ~/ (10000 - bps);
}

/// Frais retenus sur un retrait sous le seuil gratuit (même formule que le serveur) : frais
/// Mobile Money, arrondi supérieur de montant × taux / (10 000 + taux), dont le bénéficiaire
/// paie [sharePercent] % (arrondi inférieur) ; Tara paie le reste.
int withdrawalFee(int amount, int bps, int freeFrom, {int sharePercent = 100}) {
  if (bps <= 0 || amount <= 0 || amount >= freeFrom) return 0;
  final fee = (amount * bps + (10000 + bps) - 1) ~/ (10000 + bps);
  return fee * sharePercent.clamp(0, 100) ~/ 100;
}
