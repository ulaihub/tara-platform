import 'package:flutter/material.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

/// Paiement Mobile Money demandé : l'expéditeur le valide sur son téléphone (code secret).
/// Refusé ou sans réponse : nouvelle demande, ou annulation de la commande.
class PaymentPending extends StatelessWidget {
  const PaymentPending({
    super.key,
    required this.amount,
    required this.phone,
    required this.failed,
    required this.busy,
    required this.onRetry,
    required this.onCancel,
    this.error,
  });

  final int amount;

  /// Chiffres nationaux du numéro qui paie.
  final String phone;
  final bool failed;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return ScrollWithFooter(
      horizontal: 20,
      top: 40,
      content: [
        Center(
          child: failed
              ? const IconTile(icon: TaraIcons.alertCircle, size: 72, radius: 24)
              : const SizedBox(height: 72, child: GooLoader()),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            failed ? l.paymentFailed : l.payingTitle,
            textAlign: TextAlign.center,
            style: TaraText.titleForm.copyWith(color: c.textPrimary),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l.payingBody('${formatAmount(amount)} F', displayPhone(phone)),
          textAlign: TextAlign.center,
          style: TaraText.body.copyWith(color: c.textSecondary),
        ),
        if (error != null) ...[const SizedBox(height: 14), ErrorLine(error!)],
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed) PrimaryButton(label: l.retryPayment, icon: TaraIcons.refresh, loading: busy, onPressed: onRetry),
          Center(
            child: TaraLink(label: l.cancelOrder, onPressed: busy ? null : onCancel),
          ),
        ],
      ),
    );
  }
}

/// Commande envoyée : confettis, code d'enlèvement (affiché une seule fois), puis la
/// recherche d'un livreur, annoncée dès qu'il accepte.
class OrderPlaced extends StatelessWidget {
  const OrderPlaced({
    super.key,
    required this.placement,
    required this.recipients,
    required this.riderFound,
    required this.onDone,
    this.scheduled,
  });

  final Placement placement;

  /// Noms des destinataires, dans l'ordre des commandes.
  final List<String> recipients;
  final bool riderFound;
  final VoidCallback onDone;

  /// « demain à 20:00 » pour une livraison programmée.
  final String? scheduled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final orders = placement.orders;
    final code = placement.pickupCode;
    return Stack(
      children: [
        ScrollWithFooter(
          horizontal: 20,
          top: 36,
          content: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: .4, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: TaraBrand.gradient,
                    shape: BoxShape.circle,
                    boxShadow: c.brandShadow,
                  ),
                  child: const Center(
                    child: TaraIcon(TaraIcons.check, size: 40, strokeWidth: 3, color: TaraBrand.onBrand),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                scheduled == null ? l.placedTitle : l.placedScheduledTitle,
                textAlign: TextAlign.center,
                style: TaraText.titleForm.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              orders.length == 1
                  ? '${orders.first.reference} · ${recipients.first}'
                  : '${l.deliveriesCount(orders.length)} · ${orders.first.reference} → ${orders.last.reference}',
              textAlign: TextAlign.center,
              style: TaraText.label.copyWith(color: c.textSecondary),
            ),
            if (code != null) ...[
              const SizedBox(height: 22),
              GlassCard(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  children: [
                    Text(l.pickupCodeLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '${l.pickupCodeLabel} : ${code.split('').join(' ')}',
                      excludeSemantics: true,
                      child: Text(
                        code.split('').join(' '),
                        style: TaraText.amountXL.copyWith(color: c.textPrimary, letterSpacing: 6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.pickupCodeHelp,
                      textAlign: TextAlign.center,
                      style: TaraText.small.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            GlassCard(
              radius: 22,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    // Pastille de 44 px : animation de recherche, coche verte ou horloge,
                    // toujours alignée sur le texte.
                    SizedBox.square(
                      dimension: 44,
                      child: scheduled == null && !riderFound
                          ? const Center(child: GooLoader(compact: true))
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: riderFound ? c.successTintBg : c.chipBorder.withValues(alpha: .25),
                                border: Border.all(color: riderFound ? c.successTintBorder : c.chipBorder),
                              ),
                              child: Center(
                                child: TaraIcon(
                                  riderFound ? TaraIcons.check : TaraIcons.clock,
                                  size: 22,
                                  strokeWidth: 2.4,
                                  color: riderFound ? c.success : c.accentText,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scheduled != null
                            ? l.scheduledPickup(scheduled!)
                            : riderFound
                            ? l.riderFound
                            : l.searchingRider,
                        style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          footer: PrimaryButton(label: l.backHome, icon: TaraIcons.home, onPressed: onDone),
        ),
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}
