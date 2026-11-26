import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tara_ui/components/intro.dart';
import 'package:tara_ui/components/intro_art.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Présentation au premier lancement de l'app livreur : courses, gains, sécurité. Pas de
/// maquette propre : mêmes pièces, mesures et animations que la présentation de
/// l'expéditeur (maquettes « Présentation »). Vue une fois.
class RiderIntroScreen extends StatelessWidget {
  const RiderIntroScreen({super.key, required this.onDone, this.initialPage = 0});

  final VoidCallback onDone;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IntroScreen(
      initialPage: initialPage,
      skip: l.introSkip,
      next: l.introNext,
      start: l.introStart,
      back: l.introBack,
      onDone: onDone,
      slides: [
        IntroSlide(
          kicker: l.introJobsKicker,
          title: l.introJobsTitle,
          body: l.introJobsBody,
          illustration: const _JobsArt(),
          blobs: const [
            IntroBlob(right: -120, top: -90, size: 380, color: Color.fromRGBO(255, 106, 0, .34)),
            IntroBlob(left: -160, top: 360, size: 320, color: Color.fromRGBO(255, 176, 0, .14), stop: .7),
          ],
        ),
        IntroSlide(
          kicker: l.introEarningsKicker,
          title: l.introEarningsTitle,
          body: l.introEarningsBody,
          illustration: const _EarningsArt(),
          blobs: const [IntroBlob(right: -140, top: 220, size: 400, color: Color.fromRGBO(255, 106, 0, .26))],
        ),
        IntroSlide(
          kicker: l.introSafetyKicker,
          title: l.introSafetyTitle,
          body: l.introSafetyBody,
          illustration: const _SafetyArt(),
          blobs: const [IntroBlob(left: 60, top: 60, size: 420, color: Color.fromRGBO(229, 37, 47, .18), stop: .66)],
        ),
      ],
    );
  }
}

TextStyle _jakarta(double size, FontWeight weight, Color color) =>
    TextStyle(fontFamily: TaraText.jakarta, fontSize: size, fontWeight: weight, color: color, height: 1.3);

const _jobPath = 'M78 318 C 150 300, 118 214, 196 200 S 286 168, 304 116';

/// 1 · Courses : comme l'écran « Envoyer » ; la moto file vers le client, la proposition
/// montre le gain et le trajet.
class _JobsArt extends StatelessWidget {
  const _JobsArt();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    Widget streak(double left, double top, double width, double height, double alpha, double degrees) => Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: degrees * math.pi / 180,
        child: ColoredBox(color: c.textPrimary.withValues(alpha: alpha)),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(left: -120, top: 210, width: 630, height: 240, child: IntroFloor()),
        streak(-40, 120, 480, 2, .06, -9),
        streak(-40, 250, 480, 3, .07, 6),
        streak(150, -40, 2, 520, .05, 14),
        streak(290, -40, 3, 520, .06, -4),
        const Positioned.fill(
          child: IntroDrawnRoute(path: _jobPath, from: Offset(70, 330), to: Offset(310, 110)),
        ),
        const Positioned(left: 292, top: 104, child: IntroPulseDot()),
        Positioned(
          right: 20,
          top: 252,
          child: IntroGlassCard(
            padding: const EdgeInsets.all(14),
            radius: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.introJobsOffer.toUpperCase(),
                  style: _jakarta(11, FontWeight.w700, c.accentText).copyWith(letterSpacing: .88),
                ),
                const SizedBox(height: 6),
                Text(
                  l.introJobsEarning,
                  style: TextStyle(
                    fontFamily: TaraText.sora,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.introJobsRoute, style: _jakarta(11, FontWeight.w500, c.textPrimary.withValues(alpha: .72))),
              ],
            ),
          ),
        ),
        const Positioned.fill(
          child: IntroTraveler(
            path: _jobPath,
            size: Size(66, 44),
            stillPhase: .5,
            child: Row(children: [IntroSpeedLines(), SizedBox(width: 4), _MotoPuck()]),
          ),
        ),
        Positioned(
          left: 24,
          top: 62,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 177, 92, .14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color.fromRGBO(255, 177, 92, .32)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TaraIcon(TaraIcons.timer, size: 15, color: c.accentStrongText),
                const SizedBox(width: 6),
                Text(l.introJobsChip, style: _jakarta(12, FontWeight.w700, c.accentStrongText)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Livreur sur le trajet : rond en dégradé cerclé du fond, moto (comme le livreur de la
/// carte en relief de l'expéditeur).
class _MotoPuck extends StatelessWidget {
  const _MotoPuck();

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: TaraBrand.gradient,
            border: Border.all(color: c.bg, width: 3),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 106, 0, .7), blurRadius: 18)],
          ),
          alignment: Alignment.center,
          child: const TaraIcon(TaraIcons.moto, size: 17, strokeWidth: 2.2, color: TaraBrand.onBrand),
        ),
      ),
    );
  }
}

