import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/safety/safety_alert.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/layout.dart';
import '../../design/components/status.dart';
import '../../design/motion/liquid_background.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

/// 14 · Bouton d'alerte (SOS), en deux volets. Équipe Tara : maintien de 3 s, l'alerte part
/// avec la position (agents et contact d'urgence prévenus), un agent rappelle ; sans réseau,
/// elle reste sur le téléphone et peut partir par SMS. Police : appel du 117 en un geste
/// (et des pompiers ou du SAMU en cas d'accident), avec la position et la plaque à donner.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key, required this.onClose, this.orderId, this.orderReference});

  final VoidCallback onClose;

  /// Course en cours, jointe à l'alerte.
  final String? orderId;
  final String? orderReference;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  late final SafetyAlertController _safety = ref.read(safetyAlertProvider);
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(_safety.refreshPosition());
  }

  Future<void> _open(Uri uri) async {
    try {
      await ref.read(launcherProvider)(uri);
    } catch (_) {
      // Pas d'application Téléphone ou Messages : rien d'autre à proposer ici.
    }
  }

  Future<void> _call(String number) => _open(Uri(scheme: 'tel', path: number));

  /// SMS pré-rempli pour la ligne Tara : le livreur n'a qu'à appuyer sur Envoyer.
  Future<void> _sendSms(String hotline) {
    final l = AppLocalizations.of(context);
    final position = _safety.position;
    final reference = widget.orderReference;
    final text = [
      position == null
          ? l.sosSmsNoPosition
          : l.sosSmsBody(
              'https://maps.google.com/?q=${position.latitude.toStringAsFixed(5)},'
              '${position.longitude.toStringAsFixed(5)}',
            ),
      if (reference != null) l.sosSmsCourse(reference),
    ].join();
    // Espaces encodés %20 (et non « + », affiché tel quel par certaines applications SMS).
    return _open(Uri(scheme: 'sms', path: hotline, query: 'body=${Uri.encodeComponent(text)}'));
  }

  Future<void> _cancel() async {
    final cancelled = await _safety.cancelAlert();
    if (!mounted) return;
    setState(() => _notice = cancelled ? null : AppLocalizations.of(context).sosCancelNeedsNetwork);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final config = ref.watch(riderConfigProvider).value;
    final numbers = config?.emergencyNumbers ?? EmergencyNumbers.cameroon;
    final hotline = config?.safetyHotline ?? RiderConfigController.fallback['safetyHotline']! as String;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: TaraScreen(
        backgroundColor: c.alertBg,
        blobs: const [
          BlobSpec(alignment: Alignment(0, -0.15), size: 320, colors: BlobSpec.alarm, blur: 80, opacity: .45),
          BlobSpec(
            alignment: Alignment(1.3, -1.25),
            size: 280,
            colors: [TaraBrand.orange, TaraBrand.sos],
            blur: 70,
            opacity: .22,
            delay: Duration(seconds: 4),
          ),
        ],
        child: ListenableBuilder(
          listenable: _safety,
          builder: (context, _) {
            final status = _safety.status;
            final alert = _safety.alert;
            final position = _safety.position;
            final (title, body) = _texts(l, status, alert);
            // Appels (équipe Tara, police, secours) fixés en bas : jamais à faire défiler,
            // même sur un petit écran avec le texte agrandi.
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Bouton de 236 px (maquette), réduit sur les petits écrans.
                      final size = (constraints.maxHeight * .42).clamp(132.0, 236.0);
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      _Badge(l.sosBadge),
                                      const Spacer(),
                                      GlassIconButton(
                                        icon: TaraIcons.close,
                                        label: l.close,
                                        onPressed: widget.onClose,
                                        size: 46,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      style: TaraText.titleForm.copyWith(fontSize: 28, color: c.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      body,
                                      style: TaraText.body.copyWith(fontSize: 14, color: c.textSecondary),
                                    ),
                                  ),
                                  if (status == SafetyStatus.failed && _safety.error != null) ...[
                                    const SizedBox(height: 8),
                                    ErrorLine(_safety.error!),
                                  ],
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: size * .16),
                                child: Center(
                                  child: SosHoldButton(
                                    size: size,
                                    sent: _safety.active,
                                    onSent: () => unawaited(_safety.raise(orderId: widget.orderId)),
                                    idleHint: l.sosHold,
                                    holdingHint: l.sosHoldRemaining,
                                    sentHint: switch (status) {
                                      SafetyStatus.sending => l.sosSendingHint,
                                      SafetyStatus.pending => l.sosPendingHint,
                                      _ => l.sosSent,
                                    },
                                    semanticLabel: l.sosHoldLabel,
                                  ),
                                ),
                              ),
                              _PositionCard(
                                place: alert?.neighborhood ?? l.sosYourPosition,
                                detail: _positionLine(l, status, position),
                                plate: alert?.plate,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              label: l.sosCallTara,
                              icon: TaraIcons.headset,
                              onPressed: () => unawaited(_call(hotline)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _EmergencyButton(
                              label: l.sosCallPolice(numbers.police),
                              onPressed: () => unawaited(_call(numbers.police)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.sosAccident, style: TaraText.label.copyWith(color: c.textSecondary)),
                          _Link(label: l.sosFire(numbers.fire), onTap: () => unawaited(_call(numbers.fire))),
                          Text('·', style: TaraText.label.copyWith(color: c.textTertiary)),
                          _Link(label: l.sosMedical(numbers.medical), onTap: () => unawaited(_call(numbers.medical))),
                        ],
                      ),
                      if (status == SafetyStatus.pending || status == SafetyStatus.failed) ...[
                        const SizedBox(height: 4),
                        _EmergencyButton(
                          label: l.sosSendSms,
                          icon: TaraIcons.message,
                          onPressed: () => unawaited(_sendSms(hotline)),
                        ),
                      ],
                      if (_notice != null) ...[const SizedBox(height: 8), ErrorLine(_notice!)],
                      if (status == SafetyStatus.sent || status == SafetyStatus.pending)
                        _Link(label: l.sosCancel, onTap: () => unawaited(_cancel()), strong: true),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  (String, String) _texts(AppLocalizations l, SafetyStatus status, SafetyAlert? alert) => switch (status) {
    SafetyStatus.sent => (
      l.sosSentTitle,
      alert?.policeCalledAt != null
          ? l.sosPoliceCalledBody
          : alert?.acknowledgedAt != null
          ? l.sosAcknowledgedBody
          : l.sosSentBody,
    ),
    SafetyStatus.pending => (l.sosPendingTitle, l.sosPendingBody),
    SafetyStatus.failed => (l.sosFailedTitle, l.sosFailedBody),
    // Close par l'équipe : un nouveau maintien relance une alerte.
    _ => (l.sosIdleTitle, alert?.resolvedAt != null ? l.sosClosedBody : l.sosIdleBody),
  };

  String _positionLine(AppLocalizations l, SafetyStatus status, GeoPoint? position) {
    if (position == null) return status == SafetyStatus.failed ? l.sosPositionUnknown : l.sosPositionSearching;
    final meters = position.accuracy?.round();
    final shared = status == SafetyStatus.sent;
    if (meters == null) return shared ? l.sosPositionSharedPlain : l.sosPositionCurrentPlain;
    return shared ? l.sosPositionShared(meters) : l.sosPositionCurrent(meters);
  }
}

/// Pastille « Sécurité » en haut de l'écran.
class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.dangerTint,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: c.dangerText.withValues(alpha: c.isDark ? .45 : .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaraIcon(TaraIcons.shield, size: 16, color: c.dangerTextStrong),
          const SizedBox(width: 8),
          Text(
            label,
            style: TaraText.label.copyWith(fontWeight: FontWeight.w700, color: c.dangerTextStrong),
          ),
        ],
      ),
    );
  }
}

