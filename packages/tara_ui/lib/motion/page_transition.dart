import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tara_effects.dart';

/// Transition de page « vitrée » (Android) : la nouvelle page arrive en fondu, grandit
/// à peine et se précise comme derrière un verre qui s'éclaircit ; celle qu'elle couvre
/// recule légèrement. Effets réduits : sans flou ; animations réduites : fondu seul.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _GlassPageTransition(animation: animation, secondaryAnimation: secondaryAnimation, child: child);
}

class _GlassPageTransition extends StatelessWidget {
  const _GlassPageTransition({required this.animation, required this.secondaryAnimation, required this.child});

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  static final _in = Tween<double>(begin: .94, end: 1);
  static final _out = Tween<double>(begin: 1, end: .97);

  @override
  Widget build(BuildContext context) {
    final effects = TaraEffects.of(context);
    final incoming = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    Widget page = FadeTransition(opacity: incoming, child: child);
    if (!effects.decorativeMotion) return page;
    page = ScaleTransition(scale: _in.animate(incoming), child: page);
    if (effects.blur) {
      page = AnimatedBuilder(
        animation: incoming,
        child: page,
        builder: (context, child) {
          final sigma = (1 - incoming.value) * 14;
          return ImageFiltered(
            enabled: sigma > .3,
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          );
        },
      );
    }
    return ScaleTransition(
      scale: _out.animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic)),
      child: page,
    );
  }
}
