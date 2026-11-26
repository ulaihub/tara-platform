import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/pin_flow.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pin.dart';
import '../common/scoped_page.dart';
import '../home/home_screen.dart' show walletProvider;
import '../wallet/wallet_screen.dart';

/// Refus du serveur que le portefeuille permet de régler (solde, dette, retrait en cours).
const _walletErrors = {'ACCOUNT_HAS_BALANCE', 'ACCOUNT_HAS_DEBT', 'ACCOUNT_HAS_PAYOUT_IN_PROGRESS'};

/// Suppression du compte (droit à l'effacement) : ce qui est effacé, ce qui bloque (argent
/// encore chez Tara, retrait en cours), puis code secret (ou empreinte) et suppression
/// définitive. Le serveur refuse de toute façon tant qu'une commande, une dette, un solde ou
/// un retrait reste.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, required this.me, required this.onBack});

  final Me me;
  final VoidCallback onBack;

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  bool _busy = false;
  String? _error;

  /// Le refus porte sur l'argent : lien vers le portefeuille.
  bool _walletError = false;

  /// Ce qui empêche la suppression, d'après le portefeuille (le serveur vérifie aussi).
  String? _blocker(AppLocalizations l, Wallet wallet) {
    String f(int amount) => '${formatAmount(amount)} F';
    final shop = wallet.merchantBalance ?? 0;
    if (shop < 0) return l.deleteAccountDebt(f(-shop));
    if (wallet.openPayout != null) return l.deleteAccountPayout;
    final left = wallet.customerBalance + (shop > 0 ? shop : 0);
    if (left > 0) {
      // Sous le minimum d'un envoi Mobile Money, il ne peut pas être retiré : il sert aux livraisons.
      final small =
          (wallet.customerBalance > 0 && wallet.customerBalance < wallet.customerWithdrawalMinimum) ||
          (shop > 0 && shop < wallet.withdrawalMinimum);
      return small
          ? l.deleteAccountSmallBalance(
              f(left),
              f(
                wallet.withdrawalMinimum > wallet.customerWithdrawalMinimum
                    ? wallet.withdrawalMinimum
                    : wallet.customerWithdrawalMinimum,
              ),
            )
          : l.deleteAccountBalance(f(left));
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _walletError = false;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(context, error);
        _walletError = _walletErrors.contains(error.code);
      });
      if (_walletError) ref.invalidate(walletProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() => _run(() async {
    final api = ref.read(clientApiProvider);
    final deleted = await withPin<bool>(
      context,
      pinServices(context, ref),
      reason: AppLocalizations.of(context).pinReasonDelete,
      action: (proof) async {
        await api.deleteAccount(proof: proof);
        return true;
      },
    );
    if (deleted != true) return;
    // Compte effacé : session révoquée par le serveur, l'app revient à l'accueil.
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (_) {
      // Jeton déjà révoqué : la session locale est effacée quand même.
    }
  });

  void _openWallet() => unawaited(
    Navigator.of(
      context,
    ).push(scopedPage<void>(context, (route) => WalletScreen(me: widget.me, onBack: () => Navigator.of(route).pop()))),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final wallet = ref.watch(walletProvider);
    final blocker = switch (wallet.value) {
      final data? => _blocker(l, data),
      null => null,
    };

    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: _busy ? null : widget.onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.deleteAccountTitle, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.deleteAccountBody, style: TaraText.text.copyWith(color: c.textPrimary)),
                const SizedBox(height: 10),
                Text(l.deleteAccountFinal, style: TaraText.label.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (wallet.isLoading && wallet.value == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: GooLoader(compact: true)),
            )
          else if (blocker != null) ...[
            TintBox(
              tone: TintTone.danger,
              child: Semantics(
                liveRegion: true,
                child: Text(blocker, style: TaraText.text.copyWith(color: c.textPrimary)),
              ),
            ),
            const SizedBox(height: 12),
            GlassButton(label: l.openWallet, icon: TaraIcons.wallet, onPressed: _openWallet),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorLine(_error!),
            if (_walletError && blocker == null) ...[
              const SizedBox(height: 10),
              GlassButton(label: l.openWallet, icon: TaraIcons.wallet, onPressed: _openWallet),
            ],
          ],
        ],
        footer: PrimaryButton(
          label: l.deleteAccountConfirmPin,
          icon: TaraIcons.lock,
          loading: _busy,
          onPressed: wallet.value == null || blocker != null ? null : () => unawaited(_delete()),
        ),
      ),
    );
  }
}
