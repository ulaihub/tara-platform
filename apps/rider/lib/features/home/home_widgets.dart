import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

// Petits éléments communs aux accueils du livreur (maquettes Livreur-Hors-Ligne et
// Livreur-En-Ligne) : avatar dégradé, pastille d'état, carte en verre, boutons compacts.

/// Avatar rond aux initiales, en dégradé de marque (46 px).
class RiderAvatar extends StatelessWidget {
  const RiderAvatar({super.key, required this.name, this.size = 46});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: TaraBrand.gradient),
        alignment: Alignment.center,
        child: Text(
          InitialsAvatar.initials(name),
          style: TextStyle(
            fontFamily: TaraText.sora,
            fontWeight: FontWeight.w800,
            fontSize: size * 16 / 46,
            color: const Color(0xFF140800),
          ),
        ),
      ),
    );
  }
}

/// Pastille « Hors ligne » (point gris) ou « En ligne · 1 h 12 » (vert, point qui clignote).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.online = false});

  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    final dot = online
        ? MotionBuilder(
            period: const Duration(milliseconds: 1600),
            stillPhase: 0,
            builder: (context, t, _) => Opacity(
              opacity: 1 - .65 * (1 - (t * 2 - 1).abs()),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: ok, shape: BoxShape.circle),
              ),
            ),
          )
        : Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.textPrimary.withValues(alpha: .45), shape: BoxShape.circle),
          );
    return Container(
      padding: online
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: online ? const Color.fromRGBO(14, 127, 87, .22) : c.textPrimary.withValues(alpha: .08),
        border: Border.all(
          color: online ? const Color.fromRGBO(74, 222, 155, .45) : c.textPrimary.withValues(alpha: .14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          SizedBox(width: online ? 8 : 7),
          Text(
            label,
            style: TaraText.label.copyWith(
              fontSize: online ? 13 : 12,
              fontWeight: FontWeight.w800,
              color: online ? ok : c.textPrimary.withValues(alpha: .80),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de l'accueil (`--card`) : verre léger flouté, bord fin, coins de 22 px.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 22});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: c.isDark ? const Color.fromRGBO(255, 255, 255, .06) : const Color.fromRGBO(255, 255, 255, .84),
            border: Border.all(color: c.isDark ? const Color.fromRGBO(255, 255, 255, .10) : const Color(0xFFFFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Bouton compact (44 px, coins de 14) : dégradé de marque ou verre discret.
class CompactButton extends StatelessWidget {
  const CompactButton({super.key, required this.label, required this.onPressed, this.brand = true});

  final String label;
  final VoidCallback? onPressed;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: brand ? TaraBrand.gradient : null,
            color: brand ? null : c.textPrimary.withValues(alpha: .08),
            border: brand ? null : Border.all(color: c.textPrimary.withValues(alpha: .14)),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TaraText.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: brand ? const Color(0xFF140800) : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
