import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Résumé de l'accueil : nom, gains et courses du jour, temps en ligne, solde disponible.
@immutable
class HomeSummary {
  const HomeSummary({
    required this.fullName,
    required this.earnings,
    required this.delivered,
    required this.onlineSeconds,
    required this.available,
    this.withdrawalMinimum = 0,
  });

  final String fullName;
  final int earnings;
  final int delivered;
  final int onlineSeconds;

  /// Solde prépayé disponible (G5) : couvre l'argent des courses avec encaissement.
  final int available;

  /// Plus petit retrait Mobile Money, rappelé avant une recharge.
  final int withdrawalMinimum;
}

final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  final api = ref.read(riderApiProvider);
  final (me, earnings, wallet) = await (api.me(), api.earnings('day'), api.wallet()).wait;
  return HomeSummary(
    fullName: (me['fullName'] as String?) ?? '',
    earnings: earnings.earnings,
    delivered: earnings.delivered,
    onlineSeconds: earnings.onlineSeconds,
    available: ((wallet['available'] as num?) ?? 0).toInt(),
    withdrawalMinimum: (((wallet['withdrawal'] as Map?)?['minimum'] as num?) ?? 0).toInt(),
  );
});

/// Nom complet du livreur seul (en-tête de « Mes gains »).
final riderNameProvider = FutureProvider<String>((ref) async {
  final me = await ref.read(riderApiProvider).me();
  return (me['fullName'] as String?) ?? '';
});
