import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../core/media/address_media.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'order_draft.dart';
import 'package_step.dart' show contentsText;

/// Carte « Photographier le colis » (tests).
const parcelPhotoKey = ValueKey('parcel-photo');

/// Photo du colis (facultative) en tête de l'étape Colis : envoyée, analysée, et la
/// proposition (taille, nature, fragilité, précision) remplit le formulaire, que
/// l'expéditeur vérifie. Un objet interdit vu sur la photo est signalé sans bloquer.
class ParcelPhotoCard extends ConsumerStatefulWidget {
  const ParcelPhotoCard({super.key, required this.delivery, required this.onAnalyzed, required this.onPhoto});

  final DeliveryDraft delivery;

  /// Proposition reçue : à appliquer au formulaire.
  final ValueChanged<ParcelAnalysis> onAnalyzed;

  /// Photo prise et envoyée (clé), ou retirée (null).
  final void Function(String? path, String? key) onPhoto;

  @override
  ConsumerState<ParcelPhotoCard> createState() => _ParcelPhotoCardState();
}

class _ParcelPhotoCardState extends ConsumerState<ParcelPhotoCard> {
  bool _busy = false;
  String? _error;

  Future<void> _take() async {
    setState(() => _error = null);
    String? path;
    try {
      path = await ref.read(takeParcelPhotoProvider)();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
      return;
    }
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    widget.onPhoto(path, null);
    final api = ref.read(clientApiProvider);
    try {
      final key = await api.uploadMedia(path, 'PARCEL_PHOTO', mimeType: 'image/jpeg');
      if (!mounted) return;
      widget.onPhoto(path, key);
      final analysis = await api.analyzeParcel(key);
      if (!mounted) return;
      widget.onAnalyzed(analysis);
    } catch (error) {
      // Photo gardée si elle est partie ; l'expéditeur choisit lui-même taille et nature.
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final d = widget.delivery;
    final path = d.parcelPhotoPath;
    final analysis = d.parcelAnalysis;
    final (title, body) = switch ((path, analysis)) {
      (null, _) => (l.parcelPhotoTitle, l.parcelPhotoBody),
      _ when _busy => (l.parcelPhotoAnalyzing, l.parcelPhotoAnalyzingBody),
      (_, final a?) when !a.isParcel => (l.parcelPhotoNotParcel, l.parcelPhotoNotParcelBody),
      (_, final a?) => (l.parcelPhotoApplied, l.parcelPhotoAppliedBody(_summary(l, a))),
      _ => (l.parcelPhotoAttached, l.parcelPhotoAttachedBody),
    };
    final ink = switch ((path, analysis)) {
      _ when _busy => c.accentText,
      (_, final a?) when a.isParcel => c.success,
      _ => c.textTertiary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toute la carte prend la photo (maquette) ; le liquide monte pendant l'analyse.
        Semantics(
          button: true,
          liveRegion: true,
          label: '$title. $body',
          hint: path == null ? l.takePhoto : l.retake,
          excludeSemantics: true,
          child: Squish(
            enabled: !_busy,
            child: GestureDetector(
              key: parcelPhotoKey,
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : () => unawaited(_take()),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: boxedFieldFill(c),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: boxedFieldBorder(c)),
                  boxShadow: const [
                    BoxShadow(color: Color.fromRGBO(140, 70, 10, .08), blurRadius: 28, offset: Offset(0, 12)),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (path == null)
                              const ColoredBox(color: Color.fromRGBO(255, 177, 92, .12))
                            else
                              Image.file(File(path), fit: BoxFit.cover, cacheWidth: 150),
                            if (_busy)
                              const LiquidFill(
                                level: .55,
                                amplitude: 4,
                                front: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                                  stops: [0, .18, .5],
                                ),
                                back: Color.fromRGBO(255, 61, 0, .5),
                              ),
                            if (path == null || _busy)
                              Center(
                                child: TaraIcon(
                                  TaraIcons.camera,
                                  size: 24,
                                  color: _busy ? TaraBrand.onBrand : c.accentText,
                                ),
                              ),
                          ],
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
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(body, style: TaraText.small.copyWith(color: ink, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (analysis != null && analysis.prohibited.isNotEmpty) ...[
          const SizedBox(height: 8),
          TintBox(
            tone: TintTone.danger,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaraIcon(TaraIcons.alertCircle, size: 18, color: c.dangerText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.parcelPhotoProhibited(analysis.prohibited.join(', ')),
                    style: TaraText.label.copyWith(color: c.dangerText, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: 6), ErrorLine(_error!)],
      ],
    );
  }
}

String _summary(AppLocalizations l, ParcelAnalysis a) => [
  if (a.size == 'BULKY') l.sizeBulky else l.sizeShort(a.size),
  contentsText(l, a.contents),
  if (a.fragile) l.fragileTitle,
].join(' · ');
