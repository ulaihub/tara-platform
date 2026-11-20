import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/course_actions.dart';
import '../../core/course/proof_photo.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'course_page.dart';
import 'course_scaffold.dart';

/// Raisons de refuser un colis à l'enlèvement, dans l'ordre d'affichage.
const parcelRefusalReasons = ['TOO_BIG', 'TOO_HEAVY', 'NOT_AS_DECLARED', 'FORBIDDEN_ITEM'];

String parcelRefusalLabel(AppLocalizations l, String reason) => switch (reason) {
  'TOO_BIG' => l.refusalTooBig,
  'TOO_HEAVY' => l.refusalTooHeavy,
  'FORBIDDEN_ITEM' => l.refusalForbidden,
  _ => l.refusalNotAsDeclared,
};

/// Colis non conforme : à l'enlèvement, avant de prendre le colis, le livreur le refuse
/// avec un motif et une photo (preuve pour l'expéditeur et le support). La course est
/// annulée et son déplacement lui est payé. Le refus part par la file hors connexion.
class RefuseParcelScreen extends ConsumerStatefulWidget {
  const RefuseParcelScreen({super.key, required this.order, required this.onBack, required this.onDone, this.now});

  final RiderOrder order;
  final VoidCallback onBack;

  /// Refus envoyé (sent) ou gardé sur le téléphone (queued).
  final void Function(ActionOutcome outcome) onDone;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<RefuseParcelScreen> createState() => _RefuseParcelScreenState();
}

class _RefuseParcelScreenState extends ConsumerState<RefuseParcelScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  final _note = TextEditingController();
  String? _reason;
  String? _photoPath;
  DateTime? _photoAt;
  bool _busy = false;
  String? _error;
  String? _refusedActionId;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() => _error = null));
    // Refus rejeté par le serveur resté dans la file (écran rouvert) : on reprend où il en était.
    final refused = ref.read(courseActionsProvider).refused(widget.order.id, CourseActions.refuseParcelKind);
    if (refused != null) {
      _refusedActionId = refused.id;
      _error = refused.failureMessage;
      _photoPath = refused.photoPath;
      _photoAt = refused.createdAt;
      _reason = refused.body['reason'] as String?;
      _note.text = refused.body['note'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _note.dispose();
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
    final reason = _reason;
    if (photo == null || reason == null) return;
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
    final note = _note.text.trim();
    final result = await actions.refuseParcel(
      widget.order,
      reason: reason,
      note: note.isEmpty ? null : note,
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
    final senderName = order.sender.name ?? order.pickup.contactName ?? order.reference;
    final ready = _photoPath != null && _reason != null;

    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          CourseHeader(
            kicker: l.refusalTitle,

            title: senderName,

            subtitle: [?order.pickup.neighborhood, order.reference].join(' · '),

            onBack: _busy ? () {} : widget.onBack,
          ),
          const SizedBox(height: 10),
          Text(l.refusalBody, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
          CourseFieldLabel(l.refusalReasonLabel),
          const SizedBox(height: 8),
          ChoiceChips<String>(
            options: [for (final reason in parcelRefusalReasons) ChoiceOption(reason, parcelRefusalLabel(l, reason))],
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
          const SizedBox(height: 12),
          TaraTextField(
            label: l.refusalNoteLabel,
            hint: l.refusalNoteHint,
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
          ),
          const SizedBox(height: 12),
          ProofPhotoTile(
            path: _photoPath,
            takenAt: _photoAt,
            onTake: _busy ? null : _takePhoto,
            title: l.photoParcel,
            hint: l.refusalPhotoHint,
            takenLabel: l.photoParcelTaken,
          ),
          const SizedBox(height: 12),
          TintBox(
            child: Text(l.refusalNotice, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: PrimaryButton(
          label: l.refusalConfirm,
          icon: TaraIcons.close,
          loading: _busy,
          onPressed: ready ? _submit : null,
        ),
      ),
    );
  }
}
