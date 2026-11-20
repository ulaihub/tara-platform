import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/support_api.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../course/course_page.dart';

/// Fermeture du compte livreur : demandée à l'équipe Tara (service client), qui la fait
/// depuis le back-office après vérification. Rien ne part tant qu'une course, de l'argent
/// dû à Tara, un solde ou un retrait en cours empêche la fermeture.
class CloseAccountScreen extends ConsumerStatefulWidget {
  const CloseAccountScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<CloseAccountScreen> createState() => _CloseAccountScreenState();
}

class _CloseAccountScreenState extends ConsumerState<CloseAccountScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  late Future<RiderWallet> _wallet = ref.read(riderApiProvider).riderWallet();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  /// Ce qui empêche la fermeture, dans l'ordre où le livreur peut le régler.
  String? _blocker(AppLocalizations l, RiderWallet wallet, bool onCourse) {
    String f(int amount) => '${formatAmount(amount)} F';
    if (onCourse) return l.closeAccountCourse;
    final debt = (wallet.earnings < 0 ? -wallet.earnings : 0) + wallet.cashHeld;
    if (debt > 0) return l.closeAccountDebt(f(debt));
    if (wallet.openPayout != null) return l.closeAccountPayout;
    if (wallet.earnings > 0) {
      // Sous le minimum du prestataire, le retrait est impossible : le service client règle.
      return wallet.earnings < wallet.withdrawalMinimum
          ? l.closeAccountSmallBalance(f(wallet.earnings), f(wallet.withdrawalMinimum))
          : l.closeAccountBalance(f(wallet.earnings));
    }
    return null;
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(supportBackendProvider)
          .open(
            category: SupportCategory.other,
            subject: l.closeAccountTicketSubject,
            message: l.closeAccountTicketMessage,
          );
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final activeOrder = ref.watch(activeOrderProvider);

    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: FutureBuilder<RiderWallet>(
        future: _wallet,
        builder: (context, snapshot) {
          final wallet = snapshot.data;
          return ListenableBuilder(
            listenable: activeOrder,
            builder: (context, _) {
              final blocker = wallet == null ? null : _blocker(l, wallet, activeOrder.order != null);
              return ScrollWithFooter(
                horizontal: 20,
                top: 8,
                content: [
                  CourseHeader(
                    kicker: l.myAccount,
                    title: l.closeAccountTitle,
                    subtitle: l.closeAccountRowSubtitle,
                    onBack: _sending ? () {} : widget.onBack,
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    radius: 24,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.closeAccountBody, style: TaraText.text.copyWith(color: c.textPrimary)),
                        const SizedBox(height: 10),
                        Text(l.closeAccountErased, style: TaraText.label.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_sent)
                    TintBox(
                      tone: TintTone.success,
                      child: Semantics(
                        liveRegion: true,
                        child: Text(l.closeAccountSent, style: TaraText.text.copyWith(color: c.textPrimary)),
                      ),
                    )
                  else if (snapshot.hasError)
                    Row(
                      children: [
                        Expanded(child: ErrorLine(errorMessage(context, snapshot.error!))),
                        TaraLink(
                          label: l.retry,
                          onPressed: () => setState(() => _wallet = ref.read(riderApiProvider).riderWallet()),
                        ),
                      ],
                    )
                  else if (wallet == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: GooLoader(compact: true)),
                    )
                  else if (blocker != null)
                    TintBox(
                      tone: TintTone.danger,
                      child: Semantics(
                        liveRegion: true,
                        child: Text(blocker, style: TaraText.text.copyWith(color: c.textPrimary)),
                      ),
                    ),
                  if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
                ],
                footer: _sent
                    ? PrimaryButton(label: l.close, icon: TaraIcons.check, onPressed: widget.onBack)
                    : PrimaryButton(
                        label: l.closeAccountSend,
                        icon: TaraIcons.arrowRight,
                        loading: _sending,
                        onPressed: wallet == null || blocker != null ? null : () => unawaited(_send()),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
