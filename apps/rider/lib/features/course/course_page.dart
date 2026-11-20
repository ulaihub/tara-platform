import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../map/tara_map.dart';

// Cadre des écrans de course de la refonte (maquette Livreur-Enlevement) : la carte en
// haut (250 px) qui s'efface vers le fond, l'en-tête par-dessus (retour, étape, nom,
// appel, SOS), puis des cartes empilées qui défilent et l'action en bas.

/// Écran de course : carte du haut, en-tête, cartes, pied fixe.
class CoursePage extends ConsumerWidget {
  const CoursePage({super.key, required this.stop, required this.header, required this.children, required this.footer});

  final MapStop stop;
  final CourseHeader header;
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = TaraColors.of(context);
    final online = ref.watch(onlineControllerProvider);
    final insets = MediaQuery.paddingOf(context);
    return Material(
      color: c.bg,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 250 + insets.top,
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListenableBuilder(
                    listenable: online,
                    builder: (context, _) => TaraMap(
                      rider: online.lastPosition,
                      stop: stop,
                      framePadding: EdgeInsets.fromLTRB(60, 90 + insets.top, 60, 60),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.bg.withValues(alpha: .55), c.bg.withValues(alpha: 0), c.bg],
                        stops: const [0, .35, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: header),
                Expanded(
                  // Peu de cartes : toutes construites d'un coup (pas de liste paresseuse).
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), child],
                      ],
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + insets.bottom), child: footer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête : retour carré, étape en petites capitales orange, nom, détail, appel et SOS.
class CourseHeader extends StatelessWidget {
  const CourseHeader({
    super.key,
    required this.kicker,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.onSos,
    this.onCall,
    this.callLabel,
  });

  final String kicker;
  final String title;
  final String subtitle;

  /// null : pas de retour (premier écran d'un parcours).
  final VoidCallback? onBack;

  /// null : pas de SOS (écrans ouverts par-dessus une course qui l'affiche déjà).
  final VoidCallback? onSos;
  final VoidCallback? onCall;
  final String? callLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    return Row(
      children: [
        if (onBack != null) ...[
          Semantics(
            button: true,
            label: l.back,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: c.textPrimary.withValues(alpha: .07),
                  border: Border.all(color: c.textPrimary.withValues(alpha: .12)),
                ),
                alignment: Alignment.center,
                child: TaraIcon(TaraIcons.chevronLeft, size: 22, color: c.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: c.accentText,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TaraText.sora,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .70)),
                ),
              ],
            ),
          ),
        ),
        if (onCall != null) ...[
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: callLabel,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onCall,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.textPrimary.withValues(alpha: .08),
                  border: Border.all(color: c.textPrimary.withValues(alpha: .14)),
                ),
                alignment: Alignment.center,
                child: TaraIcon(TaraIcons.phone, size: 20, color: ok),
              ),
            ),
          ),
        ],
        // L'alerte reste à portée pendant toute la course.
        if (onSos != null) ...[
          const SizedBox(width: 8),
          SosButton(label: l.safetyAlert, onPressed: onSos, size: 44, round: true),
        ],
      ],
    );
  }
}

/// Carte des écrans de course (`--card`) : verre léger, bord fin, coins de 22 px.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.child, this.tint, this.border, this.onTap});

  final Widget child;
  final Color? tint;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color:
                tint ??
                (c.isDark ? const Color.fromRGBO(255, 255, 255, .06) : const Color.fromRGBO(255, 255, 255, .84)),
            border: Border.all(
              color: border ?? (c.isDark ? const Color.fromRGBO(255, 255, 255, .10) : const Color(0xFFFFFFFF)),
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
    );
  }
}

/// Photo de preuve (maquette) : à prendre (bord orange, appareil), puis prise (bord vert,
/// colis 3D qui tourne, heure). Toute la carte reprend la photo.
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.taken,
    required this.takenAt,
    required this.title,
    required this.takenTitle,
    required this.hint,
    required this.onTake,
  });

  final String title;

  /// « Photo du colis · prise à 14:48 ».
  final String Function(String time) takenTitle;

  final bool taken;
  final DateTime? takenAt;
  final String hint;
  final VoidCallback? onTake;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final at = takenAt;
    final time = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return CourseCard(
      onTap: onTake,
      tint: taken ? const Color.fromRGBO(74, 222, 155, .08) : c.textPrimary.withValues(alpha: .06),
      border: taken ? const Color.fromRGBO(74, 222, 155, .35) : const Color.fromRGBO(255, 177, 92, .45),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: c.textPrimary.withValues(alpha: .07),
            ),
            alignment: Alignment.center,
            child: taken
                ? const Parcel3D(size: 26, floating: false, period: Duration(seconds: 6))
                : TaraIcon(TaraIcons.camera, size: 24, color: c.accentText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taken ? takenTitle(time) : title,
                  style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(hint, style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .68))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            taken ? l.retakePhoto : l.takePhoto,
            style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: c.accentText),
          ),
        ],
      ),
    );
  }
}
