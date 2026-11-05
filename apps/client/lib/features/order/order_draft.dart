import 'package:flutter/foundation.dart';

import '../../core/api/client_models.dart';

/// Natures de contenu proposées (C1), dans l'ordre d'affichage ; « OTHER » en dernier.
const packageContentsCodes = [
  'DOCUMENTS',
  'CLOTHING',
  'MEDICINE',
  'LAUNDRY',
  'HOUSEHOLD',
  'ELECTRONICS',
  'FOOD',
  'BEAUTY',
  'SECONDHAND',
  'OTHER',
];

/// Une livraison de la commande (C1) : destinataire, adresse, colis.
class DeliveryDraft {
  String recipientName = '';

  /// Chiffres nationaux (9) du destinataire.
  String recipientPhone = '';
  Address? dropoff;

  /// Adresse demandée au destinataire (B3) : remplie dès qu'il a placé son point.
  LocationLink? link;

  String? contents;
  String description = '';
  String size = 'S';
  bool fragile = false;

  /// Taille et fragilité choisies par l'expéditeur : la nature du contenu ne les suggère
  /// plus ensuite.
  bool sizeChosen = false;
  bool fragileChosen = false;
  int? declaredValue;
  int codAmount = 0;
  String instructions = '';

  bool get hasRecipient => recipientName.trim().length >= 2 && RegExp(r'^6\d{8}$').hasMatch(recipientPhone);

  /// Adresse connue, ou demandée par lien (la commande attend alors qu'elle arrive).
  bool get hasAddress => dropoff != null || link != null;

  /// Montant à encaisser au plus par livraison (G5) ; valeur déclarée au plus.
  static const maxCod = 500000;
  static const maxDeclaredValue = 10000000;

  /// Nature choisie, précisée si « Autre », montants dans les plafonds.
  bool get hasPackage =>
      contents != null &&
      (contents != 'OTHER' || description.trim().length >= 2) &&
      codAmount <= maxCod &&
      (declaredValue ?? 0) <= maxDeclaredValue;
}

/// Brouillon de la nouvelle livraison, rempli étape par étape (enlèvement, destinataire,
/// colis, quand, récapitulatif). Jusqu'à 10 livraisons depuis le même point (C4).
class OrderDraft extends ChangeNotifier {
  Address? _pickup;
  final deliveries = <DeliveryDraft>[DeliveryDraft()];
  int _current = 0;

  /// Livraison programmée (C3) plutôt que tout de suite ; [scheduledFor] est alors l'heure
  /// de passage choisie (null tant qu'elle ne l'est pas).
  bool later = false;
  DateTime? scheduledFor;

  bool get hasWhen => !later || scheduledFor != null;

  Address? get pickup => _pickup;
  set pickup(Address? value) {
    _pickup = value;
    notifyListeners();
  }

  DeliveryDraft get delivery => deliveries[_current];
  int get currentIndex => _current;

  /// Jusqu'à 10 livraisons dans la même commande (C4).
  static const maxDeliveries = 10;

  /// Ajoute une livraison (même point d'enlèvement) et la rend courante.
  void addDelivery() {
    if (deliveries.length >= maxDeliveries) return;
    deliveries.add(DeliveryDraft());
    _current = deliveries.length - 1;
    notifyListeners();
  }

  void select(int index) {
    _current = index.clamp(0, deliveries.length - 1);
    notifyListeners();
  }

  /// Toute modification d'une livraison passe par ici pour rafraîchir les écrans.
  void update(void Function(DeliveryDraft delivery) change) {
    change(delivery);
    notifyListeners();
  }

  void touch() => notifyListeners();
}
