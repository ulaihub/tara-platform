import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tara_ui/components/brand.dart';
import 'package:tara_ui/components/intro.dart';
import 'package:tara_ui/components/intro_art.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Illustrations des 4 écrans de présentation, reprises point par point des maquettes
/// (Présentation · Envoyer, Suivre, Encaisser, Deux comptes) : zone de 390 × 430, mêmes
/// positions, tailles, couleurs, transformations 3D et animations.

/// Halos de chaque écran (positions de la maquette sur l'écran de 390 × 844).
abstract final class ClientIntroBlobs {
  static const send = [
    IntroBlob(right: -120, top: -90, size: 380, color: Color.fromRGBO(255, 106, 0, .34)),
    IntroBlob(left: -160, top: 360, size: 320, color: Color.fromRGBO(255, 176, 0, .14), stop: .7),
  ];
  static const track = [IntroBlob(left: -110, top: -80, size: 360, color: Color.fromRGBO(255, 106, 0, .26))];
  static const collect = [IntroBlob(right: -140, top: 220, size: 400, color: Color.fromRGBO(255, 106, 0, .26))];
  static const accounts = [IntroBlob(left: 60, top: 60, size: 420, color: Color.fromRGBO(255, 106, 0, .24), stop: .66)];
}

TextStyle _jakarta(double size, FontWeight weight, Color color) =>
    TextStyle(fontFamily: TaraText.jakarta, fontSize: size, fontWeight: weight, color: color, height: 1.3);

TextStyle _sora(double size, FontWeight weight, Color color, {double spacing = 0}) => TextStyle(
  fontFamily: TaraText.sora,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: spacing,
  height: 1.2,
);

const _sendPath = 'M78 318 C 150 300, 118 214, 196 200 S 286 168, 304 116';

