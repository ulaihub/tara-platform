import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/dashed.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'documents_controller.dart';
import 'onboarding_header.dart';

/// Prise de la photo d'une pièce (remplacée dans les tests). Photo réduite à 1600 px et
/// compressée : lisible pour la vérification, légère sur un réseau lent.
typedef PickPhoto = Future<String?> Function({required bool selfie});

Future<String?> pickWithCamera({required bool selfie}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 78,
    preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
  );
  return file?.path;
}

/// 04 · Pièces justificatives : liste fournie par l'API, envoi avec progression, pièce
/// refusée avec son motif et « Renvoyer ». Ouvert aussi depuis le profil ([fromProfile]) :
/// mêmes pièces, sans les étapes de l'inscription.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({
    super.key,
    required this.onDone,
    this.onBack,
    this.pickPhoto = pickWithCamera,
    this.fromProfile = false,
  });

  final VoidCallback onDone;
  final VoidCallback? onBack;
  final PickPhoto pickPhoto;
  final bool fromProfile;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -1.05), size: 260, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 1.0), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 6)),
  ];

  Future<void> _take(BuildContext context, WidgetRef ref, String type, bool asksExpiry) async {
    final path = await pickPhoto(selfie: type == 'SELFIE');
    if (path == null || !context.mounted) return;
    DateTime? expiresOn;
    if (asksExpiry) {
      final now = DateTime.now();
      expiresOn = await showDatePicker(
        context: context,
        initialDate: DateTime(now.year + 1, now.month, now.day),
        firstDate: now,
        lastDate: DateTime(now.year + 15),
      );
      if (!context.mounted) return;
    }
    await ref
        .read(documentsControllerProvider.notifier)
        .upload(type, path, expiresOn: expiresOn, describe: (error) => errorMessage(context, error));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final state = ref.watch(documentsControllerProvider);
    final data = state.value;
    final total = data?.requirements.length ?? 0;
    final done = data?.doneCount ?? 0;
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          if (fromProfile)
            Row(
              children: [
                GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: onBack ?? onDone),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.myDocuments, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
                  ),
                ),
                Text(
                  l.progressCount(done, total),
                  style: TaraText.label.copyWith(color: c.accentText, fontWeight: FontWeight.w700),
                ),
              ],
            )
          else ...[
            OnboardingHeader(
              step: 2,
              total: 2,
              name: l.stepDocuments,
              progress: total == 0 ? 0 : done / total,
              trailing: l.progressCount(done, total),
              onBack: onBack,
            ),
            const SizedBox(height: 22),
            Semantics(
              header: true,
              child: Text(l.documentsTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            fromProfile ? l.myDocumentsBody : l.documentsBody,
            style: TaraText.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 18),
          if (data == null && state.hasError) ...[
            ErrorLine(errorMessage(context, state.error!)),
            const SizedBox(height: 12),
            GlassButton(label: l.retry, onPressed: () => ref.invalidate(documentsControllerProvider)),
          ] else if (data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: GooLoader()),
            )
          else
            for (final item in fromProfile ? _actionFirst(data.items) : data.items) ...[
              _DocumentRow(item: item, onTake: (type, asksExpiry) => _take(context, ref, type, asksExpiry)),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          InfoNote(text: l.documentsNote),
        ],
        footer: fromProfile
            ? PrimaryButton(label: l.close, icon: TaraIcons.check, onPressed: onDone)
            : PrimaryButton(
                label: l.sendFile,
                icon: TaraIcons.check,
                onPressed: data != null && data.complete ? onDone : null,
              ),
      ),
    );
  }
}

