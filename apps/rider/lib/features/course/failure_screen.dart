import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/call_journal.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'course_page.dart';
import 'course_scaffold.dart';

/// Motifs d'échec, dans l'ordre de la maquette (10).
const failureReasons = [
  'RECIPIENT_ABSENT',
  'RECIPIENT_UNREACHABLE',
  'ADDRESS_NOT_FOUND',
  'REFUSED',
  'DAMAGED',
  'PAYMENT_REFUSED',
  'OTHER',
];

String failureReasonLabel(AppLocalizations l, String reason) => switch (reason) {
  'RECIPIENT_ABSENT' => l.reasonRecipientAbsent,
  'RECIPIENT_UNREACHABLE' => l.reasonRecipientUnreachable,
  'ADDRESS_NOT_FOUND' => l.reasonAddressNotFound,
  'REFUSED' => l.reasonRefused,
  'PAYMENT_REFUSED' => l.reasonPaymentRefused,
  'DAMAGED' => l.reasonDamaged,
  _ => l.reasonOther,
};

/// 10 · Livraison impossible : motif, appels au destinataire passés depuis l'app (exigés
/// selon le motif), photo du lieu. L'échec part par la file hors connexion ; l'expéditeur
/// choisit ensuite nouvelle tentative ou retour.
class FailureScreen extends ConsumerStatefulWidget {
  const FailureScreen({super.key, required this.order, required this.onBack, required this.onDone, this.now});

  final RiderOrder order;
  final VoidCallback onBack;

  /// Échec envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onDone;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<FailureScreen> createState() => _FailureScreenState();
}