/// 1 · Envoyer : sol quadrillé qui défile, rues pâles, trajet qui se dessine de la
/// boutique au client, colis en 3D qui file dessus, point d'arrivée qui pulse.
class SendArt extends StatelessWidget {
  const SendArt({super.key});

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
          child: IntroDrawnRoute(path: _sendPath, from: Offset(70, 330), to: Offset(310, 110)),
        ),
        Positioned(
          left: 20,
          top: 334,
          child: IntroGlassCard(
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
                  child: TaraIcon(TaraIcons.homeSoft, size: 17, strokeWidth: 1.9, color: c.accentText),
                ),
                const SizedBox(width: 8),
                _TwoLines(title: l.introSendFrom, subtitle: l.introSendFromAddress),
              ],
            ),
          ),
        ),
        const Positioned(left: 292, top: 104, child: IntroPulseDot()),
        Positioned(
          right: 20,
          top: 40,
          child: IntroGlassCard(
            child: _TwoLines(title: l.introSendTo, subtitle: l.introSendDelivered),
          ),
        ),
        const Positioned.fill(
          child: IntroTraveler(
            path: _sendPath,
            size: Size(66, 44),
            stillPhase: .78,
            child: Row(children: [IntroSpeedLines(), SizedBox(width: 4), IntroCube()]),
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
                Text(l.introSendChip, style: _jakarta(12, FontWeight.w700, c.accentStrongText)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Titre 13 en gras, ligne 11 en encre à 72 %.
class _TwoLines extends StatelessWidget {
  const _TwoLines({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _jakarta(13, FontWeight.w700, c.textPrimary)),
        Text(subtitle, style: _jakarta(11, FontWeight.w500, c.textPrimary.withValues(alpha: .72))),
      ],
    );
  }
}

/// 2 · Suivre : quartier en relief dans une carte de 350 × 410, livreur qui roule vers
/// l'épingle, carte du livreur avec le temps restant et la barre d'avancée.
class TrackArt extends StatelessWidget {
  const TrackArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final palette = IntroMapPalette.of(context);
    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 16,
          width: 350,
          height: 410,
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: c.textPrimary.withValues(alpha: .08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  const Positioned.fill(child: IntroCity()),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: palette.panel.withValues(alpha: .86),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.textPrimary.withValues(alpha: .12)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2B33),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text('JM', style: _sora(13, FontWeight.w800, c.accentStrongText)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.introTrackRider, style: _jakarta(14, FontWeight.w700, c.textPrimary)),
                                    Text(
                                      l.introTrackPlate,
                                      style: _jakarta(12, FontWeight.w500, c.textPrimary.withValues(alpha: .72)),
                                    ),
                                  ],
                                ),
                              ),
                              // `tara-eta` 2,4 s : plein, puis à 55 %.
                              MotionBuilder(
                                period: const Duration(milliseconds: 2400),
                                builder: (context, t, child) => Opacity(
                                  opacity: t < .45
                                      ? 1
                                      : (t < .5
                                            ? 1 - .45 * (t - .45) / .05
                                            : (t < .95 ? .55 : .55 + .45 * (t - .95) / .05)),
                                  child: child,
                                ),
                                child: Text(l.introTrackEta, style: _sora(18, FontWeight.w700, c.accentStrongText)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Barre d'avancée : de 18 % à 72 % en 7 s (`tara-fill`), dégradé qui coule.
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.textPrimary.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            alignment: Alignment.centerLeft,
                            child: MotionBuilder(
                              period: const Duration(seconds: 7),
                              stillPhase: 1,
                              builder: (context, t, child) =>
                                  FractionallySizedBox(widthFactor: .18 + .54 * t, child: child),
                              child: const ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(3)),
                                child: SizedBox(height: 6, child: FlowBar()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _coinPath = 'M170 182 C 230 130, 320 190, 286 268';

/// 3 · Encaisser : reçu à la porte incliné en 3D, pièces qui volent vers la carte
/// « Ventes à recevoir » dont les chiffres défilent jusqu'à 52 500 F.
class CollectArt extends StatelessWidget {
  const CollectArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 20,
          top: 34,
          width: 210,
          child: Transform(
            alignment: Alignment.center,
            transform: cssPerspective(600)
              ..rotateY(18 * math.pi / 180)
              ..rotateX(6 * math.pi / 180)
              ..rotateZ(-3 * math.pi / 180),
            child: IntroGlassCard(
              padding: const EdgeInsets.all(14),
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.introCollectDoor.toUpperCase(),
                    style: _jakarta(
                      11,
                      FontWeight.w700,
                      c.textPrimary.withValues(alpha: .66),
                    ).copyWith(letterSpacing: .88),
                  ),
                  const SizedBox(height: 8),
                  Text(l.introCollectRecipient, style: _jakarta(14, FontWeight.w700, c.textPrimary)),
                  const SizedBox(height: 8),
                  Text(l.introCollectAmount, style: _sora(24, FontWeight.w800, c.textPrimary)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.textPrimary.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.introCollectCash,
                            style: _jakarta(11, FontWeight.w700, c.textPrimary.withValues(alpha: .82)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(74, 222, 155, .16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color.fromRGBO(74, 222, 155, .36)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l.introCollectMomo, style: _jakarta(11, FontWeight.w700, c.success)),
                              const SizedBox(width: 3),
                              TaraIcon(TaraIcons.check, size: 11, strokeWidth: 3, color: c.success),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          // `t3-tilt` 7 s et `tara-glow` 2,8 s.
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
              child: _SalesCard(label: l.introSalesLabel, footer: l.introCollectFooter),
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte sombre « Ventes à recevoir » de l'écran Encaisser (274 × 152, coins 26).
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.label, required this.footer});
  final String label;
  final String footer;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: Container(
      decoration: BoxDecoration(
        gradient: cssGradient(150, const Size(274, 152), const [Color(0xFF241509), Color(0xFF16120E)], const [0, .6]),
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
                Text(label, style: _jakarta(12, FontWeight.w700, const Color.fromRGBO(255, 255, 255, .72))),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    IntroRollingAmount(
                      digits: const [5, 2, 5],
                      fixed: '00',
                      style: _sora(34, FontWeight.w800, const Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 6),
                    Text('F', style: _sora(18, FontWeight.w800, const Color.fromRGBO(255, 255, 255, .72))),
                  ],
                ),
                Text(footer, style: _jakarta(12, FontWeight.w700, const Color(0xFF4ADE9B))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Pose d'une carte de l'écran Deux comptes : `translate`, `rotateX`, `rotateY`,
/// `rotateZ`, `translateZ`, plan (z-index).
typedef _Pose = ({double x, double y, double rx, double ry, double rz, double z, int layer});

const _front = (x: 0.0, y: 0.0, rx: 14.0, ry: -10.0, rz: 0.0, z: 0.0, layer: 2);
const _aside = (x: -170.0, y: 18.0, rx: 8.0, ry: -55.0, rz: -10.0, z: 40.0, layer: 2);
const _behind = (x: 0.0, y: -46.0, rx: 14.0, ry: -10.0, rz: 0.0, z: -90.0, layer: 1);

/// Images clés `tara-cardA` (ventes) et `tara-cardB` (Solde Tara), 7 s.
const _cardA = <(double, _Pose)>[
  (0, _front),
  (.36, _front),
  (.46, _aside),
  (.52, _behind),
  (.88, _behind),
  (1, _front),
];
const _cardB = <(double, _Pose)>[
  (0, _behind),
  (.36, _behind),
  (.5, _front),
  (.86, _front),
  (.96, _aside),
  (1, _behind),
];

_Pose _poseAt(List<(double, _Pose)> keys, double t) {
  for (var i = 1; i < keys.length; i++) {
    final (end, b) = keys[i];
    final (start, a) = keys[i - 1];
    if (t > end) continue;
    if (end == start) return b;
    final p = const Cubic(.6, 0, .3, 1).transform((t - start) / (end - start));
    double lerp(double from, double to) => from + (to - from) * p;
    return (
      x: lerp(a.x, b.x),
      y: lerp(a.y, b.y),
      rx: lerp(a.rx, b.rx),
      ry: lerp(a.ry, b.ry),
      rz: lerp(a.rz, b.rz),
      z: lerp(a.z, b.z),
      // z-index entier : bascule à mi-chemin.
      layer: (a.layer + (b.layer - a.layer) * p).round(),
    );
  }
  return keys.last.$2;
}

Matrix4 _matrix(_Pose pose) => cssPerspective(900)
  ..translateByDouble(pose.x, pose.y, 0, 1)
  ..rotateX(pose.rx * math.pi / 180)
  ..rotateY(pose.ry * math.pi / 180)
  ..rotateZ(pose.rz * math.pi / 180)
  ..translateByDouble(0, 0, pose.z, 1);

/// 4 · Deux comptes : la carte des ventes et celle du Solde Tara changent de place en
/// boucle (7 s) ; glisser fait passer l'une devant l'autre.
class AccountsArt extends StatefulWidget {
  const AccountsArt({super.key});

  @override
  State<AccountsArt> createState() => _AccountsArtState();
}

class _AccountsArtState extends State<AccountsArt> {
  /// Décalage de phase après un glissement : l'autre carte passe devant.
  Duration _shift = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final sales = _AccountCard(
      dark: true,
      label: l.introSalesLabel,
      tag: l.introAccountsShopTag,
      amount: '${_group(128500)} F',
      footer: l.introAccountsSalesFooter,
    );
    final tara = _AccountCard(
      dark: false,
      label: l.introAccountsTaraLabel,
      amount: '${_group(3500)} F',
      footer: l.introAccountsTaraFooter,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (_) =>
          setState(() => _shift = _shift == Duration.zero ? const Duration(milliseconds: 3500) : Duration.zero),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 40,
            top: 130,
            width: 310,
            height: 190,
            child: MotionBuilder(
              period: const Duration(seconds: 7),
              delay: _shift,
              stillPhase: _shift == Duration.zero ? 0 : .6,
              builder: (context, t, _) {
                final a = _poseAt(_cardA, t);
                final b = _poseAt(_cardB, t);
                final cards = [
                  (b.layer, Transform(alignment: Alignment.center, transform: _matrix(b), child: tara)),
                  (a.layer, Transform(alignment: Alignment.center, transform: _matrix(a), child: sales)),
                ];
                // Ordre d'affichage : plan le plus bas d'abord ; à égalité, la carte des ventes devant.
                if (b.layer > a.layer) cards.insert(0, cards.removeAt(1));
                return Stack(clipBehavior: Clip.none, children: [for (final (_, card) in cards) card]);
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 352,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MotionBuilder(
                  period: const Duration(milliseconds: 1400),
                  stillPhase: .5,
                  builder: (context, t, child) {
                    final p = introPingPong(t);
                    return Transform.translate(
                      offset: Offset(-8 * p, 0),
                      child: Opacity(opacity: .5 + .5 * p, child: child),
                    );
                  },
                  child: SizedBox.square(
                    dimension: 18,
                    child: Stack(
                      children: [
                        TaraIcon(TaraIcons.chevronLeft, size: 18, strokeWidth: 2.2, color: c.accentText),
                        Transform.translate(
                          offset: const Offset(18 * 5 / 24, 0),
                          child: TaraIcon(
                            TaraIcons.chevronLeft,
                            size: 18,
                            strokeWidth: 2.2,
                            color: c.accentText.withValues(alpha: c.accentText.a * .5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l.introAccountsSwipe, style: _jakarta(13, FontWeight.w700, c.textPrimary.withValues(alpha: .74))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _group(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Carte de compte de 310 × 190, coins 28 : sombre (ventes, barres orange) ou claire
/// (Solde Tara, petit logo).
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.dark, required this.label, required this.amount, required this.footer, this.tag});

  final bool dark;
  final String label;
  final String amount;
  final String footer;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    const size = Size(310, 190);
    final ink = dark ? const Color(0xFFFFFFFF) : const Color(0xFF16120E);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: dark
            ? cssGradient(150, size, const [Color(0xFF2A170A), Color(0xFF16120E)], const [0, .62])
            : cssGradient(160, size, const [Color(0xFFFFFFFF), Color(0xFFFFF1E2)]),
        border: dark ? Border.all(color: const Color.fromRGBO(255, 177, 92, .28)) : null,
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, dark ? .5 : .45), blurRadius: 50, offset: const Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(child: IntroSheen()),
            if (dark)
              const Positioned(right: 18, bottom: 22, child: IntroBars(widths: [64, 42, 22], height: 7, gap: 7)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: _jakarta(13, FontWeight.w700, ink.withValues(alpha: dark ? .74 : .72)),
                        ),
                      ),
                      if (tag case final tag?)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 177, 92, .16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(tag, style: _jakarta(11, FontWeight.w700, const Color(0xFFFFC283))),
                        )
                      else
                        const SizedBox(
                          width: 40,
                          height: 28,
                          child: Center(child: TaraLogo(width: 40, ink: Color(0xFF16120E))),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(amount, style: _sora(34, FontWeight.w800, ink, spacing: -.68)),
                      const SizedBox(height: 4),
                      Text(footer, style: _jakarta(12, FontWeight.w600, ink.withValues(alpha: dark ? .72 : .70))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
