import 'dart:math';

import 'package:tara_ui/format.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';

/// Payer une livraison avec le solde : titre et détail du choix. Une boutique paie d'abord
/// avec son solde Tara, puis avec ses ventes ; un particulier avec son solde Tara.
({String title, String body}) walletChoice(
  AppLocalizations l, {
  required bool shop,
  required Wallet? wallet,
  required int total,
}) {
  String f(int amount) => '${formatAmount(amount)}\u00a0F';
  if (!shop) {
    final title = l.payWallet;
    if (wallet == null) return (title: title, body: '');
    final balance = wallet.customerBalance;
    return (
      title: title,
      body: total > 0 && balance < total ? l.walletTooLow(f(balance)) : l.payWalletBody(f(balance)),
    );
  }
  if (wallet == null) return (title: l.payWalletShop, body: '');
  final tara = max(0, wallet.customerBalance);
  final sales = wallet.merchantBalance ?? 0;
  final title = tara > 0 ? l.payWalletTaraAndSales : l.payWalletShop;
  final available = wallet.spendable;
  if (total <= 0) return (title: title, body: l.payWalletBody(f(available)));
  if (available < total) return (title: title, body: l.walletTooLow(f(available)));
  final fromTara = min(tara, total);
  final fromSales = total - fromTara;
  return (
    title: title,
    body: fromSales == 0
        ? l.payWalletTaraBody(f(tara - total))
        : fromTara > 0
        ? l.payWalletBothBody(f(sales - fromSales))
        : l.payWalletShopBody(f(sales - fromSales)),
  );
}
