import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/swipe_button.dart';
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
import 'address_help.dart';
import 'course_page.dart';
import 'course_scaffold.dart';
import 'failure_screen.dart' show failureReasonLabel;

/// 11 · Retour du colis : itinéraire jusqu'au vendeur, puis, sur place, le code de retour
/// qu'il a reçu par SMS et la photo du colis rendu. Retour sans dette : les frais sont payés
/// d'avance par le vendeur, rien n'est encaissé à la porte. Le retour passe par la file hors
/// connexion.
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

  void _arrive() => setState(() => _arrived = true);

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
    final code = _code.text;
    final codeDone = code.length == 4;
    final photoDone = _photoPath != null;
    // Étapes de la maquette : la première pas encore faite est « en cours ».
    final done = [_arrived, codeDone, photoDone];
    final current = done.indexWhere((d) => !d);
    var index = 0;
    _ReturnStepState stateOf(int i) => done[i]
        ? _ReturnStepState.done
        : i == current
        ? _ReturnStepState.current
        : _ReturnStepState.todo;
    String time(DateTime at) => '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    final steps = <Widget>[
      _ReturnStep(
        number: ++index,
        state: stateOf(index - 1),
        title: l.returnStepJoin,
        subtitle: [senderName, order.pickup.line].join(' · '),
        action: _arrived ? null : l.arrivedAction,
        onAction: _arrive,
      ),
      // Retour payé d'avance par le vendeur : rien à encaisser (maquette sans étape frais).
      if (_arrived) _ReturnStep(number: 0, state: _ReturnStepState.done, title: l.returnPaidAhead),
      _ReturnStep(
        number: ++index,
        state: stateOf(index - 1),
        title: l.returnStepCode,
        subtitle: codeDone ? l.returnCodeEntered(code.split('').join(' ')) : l.returnCodeHint,
        childVisible: _arrived,
        child: CodeCells(length: 4, controller: _code, cellHeight: 52, autofocus: false, digitLabel: l.digitLabel),
      ),
      _ReturnStep(
        number: ++index,
        state: stateOf(index - 1),
        title: l.photoReturned,
        subtitle: photoDone && _photoAt != null ? l.photoReturnedTaken(time(_photoAt!)) : l.photoReturnedHint,
        action: _arrived ? (photoDone ? l.retakePhoto : l.takePhoto) : null,
        onAction: _busy ? null : _takePhoto,
      ),
    ];

    return CoursePage(
      stop: MapStop(latitude: order.pickup.latitude, longitude: order.pickup.longitude, label: senderName),
      header: CourseHeader(
        kicker: '${l.returnTitle} · ${order.reference}',
        title: senderName,
        subtitle: order.pickup.line,
        onBack: widget.onBack,
        onSos: widget.onSos,
        callLabel: l.callPerson(senderName),
        onCall: phone == null ? null : () => callPhone(phone),
      ),
      // Remise définitive : on glisse (maquette), comme pour « Colis récupéré ».
      footer: SwipeButton(
        plain: true,
        height: 62,
        label: l.slideParcelReturned,
        semanticLabel: l.parcelReturned,
        loading: _busy,
        onConfirmed: ready ? _submit : null,
      ),
      children: [
        if (reason != null) Align(alignment: Alignment.centerLeft, child: _FailureChip(failureReasonLabel(l, reason))),
        AddressHelp(orderId: order.id, stop: 'pickup', address: order.pickup, name: senderName),
        for (final step in steps) ...[const SizedBox(height: 10), step],
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}

enum _ReturnStepState { done, current, todo }

/// Étape du retour (maquette) : pastille numérotée (verte une fois faite), titre, détail ;
/// l'étape en cours est encadrée d'orange et porte son bouton ou sa saisie.
class _ReturnStep extends StatelessWidget {
  const _ReturnStep({
    required this.number,
    required this.state,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.child,
    this.childVisible,
  });

  final int number;
  final _ReturnStepState state;
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final Widget? child;

  /// Saisie visible hors de l'étape en cours (le code se tape dans n'importe quel ordre).
  final bool? childVisible;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final current = state == _ReturnStepState.current;
    final doneStep = state == _ReturnStepState.done;
    final showChild = child != null && (childVisible ?? current);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: current ? const Color.fromRGBO(255, 138, 0, .08) : c.textPrimary.withValues(alpha: .05),
          border: Border.all(
            color: current ? const Color.fromRGBO(255, 138, 0, .45) : c.textPrimary.withValues(alpha: .10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: current ? TaraBrand.gradient : null,
                    color: doneStep ? const Color(0xFF10A06E) : (current ? null : c.textPrimary.withValues(alpha: .10)),
                  ),
                  child: doneStep
                      ? const TaraIcon(TaraIcons.check, size: 15, strokeWidth: 2.6, color: Colors.white)
                      : Text(
                          '$number',
                          style: TaraText.smallStrong.copyWith(
                            color: current ? TaraBrand.onBrand : c.textPrimary.withValues(alpha: .6),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TaraText.text.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: state == _ReturnStepState.todo ? c.textSecondary : c.textPrimary,
                        ),
                      ),
                      if (subtitle case final sub?)
                        Text(
                          sub,
                          style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .66)),
                        ),
                    ],
                  ),
                ),
                if (action case final label?) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onAction,
                    child: Text(
                      label,
                      style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: c.accentText),
                    ),
                  ),
                ],
              ],
            ),
            if (showChild) ...[const SizedBox(height: 10), child!],
          ],
        ),
      ),
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