/// Position à donner au téléphone (quartier, précision) et plaque de la moto.
class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.place, required this.detail, this.plate});
  final String place;
  final String detail;
  final String? plate;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: MergeSemantics(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.chipBg, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: TaraIcon(TaraIcons.mapPin, size: 20, color: c.dangerTextStrong),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    style: TaraText.text.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  const SizedBox(height: 1),
                  Text(detail, style: TaraText.small.copyWith(color: c.textSecondary)),
                  if (plate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).sosPlate(plate!),
                      style: TaraText.smallStrong.copyWith(color: c.textPrimary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton rouge plein (appel des secours, SMS d'alerte).
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({required this.label, required this.onPressed, this.icon = TaraIcons.phone});
  final String label;
  final VoidCallback onPressed;
  final TaraIconData icon;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    const white = Color(0xFFFFFFFF);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: TaraBrand.sos,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: TaraBrand.sos.withValues(alpha: c.isDark ? .4 : .3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TaraIcon(icon, size: 18, color: white),
              const SizedBox(width: 8),
              // Une ligne : avec le texte agrandi, le libellé rétrécit au lieu d'être coupé.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TaraText.buttonSecondary.copyWith(fontWeight: FontWeight.w800, color: white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lien souligné, zone tactile de 44 px (pompiers, SAMU, annuler l'alerte).
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap, this.strong = false});
  final String label;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final color = strong ? c.dangerTextStrong : c.textPrimary;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TaraText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
