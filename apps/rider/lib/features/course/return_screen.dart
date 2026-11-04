import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../map/tara_map.dart';
import 'course_scaffold.dart';
import 'failure_screen.dart' show failureReasonLabel;

/// 11 · Retour du colis : itinéraire jusqu'au vendeur, puis, sur place, le code de retour
/// qu'il a reçu par SMS et la photo du colis rendu. Passe par la file hors connexion.
class ReturnScreen extends ConsumerStatefulWidget {
  const ReturnScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onReturned,
    this.now,
  });

  final RiderOrder order;
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis rendu : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onReturned;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  final _code = TextEditingController();
  bool _arrived = false;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'return');
    if (refused != null) {
      _arrived = true;
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
    final result = await actions.returnToSender(
      widget.order,
      code: _code.text,
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
    widget.onReturned(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final senderName = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final phone = order.sender.phone ?? order.pickup.contactPhone;
    final reason = order.failureReason;
    final ready = _photoPath != null && _code.text.length == 4;
    final step = !_arrived ? 0 : (_code.text.length == 4 ? 2 : 1);

    return CourseScaffold(
      order: order,
      stop: MapStop(latitude: order.pickup.latitude, longitude: order.pickup.longitude, label: senderName),
      title: (route, _) => route?.minutes == null ? l.returnTitle : l.returnMinutes(route!.minutes!),
      onBack: widget.onBack,
      onSos: widget.onSos,
      footer: _arrived
          ? PrimaryButton(
              label: l.parcelReturned,
              icon: TaraIcons.check,
              loading: _busy,
              onPressed: ready ? _submit : null,
            )
          : PrimaryButton(label: l.atSender, icon: TaraIcons.mapPin, onPressed: () => setState(() => _arrived = true)),
      children: [
        if (reason != null) Align(alignment: Alignment.centerLeft, child: _FailureChip(failureReasonLabel(l, reason))),
        const SizedBox(height: 12),
        CourseFieldLabel(l.returnTo),
        const SizedBox(height: 8),
        PartyRow(
          name: senderName,
          line: order.pickup.line,
          callLabel: l.callPerson(senderName),
          onCall: phone == null ? null : () => callPhone(phone),
        ),
        const SizedBox(height: 14),
        _ReturnSteps(
          labels: [l.returnStepJoin, l.returnStepCode, l.returnStepPhoto],
          active: step,
          inProgress: l.stepInProgress,
        ),
        if (_arrived) ...[
          const SizedBox(height: 14),
          CourseFieldLabel(l.returnCodeLabel, hint: l.returnCodeHint),
          const SizedBox(height: 8),
          CodeCells(length: 4, controller: _code, cellHeight: 56, autofocus: false, digitLabel: l.digitLabel),
          const SizedBox(height: 12),
          ProofPhotoTile(
            path: _photoPath,
            takenAt: _photoAt,
            onTake: _busy ? null : _takePhoto,
            title: l.photoReturned,
            hint: l.photoReturnedHint,
            takenLabel: l.photoReturnedTaken,
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Pastille « Échec · Client absent ».
class _FailureChip extends StatelessWidget {
  const _FailureChip(this.reason);
  final String reason;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.dangerText.withValues(alpha: .35)),
      ),
      child: Text(
        AppLocalizations.of(context).failureChip(reason),
        style: TaraText.smallStrong.copyWith(color: c.dangerTextStrong),
      ),
    );
  }
}

/// Étapes du retour : rejoindre le vendeur, code de retour, photo du colis rendu.
class _ReturnSteps extends StatelessWidget {
  const _ReturnSteps({required this.labels, required this.active, required this.inProgress});
  final List<String> labels;
  final int active;
  final String inProgress;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == labels.length - 1 ? 0 : 10),
            child: MergeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i == active ? TaraBrand.gradient : null,
                      color: i < active ? c.successTintBg : (i > active ? c.chipBg : null),
                      border: i > active ? Border.all(color: c.chipBorder) : null,
                    ),
                    child: i < active
                        ? TaraIcon(TaraIcons.check, size: 16, color: c.success)
                        : Text(
                            '${i + 1}',
                            style: TaraText.smallStrong.copyWith(
                              color: i == active ? TaraBrand.onBrand : c.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      labels[i],
                      style: TaraText.text.copyWith(
                        color: i <= active ? c.textPrimary : c.textSecondary,
                        fontWeight: i == active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (i == active) Text(inProgress, style: TaraText.smallStrong.copyWith(color: c.accentText)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
