import 'package:flutter/material.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/operator_logo.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pickup_qr.dart';

/// Paiement Mobile Money demandé (maquette) : référence en tête, jauge liquide ronde avec
/// le logo de l'opérateur et le montant, consigne, numéro qui paie. Refusé ou sans réponse :
/// nouvelle demande, ou annulation de la commande.
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
    this.reference,
    this.method,
    this.onBack,
  });

  final int amount;

  /// Chiffres nationaux du numéro qui paie.
  final String phone;
  final bool failed;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final String? error;

  /// « TR-48302 » (ou le premier colis d'un envoi).
  final String? reference;

  /// MOMO_ORANGE ou MOMO_MTN : logo et nom de l'opérateur.
  final String? method;
  final VoidCallback? onBack;

  /// « 6 77 •• •• 56 » : le début et la fin du numéro.
  static String masked(String digits) =>
      digits.length < 9 ? digits : '${digits[0]} ${digits.substring(1, 3)} •• •• ${digits.substring(7)}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final operatorName = switch (method) {
      'MOMO_ORANGE' => l.payOrange,
      'MOMO_MTN' => l.payMtn,
      _ => l.mobileMoney,
    };
    final shown = masked(phone);
    final amountText = '${formatAmount(amount)} F';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              if (onBack != null) ...[
                GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: busy ? null : onBack),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (reference case final ref?)
                        Text(ref, style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 18)),
                      Text(
                        l.trackAwaitingPayment,
                        style: TaraText.small.copyWith(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ScrollWithFooter(
            horizontal: 20,
            top: 14,
            content: [
              // Jauge liquide qui monte pendant l'attente ; vide si le paiement a échoué.
              Center(
                child: Semantics(
                  label: '$operatorName, $amountText',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.textPrimary.withValues(alpha: .08), width: 6),
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (!failed)
                              const LiquidFill(
                                level: .38,
                                amplitude: 6,
                                front: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                                  stops: [0, .18, .5],
                                ),
                                back: Color.fromRGBO(255, 61, 0, .5),
                              ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (method case final m? when m.startsWith('MOMO_'))
                                  OperatorLogo(m, size: 46)
                                else
                                  TaraIcon(TaraIcons.phone, size: 40, color: c.accentText),
                                const SizedBox(height: 4),
                                Text(
                                  amountText,
                                  style: TaraText.titlePanel.copyWith(
                                    color: failed ? c.textPrimary : Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    shadows: failed
                                        ? null
                                        : const [
                                            Shadow(
                                              color: Color.fromRGBO(0, 0, 0, .25),
                                              blurRadius: 6,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  failed ? l.paymentFailed : l.payingTitle,
                  textAlign: TextAlign.center,
                  style: TaraText.titleForm.copyWith(color: c.textPrimary, fontSize: 20),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                failed ? l.paymentFailedBody : l.payingBodyOperator(amountText, shown, operatorName),
                textAlign: TextAlign.center,
                style: TaraText.label.copyWith(color: c.textPrimary.withValues(alpha: .74), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              BoxedField(
                label: l.payerPhoneLabel,
                value: shown,
                helper: l.payerPhoneHelp(operatorName),
                trailing: method != null && method!.startsWith('MOMO_') ? OperatorLogo(method!, size: 36) : null,
              ),
              if (error != null) ...[const SizedBox(height: 14), ErrorLine(error!)],
            ],
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failed) PrimaryButton(label: l.retryPayment, loading: busy, onPressed: onRetry),
                Center(
                  child: TaraLink(
                    label: l.cancelDelivery,
                    onPressed: busy ? null : onCancel,
                    style: TaraText.label.copyWith(fontSize: 13, color: c.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Commande envoyée : confettis, code d'enlèvement (affiché une seule fois), puis la
/// recherche d'un livreur, annoncée dès qu'il accepte. Plusieurs colis : chacun a son
/// numéro, à écrire dessus, et son livreur annoncé dès qu'il accepte.
class OrderPlaced extends StatelessWidget {
  const OrderPlaced({
    super.key,
    required this.placement,
    required this.recipients,
    required this.assigned,
    required this.onDone,
    this.details = const [],
    this.onTrack,
    this.scheduled,
  });

  /// Suivi de la livraison (une seule commande).
  final VoidCallback? onTrack;

  final Placement placement;

  /// Noms des destinataires, dans l'ordre des commandes.
  final List<String> recipients;

  /// Quartier et « Gros objet » de chaque colis, dans l'ordre des commandes.
  final List<String> details;

  /// Commandes dont le livreur a accepté la course.
  final Set<String> assigned;
  final VoidCallback onDone;

  /// « demain à 20:00 » pour une livraison programmée.
  final String? scheduled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final orders = placement.orders;
    final code = placement.pickupCode;
    final batch = orders.length > 1;
    final found = orders.where((o) => assigned.contains(o.id)).length;
    final riderFound = found > 0 && found == orders.length;
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
                    const SizedBox(height: 10),
                    // Le livreur le scanne (maquette Scanner) ; les chiffres restent dessous.
                    PickupQr(reference: orders.first.reference, code: code, size: 150),
                    const SizedBox(height: 8),
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
                      batch ? l.pickupCodeHelpBatch : l.pickupCodeHelp,
                      textAlign: TextAlign.center,
                      style: TaraText.small.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
            if (batch) ...[
              const SizedBox(height: 14),
              _ParcelNumbers(
                orders: orders,
                recipients: recipients,
                details: details,
                assigned: assigned,
                searching: scheduled == null,
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
                            : batch
                            ? (riderFound ? l.allRidersFound : l.ridersFound(found, orders.length))
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
          footer: onTrack == null
              ? PrimaryButton(label: l.backHome, icon: TaraIcons.home, onPressed: onDone)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(label: l.trackDelivery, icon: TaraIcons.navigation, onPressed: onTrack),
                    Center(
                      child: TaraLink(label: l.backHome, onPressed: onDone),
                    ),
                  ],
                ),
        ),
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

/// « Écrivez son numéro sur chaque colis » : un grand numéro par colis, son destinataire,
/// et son livreur annoncé dès qu'il accepte. Le livreur reçoit le même numéro.
class _ParcelNumbers extends StatelessWidget {
  const _ParcelNumbers({
    required this.orders,
    required this.recipients,
    required this.details,
    required this.assigned,
    required this.searching,
  });

  final List<PlacedOrder> orders;
  final List<String> recipients;
  final List<String> details;
  final Set<String> assigned;

  /// Livraison immédiate : on cherche un livreur par colis (sinon, créneau programmé).
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.writeNumbersTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(l.writeNumbersBody, style: TaraText.small.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          for (final (i, order) in orders.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: MergeSemantics(
                child: Row(
                  children: [
                    Semantics(
                      label: l.parcelNumberSemantics(i + 1),
                      excludeSemantics: true,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: TaraBrand.gradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TaraText.titlePanel.copyWith(color: TaraBrand.onBrand, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i < recipients.length ? recipients[i] : order.reference,
                            style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [if (i < details.length && details[i].isNotEmpty) details[i], order.reference].join(' · '),
                            style: TaraText.small.copyWith(color: c.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    if (searching) ...[
                      const SizedBox(width: 8),
                      if (assigned.contains(order.id))
                        InfoPill(label: l.riderFoundShort, tone: TintTone.success, icon: TaraIcons.check)
                      else
                        InfoPill(label: l.riderSearchingShort, dot: c.accentText, blinkDot: true),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
