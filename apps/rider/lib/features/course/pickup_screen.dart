import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/tara_icons.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/step_labels.dart';
import '../map/tara_map.dart';
import 'course_scaffold.dart';

/// 08 · Enlèvement : itinéraire jusqu'au vendeur, montant à encaisser sur place, code de
/// l'expéditeur et photo du colis. « Colis récupéré » passe par la file hors connexion.
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onPickedUp,
    this.now,
  });

  final RiderOrder order;

  /// Retour à l'accueil, la course reste en cours.
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis récupéré : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onPickedUp;

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

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
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
    _code.dispose();
    super.dispose();
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
      footer: PrimaryButton(
        label: l.parcelCollected,
        icon: TaraIcons.check,
        loading: _busy,
        onPressed: ready ? _submit : null,
      ),
      children: [
        CourseStepper(labels: steps, activeIndex: 0, stateLabels: stepStateLabels(l)),
        const SizedBox(height: 14),
        PartyRow(
          name: senderName,
          line: order.pickup.line,
          note: order.instructions,
          callLabel: l.callPerson(senderName),
          onCall: phone == null ? null : () => callPhone(phone),
        ),
        if (order.collectAtPickup > 0) ...[
          const SizedBox(height: 12),
          CollectBox(amount: order.collectAtPickup, title: l.collectAtPickupTitle, body: l.collectAtPickupBody),
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
          hint: l.photoParcelHint,
          takenLabel: l.photoParcelTaken,
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}