const _coinPath = 'M170 182 C 230 130, 320 190, 286 268';

/// 2 · Gains : comme l'écran « Encaisser » ; pièces qui volent vers la carte des gains
/// du jour dont les chiffres défilent.
class _EarningsArt extends StatelessWidget {
  const _EarningsArt();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 20,
          top: 60,
          child: Transform(
            alignment: Alignment.center,
            transform: cssPerspective(600)
              ..rotateY(18 * math.pi / 180)
              ..rotateX(6 * math.pi / 180)
              ..rotateZ(-3 * math.pi / 180),
            child: IntroGlassCard(
              padding: const EdgeInsets.all(14),
              radius: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(74, 222, 155, .16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color.fromRGBO(74, 222, 155, .36)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.introEarningsChip, style: _jakarta(12, FontWeight.w700, c.success)),
                    const SizedBox(width: 4),
                    TaraIcon(TaraIcons.check, size: 12, strokeWidth: 3, color: c.success),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(child: IntroCoin(path: _coinPath, size: 28)),
        const Positioned.fill(
          child: IntroCoin(path: _coinPath, size: 24, delay: Duration(milliseconds: 400)),
        ),
        const Positioned.fill(
          child: IntroCoin(path: _coinPath, size: 20, delay: Duration(milliseconds: 800)),
        ),
        Positioned(
          left: 96,
          top: 262,
          width: 274,
          height: 152,
          child: MotionBuilder(
            period: const Duration(seconds: 7),
            builder: (context, tilt, child) {
              final p = introPingPong(tilt);
              return Transform(
                alignment: Alignment.center,
                transform: cssPerspective(800)
                  ..rotateX((9 - 5 * p) * math.pi / 180)
                  ..rotateY((-12 + 21 * p) * math.pi / 180),
                child: child,
              );
            },
            child: MotionBuilder(
              period: const Duration(milliseconds: 2800),
              builder: (context, glow, child) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(255, 90, 0, .18 + .24 * introPingPong(glow)),
                      blurRadius: 40 + 8 * introPingPong(glow),
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: child,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: cssGradient(
                      150,
                      const Size(274, 152),
                      const [Color(0xFF241509), Color(0xFF16120E)],
                      const [0, .6],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color.fromRGBO(255, 177, 92, .28)),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: IntroSheen()),
                      const Positioned(right: 14, bottom: 18, child: Opacity(opacity: .9, child: IntroBars())),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.introEarningsCard,
                              style: _jakarta(12, FontWeight.w700, const Color.fromRGBO(255, 255, 255, .72)),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const IntroRollingAmount(
                                  digits: [1, 2, 4],
                                  fixed: '00',
                                  style: TextStyle(
                                    fontFamily: TaraText.sora,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'F',
                                  style: TextStyle(
                                    fontFamily: TaraText.sora,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFFFFF).withValues(alpha: .72),
                                  ),
                                ),
                              ],
                            ),
                            Text(l.introEarningsFooter, style: _jakarta(12, FontWeight.w700, const Color(0xFF4ADE9B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 3 · Sécurité : bouton SOS qui pulse, entouré de ce qui se passe quand on l'active.
class _SafetyArt extends StatelessWidget {
  const _SafetyArt();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    Widget step(TaraIconData icon, String label) => IntroGlassCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 177, 92, .16),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: TaraIcon(icon, size: 17, strokeWidth: 1.9, color: c.accentText),
          ),
          const SizedBox(width: 8),
          Text(label, style: _jakarta(13, FontWeight.w700, c.textPrimary)),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 92,
          child: Center(
            child: PulseRings(
              size: 190,
              color: const Color(0xFFE5252F).withValues(alpha: .35),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: cssGradient(150, const Size.square(132), const [Color(0xFFFF4D57), Color(0xFFC8141F)]),
                  boxShadow: const [
                    BoxShadow(color: Color.fromRGBO(229, 37, 47, .45), blurRadius: 40, offset: Offset(0, 18)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text('SOS', style: TaraText.sos.copyWith(color: const Color(0xFFFFFFFF), fontSize: 38)),
              ),
            ),
          ),
        ),
        Positioned(left: 20, top: 24, child: step(TaraIcons.shieldCheck, l.introSafetyTeam)),
        Positioned(right: 20, top: 292, child: step(TaraIcons.contacts, l.introSafetyContact)),
        Positioned(left: 20, top: 346, child: step(TaraIcons.mapPin, l.introSafetyPosition)),
      ],
    );
  }
}