/// Retour non payé à temps : le colis est déposé au bureau Tara (adresse et horaires du
/// serveur), photo du dépôt à l'appui. Le livreur est payé comme pour un retour.
class OfficeDropScreen extends ConsumerStatefulWidget {
  const OfficeDropScreen({
    super.key,
    required this.order,
    required this.onBack,
    required this.onSos,
    required this.onDropped,
    this.now,
  });

  final RiderOrder order;
  final VoidCallback onBack;
  final VoidCallback onSos;

  /// Colis déposé : envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onDropped;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<OfficeDropScreen> createState() => _OfficeDropScreenState();
}

class _OfficeDropScreenState extends ConsumerState<OfficeDropScreen> {
  bool _arrived = false;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  @override
  void initState() {
    super.initState();
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'office-drop');
    if (refused != null) {
      _arrived = true;
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
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
    if (photo == null) return;
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
    final result = await actions.officeDrop(widget.order, photoPath: photo, at: at, retryActionId: _refusedActionId);
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _refusedActionId = result.actionId;
        _error = result.message ?? l.genericError;
      });
      return;
    }
    widget.onDropped(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final office = order.office;
    final reason = order.failureReason;
    final photoDone = _photoPath != null;
    final done = [_arrived, photoDone];
    final current = done.indexWhere((d) => !d);
    _ReturnStepState stateOf(int i) => done[i]
        ? _ReturnStepState.done
        : i == current
        ? _ReturnStepState.current
        : _ReturnStepState.todo;
    String time(DateTime at) => '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final hours = office?.hoursFor(Localizations.localeOf(context).languageCode);
    return CoursePage(
      stop: MapStop(
        latitude: office?.latitude ?? order.pickup.latitude,
        longitude: office?.longitude ?? order.pickup.longitude,
        label: l.officeDropTitle,
      ),
      header: CourseHeader(
        kicker: '${l.officeDropTitle} · ${order.reference}',
        title: l.officeStepGo,
        subtitle: office?.address ?? '',
        onBack: widget.onBack,
        onSos: widget.onSos,
      ),
      footer: SwipeButton(
        plain: true,
        height: 62,
        label: l.slideOfficeDropped,
        semanticLabel: l.officeDropped,
        loading: _busy,
        onConfirmed: photoDone ? _submit : null,
      ),
      children: [
        if (reason != null) Align(alignment: Alignment.centerLeft, child: _FailureChip(failureReasonLabel(l, reason))),
        const SizedBox(height: 8),
        Text(l.officeDropWhy, style: TaraText.small.copyWith(color: c.textSecondary, height: 1.4)),
        const SizedBox(height: 10),
        _ReturnStep(
          number: 1,
          state: stateOf(0),
          title: l.officeStepGo,
          subtitle: [?office?.address, ?hours].join(' · '),
          action: _arrived ? null : l.arrivedAction,
          onAction: () => setState(() => _arrived = true),
        ),
        const SizedBox(height: 10),
        _ReturnStep(
          number: 2,
          state: stateOf(1),
          title: l.officeStepPhoto,
          subtitle: photoDone && _photoAt != null ? l.officeStepPhotoTaken(time(_photoAt!)) : l.officeStepPhotoHint,
          action: _arrived ? (photoDone ? l.retakePhoto : l.takePhoto) : null,
          onAction: _busy ? null : _takePhoto,
        ),
        if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        const SizedBox(height: 12),
      ],
    );
  }
}
