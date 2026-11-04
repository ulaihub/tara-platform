import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../design/components/buttons.dart';
import '../../design/components/inputs.dart';
import '../../design/components/progress.dart';
import '../../design/format.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../map/tara_map.dart';
import 'course_scaffold.dart';

/// Au-delà, le livreur est prévenu que sa livraison sera signalée au support.
const farFromAddressMeters = 200;

/// Arrivé : à moins de cette distance de l'adresse.
const arrivedMeters = 150;

/// 09 · Livraison : itinéraire jusqu'au client, argent à encaisser à la remise, code du
/// destinataire ou livraison sans code (nom de la personne qui reçoit, le support appelle le
/// client), photo de remise. Avec de l'argent à encaisser, l'encaissement (12) vient avant
/// l'envoi de la livraison (décision : encaisser puis livrer).
class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onDelivered,
    required this.onCollect,
    this.now,
  });

  final RiderOrder order;
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Livraison envoyée (sent) ou gardée sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onDelivered;

  /// Argent à encaisser d'abord : ouvre l'encaissement (12).
  final VoidCallback onCollect;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final _code = TextEditingController();
  final _receivedBy = TextEditingController();
  bool _withCode = true;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  @override
  void initState() {
    super.initState();
    void clearError() => setState(() => _error = null);
    _code.addListener(clearError);
    _receivedBy.addListener(clearError);
    // Livraison refusée restée dans la file (code faux saisi hors réseau) : on la reprend.
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'deliver');
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
      _withCode = refused.body.containsKey('deliveryCode');
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _receivedBy.dispose();
    super.dispose();
  }

  bool get _ready => _photoPath != null && (_withCode ? _code.text.length == 4 : _receivedBy.text.trim().length >= 2);

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
    if (photo == null || !_ready) return;
    // Argent à encaisser : l'encaissement d'abord, la livraison partira ensuite.
    if (widget.order.collectAtDelivery > 0) {
      widget.onCollect();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final actions = ref.read(courseActionsProvider);
    final at = await actions.position();
    if (!mounted) return;
    if (at == null) {
      setState(() {
        _busy = false;
        _error = l.noPositionYet;
      });
      return;
    }
    final result = await actions.deliver(
      widget.order,
      code: _withCode ? _code.text : null,
      receivedBy: _withCode ? null : _receivedBy.text.trim(),
      photoPath: photo,
      at: at,
      retryActionId: _refusedActionId,
    );
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _refusedActionId = result.actionId;
        _error = result.message ?? l.genericError;
        _code.clear();
      });
      return;
    }
    widget.onDelivered(result.outcome);
  }

  void _toggleMode() => setState(() {
    _withCode = !_withCode;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final due = order.collectAtDelivery > 0;
    final steps = [l.stepPickup, if (due) l.stepCollect, l.stepDelivery];
    final name = order.recipient.name ?? order.dropoff.contactName ?? order.reference;
    final phone = order.recipient.phone ?? order.dropoff.contactPhone;
    final online = ref.watch(onlineControllerProvider);

    return CourseScaffold(
      order: order,
      stop: MapStop(latitude: order.dropoff.latitude, longitude: order.dropoff.longitude, dropoff: true, label: name),
      title: (route, distance) {
        if (distance != null && distance <= arrivedMeters) return l.arrivedAtDestination;
        final minutes = route?.minutes;
        return minutes == null ? l.toDropoff : l.toDropoffMinutes(minutes);
      },
      onBack: widget.onBack,
      onSos: widget.onSos,
      panelRatio: .70,
      footer: PrimaryButton(
        label: l.confirmDelivery,
        icon: TaraIcons.check,
        loading: _busy,
        onPressed: _ready ? _submit : null,
      ),
      children: [
        // Enlèvement fait ; étape en cours : l'encaissement s'il y en a, sinon la livraison.
        CourseStepper(labels: steps, activeIndex: 1),
        const SizedBox(height: 14),
        PartyRow(
          name: name,
          line: order.dropoff.line,
          callLabel: l.callPerson(name),
          onCall: phone == null ? null : () => callPhone(phone),
        ),
        if (due) ...[
          const SizedBox(height: 12),
          CollectBox(amount: order.collectAtDelivery, title: l.collectAtDeliveryTitle, body: l.collectAtDeliveryBody),
        ],
        // Loin de l'adresse : la livraison confirmée d'ici sera signalée au support.
        ListenableBuilder(
          listenable: online,
          builder: (context, _) {
            final here = online.lastPosition;
            final meters = here == null
                ? null
                : courseDistance(here.latitude, here.longitude, order.dropoff.latitude, order.dropoff.longitude);
            if (meters == null || meters <= farFromAddressMeters) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CourseWarning(l.farFromAddress(formatDistance(meters.round()))),
            );
          },
        ),
        if (order.dropoff.motorbikeRestricted) ...[const SizedBox(height: 12), CourseWarning(l.noMotoAddress)],
        const SizedBox(height: 14),
        if (_withCode) ...[
          CourseFieldLabel(l.deliveryCodeLabel, hint: l.deliveryCodeHint),
          const SizedBox(height: 8),
          CodeCells(length: 4, controller: _code, cellHeight: 56, autofocus: false, digitLabel: l.digitLabel),
          TaraLink(label: l.noCodeLink, onPressed: _busy ? null : _toggleMode),
        ] else ...[
          Text(
            l.noCodeTitle,
            style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l.noCodeBody,
            style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TaraTextField(
            label: l.receivedByLabel,
            hint: l.receivedByHint,
            controller: _receivedBy,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
          ),
          TaraLink(label: l.hasCodeLink, onPressed: _busy ? null : _toggleMode),
        ],
        const SizedBox(height: 4),
        ProofPhotoTile(
          path: _photoPath,
          takenAt: _photoAt,
          onTake: _busy ? null : _takePhoto,
          title: l.photoHandover,
          hint: l.photoHandoverHint,
          takenLabel: l.photoHandoverTaken,
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}
