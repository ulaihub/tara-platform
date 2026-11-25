import 'package:flutter/material.dart';
import 'package:tara_ui/components/intro.dart';
import 'package:tara_ui/components/intro_art.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Présentation au premier lancement de l'app livreur : courses, gains, sécurité. Même
/// style que celle de l'expéditeur (maquettes « Présentation »). Vue une fois.
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
      onDone: onDone,
      slides: [
        IntroSlide(
          kicker: l.introJobsKicker,
          title: l.introJobsTitle,
          body: l.introJobsBody,
          illustration: const _JobsArt(),
        ),
        IntroSlide(
          kicker: l.introEarningsKicker,
          title: l.introEarningsTitle,
          body: l.introEarningsBody,
          illustration: const _EarningsArt(),
        ),
        IntroSlide(
          kicker: l.introSafetyKicker,
          title: l.introSafetyTitle,
          body: l.introSafetyBody,
          illustration: const _SafetyArt(),
        ),
      ],
    );
  }
}

Widget _at(BoxConstraints box, double x, double y, Widget child) =>
    Positioned(left: box.maxWidth * x, top: box.maxHeight * y, child: child);

/// 1 · Courses : la moto file vers le vendeur ; la proposition affiche trajet et gain.
class _JobsArt extends StatelessWidget {
  const _JobsArt();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: IntroGrid(horizon: .5)),
          Positioned(left: box.maxWidth * .55, top: box.maxHeight * .1, child: const IntroGlow(size: 180)),
          const Positioned.fill(
            child: IntroRoute(
              curved: true,
              period: Duration(seconds: 6),
              stillPhase: .45,
              mover: IntroPuck(icon: TaraIcons.moto),
              points: [Offset(.18, .8), Offset(.48, .72), Offset(.32, .44), Offset(.78, .34)],
            ),
          ),
          _at(box, .72, .26, const IntroPuck(icon: TaraIcons.package, size: 30)),
          _at(box, .06, .08, IntroChip(label: l.introJobsChip, icon: TaraIcons.timer)),
          Positioned(
            left: box.maxWidth * .06,
            right: box.maxWidth * .46,
            top: box.maxHeight * .24,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: c.isDark ? const Color(0xFF1E1914) : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.textPrimary.withValues(alpha: .08)),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .12), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.introJobsOffer.toUpperCase(),
                    style: TaraText.overline.copyWith(color: c.accentText, letterSpacing: 1.2),
                  ),
                  Text(
                    l.introJobsEarning,
                    style: TaraText.titleForm.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                  ),
                  Text(l.introJobsRoute, style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2 · Gains : pièces qui tombent dans la carte des gains du jour.
class _EarningsArt extends StatelessWidget {
  const _EarningsArt();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -40, top: box.maxHeight * .3, child: const IntroGlow(size: 260, alpha: .28)),
          _at(box, .07, .12, IntroChip(label: l.introEarningsChip, icon: TaraIcons.check, tint: const Color(0xFF1FA463))),
          _at(box, .56, .2, const IntroCoin(fall: 120)),
          _at(box, .64, .26, const IntroCoin(fall: 110, delay: Duration(milliseconds: 600))),
          _at(box, .7, .34, const IntroCoin(fall: 90, delay: Duration(milliseconds: 1200))),
          Positioned(
            left: box.maxWidth * .14,
            top: box.maxHeight * .46,
            child: MoneyCard(
              label: l.introEarningsCard,
              from: 11350,
              amount: 12400,
              footer: l.introEarningsFooter,
              footerColor: const Color(0xFF4ADE9B),
              tilt: -.03,
              width: box.maxWidth * .72,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3 · Sécurité : bouton SOS qui pulse, entouré de ce qui se passe quand on l'active.
class _SafetyArt extends StatelessWidget {
  const _SafetyArt();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: const Alignment(0, -.15),
            child: PulseRings(
              size: 150,
              color: const Color(0xFFE5252F).withValues(alpha: .35),
              child: MotionBuilder(
                period: const Duration(seconds: 3),
                builder: (context, t, child) => child!,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF4D57), Color(0xFFC8141F)],
                    ),
                    boxShadow: [BoxShadow(color: Color.fromRGBO(229, 37, 47, .45), blurRadius: 30, offset: Offset(0, 12))],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'SOS',
                    style: TaraText.sos.copyWith(color: const Color(0xFFFFFFFF), fontSize: 34),
                  ),
                ),
              ),
            ),
          ),
          _at(box, .05, .08, IntroChip(label: l.introSafetyTeam, icon: TaraIcons.shieldCheck)),
          _at(box, .4, .72, IntroChip(label: l.introSafetyContact, icon: TaraIcons.contacts)),
          _at(box, .06, .86, IntroChip(label: l.introSafetyPosition, icon: TaraIcons.mapPin)),
        ],
      ),
    );
  }
}