/// Depuis le profil : les pièces à renvoyer (refusées, expirées, manquantes) d'abord.
List<DocumentItem> _actionFirst(List<DocumentItem> items) {
  bool needsAction(DocumentItem item) =>
      item.status == DocumentStatus.rejected ||
      item.status == DocumentStatus.expired ||
      item.status == DocumentStatus.toDo;
  return [...items.where(needsAction), ...items.where((item) => !needsAction(item))];
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.item, required this.onTake});

  final DocumentItem item;
  final void Function(String type, bool asksExpiry) onTake;

  static TaraIconData _icon(String type) => switch (type) {
    'SELFIE' => TaraIcons.selfie,
    'DRIVING_LICENSE' || 'VEHICLE_REGISTRATION' || 'VEHICLE_RENTAL_CONTRACT' => TaraIcons.license,
    'INSURANCE' || 'CRIMINAL_RECORD' => TaraIcons.shieldCheck,
    _ => TaraIcons.idCard,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final options = item.requirement.options;
    final main = item.main;
    final status = item.status;
    final (statusText, statusColor) = switch (status) {
      DocumentStatus.toDo => (l.docToDo, c.textTertiary),
      DocumentStatus.uploading => (l.docUploading((item.progress * 100).round()), c.accentText),
      DocumentStatus.sent => (l.docSent, c.success),
      DocumentStatus.approved => (l.docApproved, c.success),
      DocumentStatus.rejected => (l.docRejected, c.dangerText),
      DocumentStatus.expired => (l.docExpired, c.dangerText),
    };
    final needsAction =
        status == DocumentStatus.toDo || status == DocumentStatus.rejected || status == DocumentStatus.expired;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: _icon(main.type),
                tone: switch (status) {
                  DocumentStatus.sent || DocumentStatus.approved => TintTone.success,
                  DocumentStatus.rejected || DocumentStatus.expired => TintTone.danger,
                  _ => TintTone.accent,
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      main.label(language),
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TaraText.small.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (needsAction)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 104, maxWidth: 148),
                  child: GlassButton(
                    label: status == DocumentStatus.toDo ? l.takePhoto : l.sendAgain,
                    icon: TaraIcons.camera,
                    height: 48,
                    radius: 14,
                    color: c.accentText,
                    onPressed: () => onTake(main.type, main.asksExpiry),
                  ),
                )
              else if (item.done)
                TaraIcon(TaraIcons.check, size: 22, color: c.success, semanticLabel: statusText),
            ],
          ),
          if (status == DocumentStatus.rejected && item.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Text(item.rejectionReason!, style: TaraText.label.copyWith(color: c.dangerTextStrong)),
          ],
          if (needsAction && options.length > 1) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TaraLink(
                label: l.docAlternative(options[1].label(language)),
                onPressed: () => onTake(options[1].type, options[1].asksExpiry),
              ),
            ),
          ],
          if (item.error != null) ...[const SizedBox(height: 8), ErrorLine(item.error!)],
        ],
      ),
    );
    return Semantics(
      container: true,
      child: switch (status) {
        DocumentStatus.toDo => CustomPaint(
          painter: DashedBorderPainter(color: c.accentTintBorder, radius: 22),
          child: row,
        ),
        DocumentStatus.rejected || DocumentStatus.expired => DecoratedBox(
          decoration: BoxDecoration(
            color: c.dangerTint,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.dangerText.withValues(alpha: .35)),
          ),
          child: row,
        ),
        DocumentStatus.uploading => ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: LiquidFill(
                  level: item.progress,
                  horizontal: true,
                  levelDuration: const Duration(milliseconds: 400),
                  front: LinearGradient(
                    colors: [TaraBrand.amber.withValues(alpha: .42), TaraBrand.orange.withValues(alpha: .32)],
                  ),
                  back: TaraBrand.orange.withValues(alpha: .12),
                ),
              ),
              GlassCard(radius: 22, padding: EdgeInsets.zero, shadow: false, fill: Colors.transparent, child: row),
            ],
          ),
        ),
        _ => GlassCard(radius: 22, padding: EdgeInsets.zero, shadow: false, child: row),
      },
    );
  }
}
