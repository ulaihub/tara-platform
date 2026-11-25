import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tara_ui/components/intro_art.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Illustrations des 4 écrans de présentation, calquées sur les maquettes
/// (Presentation · Envoyer, Suivre, Encaisser, Deux comptes). Positions en fractions de la
/// zone de l'illustration, relevées sur les maquettes en 390 × 844.

Widget _at(BoxConstraints box, double x, double y, Widget child) =>
    Positioned(left: box.maxWidth * x, top: box.maxHeight * y, child: child);

/// 1 · Envoyer : sol en perspective, trajet qui se dessine de la boutique au client,
/// colis en relief à l'arrivée.
class SendArt extends StatelessWidget {
  const SendArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: IntroGrid(horizon: .5)),
          Positioned(left: box.maxWidth * .62, top: box.maxHeight * .14, child: const IntroGlow(size: 170)),
          const Positioned.fill(
            child: IntroRoute(
              curved: true,
              drawOnly: true,
              stillPhase: .99,
              period: Duration(seconds: 6),
              points: [Offset(.2, .78), Offset(.46, .7), Offset(.3, .46), Offset(.76, .36)],
            ),
          ),
          _at(box, .69, .25, const _Parcel()),
          _at(box, .48, .14, IntroLabel(title: l.introSendTo, subtitle: l.introSendDelivered)),
          _at(box, .06, .3, IntroChip(label: l.introSendChip)),
          _at(
            box,
            .08,
            .8,
            IntroLabel(
              title: l.introSendFrom,
              subtitle: l.introSendFromAddress,
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c.accentText.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: TaraIcon(TaraIcons.home, size: 16, color: c.accentText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colis en relief (trois faces) qui flotte doucement.
class _Parcel extends StatelessWidget {
  const _Parcel();

  @override
  Widget build(BuildContext context) => MotionBuilder(
    period: const Duration(milliseconds: 2600),
    stillPhase: .25,
    builder: (context, t, child) =>
        Transform.translate(offset: Offset(0, -5 * math.sin(t * 2 * math.pi)), child: child),
    child: SizedBox(width: 52, height: 52, child: CustomPaint(painter: _CubePainter())),
  );
}

class _CubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = Path()
      ..moveTo(w * .5, 0)
      ..lineTo(w, w * .25)
      ..lineTo(w * .5, w * .5)
      ..lineTo(0, w * .25)
      ..close();
    final left = Path()
      ..moveTo(0, w * .25)
      ..lineTo(w * .5, w * .5)
      ..lineTo(w * .5, w)
      ..lineTo(0, w * .75)
      ..close();
    final right = Path()
      ..moveTo(w, w * .25)
      ..lineTo(w * .5, w * .5)
      ..lineTo(w * .5, w)
      ..lineTo(w, w * .75)
      ..close();
    canvas
      ..drawPath(top, Paint()..color = const Color(0xFFE9A66B))
      ..drawPath(left, Paint()..color = const Color(0xFFCB7F3E))
      ..drawPath(right, Paint()..color = const Color(0xFFB36A2C))
      // Ruban adhésif.
      ..drawLine(Offset(w * .25, w * .125), Offset(w * .75, w * .375), Paint()
        ..color = const Color(0xFFF6C995)
        ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_CubePainter old) => false;
}

/// 2 · Suivre : quartier en relief, rues, livreur qui avance vers l'épingle, carte du
/// livreur et temps restant.
class TrackArt extends StatelessWidget {
  const TrackArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _BlocksPainter())),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: box.maxHeight * .2),
              child: const IntroRoute(
                period: Duration(seconds: 7),
                stillPhase: .55,
                mover: IntroPuck(icon: TaraIcons.navigation),
                points: [Offset(.3, .8), Offset(.55, .67), Offset(.38, .47), Offset(.61, .35), Offset(.5, .22)],
              ),
            ),
          ),
          _at(box, .465, .11, const _Pin()),
          _at(box, .285, .58, TaraIcon(TaraIcons.home, size: 18, color: c.textPrimary.withValues(alpha: .75))),
          Positioned(
            left: box.maxWidth * .1,
            right: box.maxWidth * .1,
            bottom: 0,
            child: _RiderLine(name: l.introTrackRider, plate: l.introTrackPlate, eta: l.introTrackEta),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Transform.rotate(
        angle: -math.pi / 4,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            gradient: TaraBrand.gradient,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(11),
              topRight: Radius.circular(11),
              bottomRight: Radius.circular(11),
            ),
          ),
        ),
      ),
      Container(
        width: 18,
        height: 6,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6A00).withValues(alpha: .25),
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    ],
  );
}

