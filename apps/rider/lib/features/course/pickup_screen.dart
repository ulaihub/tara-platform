import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/step_labels.dart';
import '../map/tara_map.dart';
import 'address_help.dart';
import 'course_scaffold.dart';

/// 08 · Enlèvement : itinéraire jusqu'au vendeur, montant à encaisser sur place, code de
/// l'expéditeur et photo du colis. « Colis récupéré » passe par la file hors connexion.
/// « Colis non conforme ? » ouvre le refus du colis (trop grand, trop lourd, interdit…).
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onPickedUp,
    required this.onRefuse,
    this.onSenderAbsent,
    this.now,
  });

  final RiderOrder order;

  /// Retour à l'accueil, la course reste en cours.
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis récupéré : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onPickedUp;

  /// « Colis non conforme ? » : écran de refus du colis.
  final VoidCallback onRefuse;

  /// Parti sans le colis : l'expéditeur n'est pas venu après l'attente maximale (D).
  final VoidCallback? onSenderAbsent;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  final _code = TextEditingController();
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  /// Arrivée signalée au point d'enlèvement : l'attente compte depuis là (D).
  late DateTime? _arrivedAt = widget.order.arrivedPickupAt;
  bool _arriving = false;
  bool _confirmLeave = false;
  bool _leaving = false;
  Timer? _tick;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    if (_arrivedAt != null) _startTick();
    // Enlèvement refusé resté dans la file (écran rouvert) : on reprend où il en était.
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'pickup');
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// Le temps d'attente affiché avance toute seule.
  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  /// L'expéditeur ne vient pas (D) : après l'attente maximale, sur place, après 2 appels. Le
  /// premier toucher annonce ce qu'il paiera ; le second annule la course.
  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    if (!_confirmLeave) {
      setState(() => _confirmLeave = true);
      return;
    }
    setState(() {
      _leaving = true;
      _error = null;
    });
    try {
      final at = await ref.read(courseActionsProvider).position();
      if (!mounted) return;
      if (at == null) {
        setState(() => _error = l.noPositionYet);
        return;
      }
      await ref
          .read(riderApiProvider)
          .senderAbsent(
            widget.order.id,
            latitude: at.latitude,
            longitude: at.longitude,
            callLog: [for (final call in ref.read(callJournalProvider).forOrder(widget.order.id)) call.toApi()],
          );
      await ref.read(courseActionsProvider).activeOrder.update(widget.order.withStatus('CANCELLED'));
      widget.onSenderAbsent?.call();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) {
        setState(() {
          _leaving = false;
          _confirmLeave = false;
        });
      }
    }
  }

  /// « Je suis arrivé » : sur place seulement (le serveur vérifie la position).
  Future<void> _arrive() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _arriving = true;
      _error = null;
    });
    try {
      final at = await ref.read(courseActionsProvider).position();
      if (!mounted) return;
      if (at == null) {
        setState(() => _error = l.noPositionYet);
        return;
      }
      final updated = await ref
          .read(riderApiProvider)
          .arrived(widget.order.id, latitude: at.latitude, longitude: at.longitude);
      if (!mounted) return;
      setState(() => _arrivedAt = updated.arrivedPickupAt ?? _now());
      _startTick();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
  }

  Future<void> _takePhoto() async {
    final path = await ref.read(takeProofPhotoProvider)();
    if (path == null || !mounted) return;
    setState(() {
      _photoPath = path;
      _photoAt = widget.now?.call() ?? DateTime.now();
      _error = null;
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final photo = _photoPath;
    if (photo == null || _code.text.length != 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final at = await ref.read(courseActionsProvider).position();
    if (!mounted) return;
    if (at == null) {
      setState(() {
        _busy = false;
        _error = l.noPositionYet;
      });
      return;
    }
    final result = await ref
        .read(courseActionsProvider)
        .pickUp(widget.order, code: _code.text, photoPath: photo, at: at, retryActionId: _refusedActionId);
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _refusedActionId = result.actionId;
        _error = result.message ?? l.genericError;
        _code.clear();
      });
      TaraFeedback.play(context, TaraSound.error);
      return;
    }
    TaraFeedback.play(context, TaraSound.pickedUp);
    widget.onPickedUp(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final steps = [l.stepPickup, if (order.collectAtDelivery > 0) l.stepCollect, l.stepDelivery];
    final senderName = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final phone = order.sender.phone ?? order.pickup.contactPhone;
    final ready = _photoPath != null && _code.text.length == 4;

    return CourseScaffold(
      order: order,
      stop: MapStop(latitude: order.pickup.latitude, longitude: order.pickup.longitude, label: senderName),
      title: (route, _) => route?.minutes == null ? l.toPickup : l.toPickupMinutes(route!.minutes!),
      onBack: widget.onBack,
      onSos: widget.onSos,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Enlèvement définitif : on glisse plutôt que toucher, pour éviter l'erreur.
          SwipeButton(
            label: l.parcelCollected,
            icon: TaraIcons.package,
            loading: _busy,
            onConfirmed: ready ? _submit : null,
          ),
          Center(
            child: TaraLink(label: l.parcelNotConforming, onPressed: _busy ? null : widget.onRefuse),
          ),
        ],
      ),
      children: [
        CourseStepper(labels: steps, activeIndex: 0, stateLabels: stepStateLabels(l)),
        const SizedBox(height: 14),
        PartyRow(
          name: senderName,
          line: order.pickup.line,
          note: order.instructions,
          callLabel: l.callPerson(senderName),
          // Appels gardés dans le journal : ils prouvent l'attente si l'expéditeur ne vient pas.
          onCall: phone == null ? null : () => ref.read(callJournalProvider).call(order.id, to: 'SENDER', phone: phone),
        ),
        AddressHelp(orderId: order.id, stop: 'pickup', address: order.pickup, name: senderName),
        const SizedBox(height: 12),
        _WaitingBox(
          arrivedAt: _arrivedAt,
          rules: ref.watch(riderConfigProvider).value?.waiting ?? const WaitingRules(),
          now: _now(),
          busy: _arriving,
          onArrive: _busy ? null : _arrive,
          senderCalls: _arrivedAt == null
              ? 0
              : ref
                    .watch(callJournalProvider)
                    .forOrder(order.id)
                    .where((call) => call.to == 'SENDER' && !call.at.isBefore(_arrivedAt!))
                    .length,
          confirmLeave: _confirmLeave,
          leaving: _leaving,
          onLeave: _busy ? null : _leave,
        ),
        // Quel colis prendre : l'expéditeur peut en avoir plusieurs, pour d'autres livreurs.
        const SizedBox(height: 12),
        ParcelCard(order: order, title: l.parcelToCollect),
        if (order.collectAtPickup > 0) ...[
          const SizedBox(height: 12),
          CollectBox(amount: order.collectAtPickup, title: l.collectAtPickupTitle, body: l.collectAtPickupBody),
        ],
        if (order.bulky) ...[
          const SizedBox(height: 12),
          TintBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaraIcon(TaraIcons.package, size: 18, color: TaraColors.of(context).accentText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.loadingHelp ? l.bulkyWithHelpNotice : l.bulkyNotice,
                    style: TaraText.label.copyWith(color: TaraColors.of(context).textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (order.pickup.motorbikeRestricted) ...[const SizedBox(height: 12), CourseWarning(l.noMotoAddress)],
        const SizedBox(height: 14),
        CourseFieldLabel(l.pickupCodeLabel, hint: l.pickupCodeHint),
        const SizedBox(height: 8),
        CodeCells(length: 4, controller: _code, cellHeight: 56, autofocus: false, digitLabel: l.digitLabel),
        const SizedBox(height: 12),
        ProofPhotoTile(
          path: _photoPath,
          takenAt: _photoAt,
          onTake: _busy ? null : _takePhoto,
          title: l.photoParcel,
          hint: switch (order.batchNumber) {
            final number? => l.photoParcelHintNumber(number),
            null => l.photoParcelHint,
          },
          takenLabel: l.photoParcelTaken,
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Attente chez l'expéditeur (D) : « Je suis arrivé » démarre le temps ; au-delà des minutes
/// gratuites, l'expéditeur paie et le livreur reçoit sa part.
class _WaitingBox extends StatelessWidget {
  const _WaitingBox({
    required this.arrivedAt,
    required this.rules,
    required this.now,
    required this.busy,
    required this.onArrive,
    this.senderCalls = 0,
    this.confirmLeave = false,
    this.leaving = false,
    this.onLeave,
  });

  final DateTime? arrivedAt;
  final WaitingRules rules;
  final DateTime now;
  final bool busy;
  final VoidCallback? onArrive;

  /// Appels à l'expéditeur depuis l'arrivée, et le départ sans le colis (D).
  final int senderCalls;
  final bool confirmLeave;
  final bool leaving;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    String f(int amount) => '${formatAmount(amount)}\u00a0F';
    final since = arrivedAt;
    if (since == null) {
      return TintBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.waitingRule(
                rules.freeMinutes,
                f(rules.feePerStep),
                rules.stepMinutes,
                f(rules.riderPart(rules.feePerStep)),
                f(rules.maxFee),
              ),
              style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: busy ? l.arrivedSending : l.arrivedAction,
              icon: TaraIcons.mapPin,
              onPressed: busy ? null : onArrive,
            ),
          ],
        ),
      );
    }
    final waited = now.difference(since);
    final minutes = waited.inMinutes;
    final fee = rules.feeAfter(waited);
    final canLeave = minutes >= rules.maxMinutes;
    final callsLeft = WaitingRules.absentMinCalls - senderCalls;
    return TintBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaraIcon(TaraIcons.clock, size: 18, color: c.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fee == 0
                      ? l.waitingFree(minutes, rules.freeMinutes - minutes < 0 ? 0 : rules.freeMinutes - minutes)
                      : l.waitingPaid(minutes, f(fee), f(rules.riderPart(fee))),
                  style: TaraText.label.copyWith(color: c.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
          if (!canLeave) ...[
            const SizedBox(height: 6),
            Text(
              l.senderAbsentLater(rules.maxMinutes - minutes, f(rules.absentRiderPart)),
              style: TaraText.small.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ] else ...[
            const SizedBox(height: 10),
            if (callsLeft > 0)
              Text(l.senderAbsentCallFirst(callsLeft), style: TaraText.small.copyWith(color: c.textSecondary))
            else if (confirmLeave)
              Text(
                l.senderAbsentConfirm(f(rules.absentFee), f(rules.absentRiderPart)),
                style: TaraText.small.copyWith(color: c.dangerText, height: 1.4),
              ),
            const SizedBox(height: 6),
            GlassButton(
              label: leaving ? l.arrivedSending : l.senderAbsentAction,
              icon: TaraIcons.close,
              onPressed: callsLeft > 0 || leaving ? null : onLeave,
            ),
          ],
        ],
      ),
    );
  }
}
