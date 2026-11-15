import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
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
import '../common/scoped_page.dart';
import '../home/home_screen.dart' show walletProvider;
import '../wallet/wallet_screen.dart';

/// Refus du serveur que le portefeuille permet de régler (solde, dette, retrait en cours).
const _walletErrors = {'ACCOUNT_HAS_BALANCE', 'ACCOUNT_HAS_DEBT', 'ACCOUNT_HAS_PAYOUT_IN_PROGRESS'};

/// Suppression du compte (droit à l'effacement) : ce qui est effacé, ce qui bloque (argent
/// encore chez Tara, retrait en cours), puis code SMS et suppression définitive. Le serveur
/// refuse de toute façon tant qu'une commande, une dette, un solde ou un retrait reste.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, required this.me, required this.onBack});

  final Me me;
  final VoidCallback onBack;

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  final _code = TextEditingController();
  OtpChallenge? _challenge;
  bool _busy = false;
  String? _error;

  /// Le refus porte sur l'argent : lien vers le portefeuille.
  bool _walletError = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Ce qui empêche la suppression, d'après le portefeuille (le serveur vérifie aussi).
  String? _blocker(AppLocalizations l, Wallet wallet) {
    String f(int amount) => '${formatAmount(amount)} F';
    final shop = wallet.merchantBalance ?? 0;
    if (shop < 0) return l.deleteAccountDebt(f(-shop));
    if (wallet.openPayout != null) return l.deleteAccountPayout;
    final left = wallet.customerBalance + (shop > 0 ? shop : 0);
    if (left > 0) return l.deleteAccountBalance(f(left));
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

  Future<void> _sendCode() => _run(() async {
    final challenge = await ref.read(clientApiProvider).requestDeletionCode();
    if (mounted) setState(() => _challenge = challenge);
  });

  Future<void> _delete() => _run(() async {
    final challenge = _challenge;
    if (challenge == null) return;
    await ref.read(clientApiProvider).deleteAccount(challengeId: challenge.challengeId, code: _code.text);
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
    final challenge = _challenge;

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
            GlassButton(label: l.openWallet, icon: TaraIcons.wallet, height: 48, onPressed: _openWallet),
          ] else if (challenge != null) ...[
            Text(
              l.deleteAccountCodeSent(displayPhone(widget.me.phone)),
              style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            TaraTextField(
              label: l.deleteAccountCodeLabel,
              hint: '000000',
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TaraLink(label: l.deleteAccountResend, onPressed: _busy ? null : () => unawaited(_sendCode())),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorLine(_error!),
            if (_walletError && blocker == null) ...[
              const SizedBox(height: 10),
              GlassButton(label: l.openWallet, icon: TaraIcons.wallet, height: 48, onPressed: _openWallet),
            ],
          ],
        ],
        footer: challenge == null
            ? PrimaryButton(
                label: l.deleteAccountSendCode,
                icon: TaraIcons.message,
                loading: _busy,
                onPressed: wallet.value == null || blocker != null ? null : () => unawaited(_sendCode()),
              )
            : PrimaryButton(
                label: l.deleteAccountConfirm,
                icon: TaraIcons.check,
                loading: _busy,
                onPressed: _code.text.length == 6 ? () => unawaited(_delete()) : null,
              ),
      ),
    );
  }
}