/// Îlots de rues hachurés, très pâles, comme le plan en relief de la maquette.
class _BlocksPainter extends CustomPainter {
  const _BlocksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8B48A).withValues(alpha: .35)
      ..strokeWidth = 1;
    final blocks = [
      const Rect.fromLTWH(.05, .2, .18, .2),
      const Rect.fromLTWH(.62, .12, .16, .18),
      const Rect.fromLTWH(.66, .42, .2, .22),
      const Rect.fromLTWH(.12, .5, .14, .16),
      const Rect.fromLTWH(.42, .03, .14, .12),
    ];
    for (final b in blocks) {
      final r = Rect.fromLTWH(b.left * size.width, b.top * size.height, b.width * size.width, b.height * size.height);
      for (var x = r.left; x < r.right; x += 6) {
        canvas.drawLine(Offset(x, r.top + (x - r.left) * .2), Offset(x, r.bottom), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlocksPainter old) => false;
}

class _RiderLine extends StatelessWidget {
  const _RiderLine({required this.name, required this.plate, required this.eta});
  final String name;
  final String plate;
  final String eta;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFF2A2522), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('JM', style: TaraText.smallStrong.copyWith(color: const Color(0xFFFFFFFF))),
            ),
            const SizedBox(width: 10),
            Expanded(child: IntroLabel(title: name, subtitle: plate)),
            Text(eta, style: TaraText.cardTitle.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        MotionBuilder(
          period: const Duration(seconds: 7),
          stillPhase: .55,
          builder: (context, t, _) => FractionallySizedBox(
            widthFactor: .2 + .5 * Curves.easeInOut.transform(t),
            child: Container(
              height: 6,
              decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 3 · Encaisser : reçu à la porte (espèces ou Mobile Money), pièces qui tombent dans la
/// carte « Ventes à recevoir » qui monte de 15 000 F.
class CollectArt extends StatelessWidget {
  const CollectArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -40, top: box.maxHeight * .45, child: const IntroGlow(size: 240, alpha: .28)),
          Positioned(
            left: box.maxWidth * .07,
            top: box.maxHeight * .1,
            child: Transform.rotate(
              angle: -.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.introCollectDoor.toUpperCase(),
                    style: TaraText.overline.copyWith(color: c.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: box.maxWidth * .45,
                    child: Text(
                      l.introCollectRecipient,
                      style: TaraText.bodyStrong.copyWith(color: c.textPrimary, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.introCollectAmount,
                    style: TaraText.titleForm.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l.introCollectCash, style: TaraText.smallStrong.copyWith(color: c.textPrimary)),
                      ),
                      IntroChip(label: l.introCollectMomo, icon: TaraIcons.check, tint: const Color(0xFF1FA463)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _at(box, .62, .33, const IntroCoin(fall: 120)),
          _at(box, .69, .39, const IntroCoin(fall: 110, delay: Duration(milliseconds: 600))),
          _at(box, .72, .48, const IntroCoin(fall: 90, delay: Duration(milliseconds: 1200))),
          Positioned(
            left: box.maxWidth * .24,
            top: box.maxHeight * .6,
            child: MoneyCard(
              label: l.introSalesLabel,
              from: 37500,
              amount: 52500,
              footer: l.introCollectFooter,
              footerColor: const Color(0xFF4ADE9B),
              tilt: -.03,
              width: box.maxWidth * .69,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4 · Deux comptes : carte des ventes devant, Solde Tara derrière ; on glisse pour
/// passer de l'une à l'autre.
class AccountsArt extends StatefulWidget {
  const AccountsArt({super.key});

  @override
  State<AccountsArt> createState() => _AccountsArtState();
}

class _AccountsArtState extends State<AccountsArt> {
  bool _tara = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final sales = MoneyCard(
      label: l.introSalesLabel,
      tag: l.introAccountsShopTag,
      amount: 128500,
      footer: l.introAccountsSalesFooter,
      tilt: -.04,
    );
    final tara = MoneyCard(
      label: l.introAccountsTaraLabel,
      amount: 3500,
      footer: l.introAccountsTaraFooter,
      tilt: -.04,
    );
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (_) => setState(() => _tara = !_tara),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(top: 20, right: 0, child: IntroGlow(size: 280, alpha: .22)),
            Align(
              alignment: const Alignment(.15, -.1),
              child: Transform.translate(
                offset: const Offset(18, -18),
                child: Opacity(
                  opacity: .9,
                  child: Container(
                    width: 280,
                    height: 150,
                    // Carte du Solde Tara derrière (maquette : claire, décalée en haut à droite).
                    decoration: BoxDecoration(
                      color: c.isDark ? const Color(0xFF2B2622) : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c.textPrimary.withValues(alpha: .08)),
                      boxShadow: const [
                        BoxShadow(color: Color.fromRGBO(0, 0, 0, .10), blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, -.1),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(begin: const Offset(.25, 0), end: Offset.zero).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: KeyedSubtree(key: ValueKey(_tara), child: _tara ? tara : sales),
              ),
            ),
            Align(
              alignment: const Alignment(0, .95),
              child: Text(l.introAccountsSwipe, style: TaraText.smallStrong.copyWith(color: c.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
