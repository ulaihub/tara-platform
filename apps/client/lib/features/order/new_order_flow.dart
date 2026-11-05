import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/scoped_page.dart';
import 'address_editor.dart';
import 'order_draft.dart';
import 'package_step.dart';
import 'pickup_step.dart';
import 'recipient_step.dart';

/// Nouvelle livraison (C1–C4), en cinq étapes : enlèvement, destinataire, colis, quand,
/// récapitulatif. « Retour » (ou le geste retour du téléphone) revient à l'étape
/// précédente ; à la première, il ferme le parcours.
class NewOrderFlow extends ConsumerStatefulWidget {
  const NewOrderFlow({super.key, required this.me, required this.onClose});

  final Me me;
  final VoidCallback onClose;

  @override
  ConsumerState<NewOrderFlow> createState() => _NewOrderFlowState();
}

class _NewOrderFlowState extends ConsumerState<NewOrderFlow> {
  static const _total = 5;

  /// Étapes déjà construites ; les suivantes (quand, récapitulatif) arrivent ensuite.
  static const _built = 3;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -1.1), size: 260, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.35, 0.9), size: 220, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 4)),
  ];

  final _draft = OrderDraft();
  late final AppLifecycleListener _lifecycle;
  int _step = 0;
  bool _tried = false;
  Timer? _linkTimer;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_watchLinks);
    // Retour de WhatsApp ou des SMS : le destinataire a peut-être déjà répondu.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_checkLinks()));
  }

  @override
  void dispose() {
    _linkTimer?.cancel();
    _lifecycle.dispose();
    _draft.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
    0 => _draft.pickup != null,
    1 => _draft.delivery.hasRecipient && _draft.delivery.hasAddress,
    2 => _draft.delivery.hasPackage,
    _ => true,
  };

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_stepValid) {
      setState(() => _tried = true);
      return;
    }
    if (_step + 1 < _built) {
      setState(() {
        _step++;
        _tried = false;
      });
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      widget.onClose();
      return;
    }
    setState(() {
      _step--;
      _tried = false;
    });
  }

  /// Interroge les liens de localisation en attente tant que le parcours est ouvert.
  void _watchLinks() {
    final waiting = _draft.deliveries.any((d) => d.dropoff == null && d.link?.status == 'PENDING');
    if (waiting) {
      _linkTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_checkLinks()));
    } else {
      _linkTimer?.cancel();
      _linkTimer = null;
    }
  }

  Future<void> _checkLinks() async {
    for (final delivery in List.of(_draft.deliveries)) {
      final link = delivery.link;
      if (delivery.dropoff != null || link == null || link.status != 'PENDING') continue;
      try {
        final fresh = await ref.read(clientApiProvider).locationLink(link.id);
        if (!mounted || delivery.link?.id != link.id) continue;
        delivery
          ..link = fresh
          ..dropoff = fresh.address ?? delivery.dropoff;
        if (fresh.address != null) TaraFeedback.play(context, TaraSound.received);
        _draft.touch();
      } catch (_) {
        // Réseau absent : nouvel essai au tour suivant.
      }
    }
  }

  Future<void> _placeAddress({required bool pickup}) async {
    final l = AppLocalizations.of(context);
    final delivery = _draft.delivery;
    final navigator = Navigator.of(context);
    final address = await navigator.push<Address>(
      scopedPage(
        context,
        (context) => AddressEditor(
          title: pickup ? l.pickupAddressTitle : l.deliveryAddress,
          forPickup: pickup,
          contactName: pickup ? null : delivery.recipientName.trim(),
          contactPhone: pickup || delivery.recipientPhone.isEmpty ? null : '+237${delivery.recipientPhone}',
          initial: switch (pickup ? null : delivery.dropoff) {
            final current? => MapPoint(current.latitude, current.longitude),
            null => null,
          },
          onBack: navigator.pop,
          onSaved: navigator.pop,
        ),
      ),
    );
    if (address == null || !mounted) return;
    if (pickup) {
      ref.invalidate(pickupAddressesProvider);
      _draft.pickup = address;
    } else {
      _draft.update(
        (d) => d
          ..dropoff = address
          ..link = null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final titles = [l.stepPickup, l.stepRecipient, l.stepPackage, l.stepWhen, l.stepSummary];
    final me = widget.me;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: TaraScreen(
        safeBottom: false,
        blobs: _blobs,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: _step == 0 ? TaraIcons.close : TaraIcons.chevronLeft,
                    label: _step == 0 ? l.close : l.back,
                    onPressed: _back,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.stepOf(_step + 1, _total, titles[_step]),
                          style: TaraText.label.copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        LiquidProgressBar(value: (_step + 1) / _total),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _draft,
                builder: (context, _) => ScrollWithFooter(
                  horizontal: 20,
                  top: 22,
                  content: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          0 => PickupStep(
                            draft: _draft,
                            showErrors: _tried,
                            onAddAddress: () => unawaited(_placeAddress(pickup: true)),
                          ),
                          2 => PackageStep(draft: _draft, merchant: me.merchant != null, showErrors: _tried),
                          _ => RecipientStep(
                            draft: _draft,
                            senderName: me.merchant?.shopName ?? me.fullName ?? '',
                            showErrors: _tried,
                            onPlaceOnMap: () => unawaited(_placeAddress(pickup: false)),
                          ),
                        },
                      ),
                    ),
                  ],
                  footer: PrimaryButton(label: l.continueLabel, icon: TaraIcons.arrowRight, onPressed: _next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