class _FailureScreenState extends ConsumerState<FailureScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  final _note = TextEditingController();
  String _reason = failureReasons.first;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  /// Rafraîchit l'écran quand le prochain appel devient possible.
  Timer? _ready;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() => _error = null));
    unawaited(ref.read(callJournalProvider).load());
    // Échec refusé resté dans la file (écran rouvert) : on reprend où il en était.
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, 'fail');
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
      _reason = refused.body['reason'] as String? ?? _reason;
      _note.text = refused.body['note'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _ready?.cancel();
    _note.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final path = await ref.read(takeProofPhotoProvider)();
    if (path == null || !mounted) return;
    setState(() {
      _photoPath = path;
      _photoAt = _now();
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
    final policy = ref.read(riderConfigProvider).value?.failurePolicy ?? const FailurePolicy();
    final note = _note.text.trim();
    final result = await actions.fail(
      widget.order,
      reason: _reason,
      note: note.isEmpty ? null : note,
      callLog: [for (final call in ref.read(callJournalProvider).forOrder(widget.order.id)) call.toApi()],
      photoPath: photo,
      at: at,
      decisionTimeout: policy.decisionTimeout,
      retryActionId: _refusedActionId,
    );
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) {
      setState(() {
        _busy = false;
        _refusedActionId = result.actionId;
        _error = result.message ?? l.genericError;
      });
      return;
    }
    widget.onDone(result.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = widget.order;
    final name = order.recipient.name ?? order.dropoff.contactName ?? order.reference;
    final phone = order.recipient.phone ?? order.dropoff.contactPhone;
    final config = ref.watch(riderConfigProvider).value;
    final policy = config?.failurePolicy ?? const FailurePolicy();
    final support = config?.supportPhone ?? config?.safetyHotline;
    final journal = ref.watch(callJournalProvider);

    return ListenableBuilder(
      listenable: journal,
      builder: (context, _) {
        final calls = journal.forOrder(order.id).where((call) => call.to == 'RECIPIENT').toList();
        final required = policy.callsRequired(_reason);
        final progress = policy.progress(_reason, journal.recipientCalls(order.id));
        final now = _now();
        final waitUntil = progress.readyAt;
        // Prochain appel pas encore possible : l'écran se remet à jour à l'heure dite.
        _ready?.cancel();
        if (waitUntil != null && waitUntil.isAfter(now)) {
          _ready = Timer(waitUntil.difference(now), () {
            if (mounted) setState(() {});
          });
        }
        final noteOk = _reason != 'OTHER' || _note.text.trim().isNotEmpty;
        final ready = _photoPath != null && progress.missing == 0 && noteOk;

        return TaraScreen(
          safeBottom: false,
          blobs: _blobs,
          child: ScrollWithFooter(
            horizontal: 20,
            top: 8,
            content: [
              CourseHeader(
                kicker: l.failureTitle,

                title: name,

                subtitle: [?order.dropoff.neighborhood, order.reference].join(' · '),

                onBack: _busy ? () {} : widget.onBack,
              ),
              const SizedBox(height: 18),
              CourseFieldLabel(l.failureReasonLabel),
              const SizedBox(height: 8),
              ChoiceChips<String>(
                options: [for (final reason in failureReasons) ChoiceOption(reason, failureReasonLabel(l, reason))],
                selected: _reason,
                onSelected: (reason) {
                  if (!_busy) {
                    setState(() {
                      _reason = reason;
                      _error = null;
                    });
                  }
                },
              ),
              if (_reason == 'DAMAGED') ...[
                const SizedBox(height: 12),
                TintBox(
                  tone: TintTone.accent,
                  child: Text(l.damagedNotice, style: TaraText.label.copyWith(color: c.textPrimary, height: 1.4)),
                ),
              ],
              if (_reason == 'OTHER' || _reason == 'DAMAGED') ...[
                const SizedBox(height: 12),
                TaraTextField(
                  label: l.failureNoteLabel,
                  hint: _reason == 'DAMAGED' ? l.damagedNoteHint : l.failureNoteHint,
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
              const SizedBox(height: 14),
              _CallsCard(
                calls: calls,
                required: required,
                missing: progress.missing,
                waitUntil: waitUntil != null && waitUntil.isAfter(now) ? waitUntil : null,
                onCall: phone == null ? null : () => unawaited(journal.call(order.id, to: 'RECIPIENT', phone: phone)),
                onSupport: support == null ? null : () => unawaited(callPhone(support)),
              ),
              const SizedBox(height: 12),
              ProofPhotoTile(
                path: _photoPath,
                takenAt: _photoAt,
                onTake: _busy ? null : _takePhoto,
                title: _reason == 'DAMAGED' ? l.photoDamaged : l.photoPlace,
                hint: _reason == 'DAMAGED' ? l.photoDamagedHint : l.photoPlaceHint,
                takenLabel: l.photoPlaceTaken,
              ),
              const SizedBox(height: 12),
              TintBox(
                child: Text(
                  l.failureNotice(policy.decisionTimeout.inMinutes),
                  style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
            ],
            footer: PrimaryButton(
              label: l.validateFailure,
              icon: TaraIcons.check,
              loading: _busy,
              onPressed: ready ? _submit : null,
            ),
          ),
        );
      },
    );
  }
}

/// Appels au destinataire passés depuis l'app (preuve d'appel), rappel et support.
class _CallsCard extends StatelessWidget {
  const _CallsCard({
    required this.calls,
    required this.required,
    required this.missing,
    required this.waitUntil,
    required this.onCall,
    required this.onSupport,
  });

  final List<CallEntry> calls;
  final int required;
  final int missing;
  final DateTime? waitUntil;
  final VoidCallback? onCall;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final status = required == 0
        ? l.callsNotRequired
        : missing == 0
        ? l.callsDone
        : waitUntil != null
        ? l.callsMissingAt(formatClock(waitUntil!))
        : l.callsMissing(missing);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.callsTitle,
                  style: TaraText.text.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
              ),
              Text(l.callsCount(calls.length), style: TaraText.small.copyWith(color: c.textSecondary)),
            ],
          ),
          for (final call in calls.reversed) ...[
            const SizedBox(height: 10),
            MergeSemantics(
              child: Row(
                children: [
                  // Le téléphone ne dit pas si l'appel a abouti : icône neutre.
                  TaraIcon(TaraIcons.phone, size: 18, color: c.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.callMade, style: TaraText.label.copyWith(color: c.textPrimary)),
                  ),
                  Text(
                    l.callMeta(
                      formatClock(call.at),
                      call.durationSeconds == null ? '…' : formatCountdown(Duration(seconds: call.durationSeconds!)),
                    ),
                    style: TaraText.small.copyWith(color: c.textSecondary, fontFeatures: TaraText.tabular),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: TaraText.label.copyWith(
                color: required == 0 || missing == 0 ? c.success : c.warningText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: calls.isEmpty ? l.callRecipient : l.callAgain,
                  icon: TaraIcons.phone,
                  color: c.success,
                  onPressed: onCall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(label: l.sosCallTara, icon: TaraIcons.headset, onPressed: onSupport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
