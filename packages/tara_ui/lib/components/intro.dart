import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'brand.dart';

/// Halo orange flou d'un écran de la présentation (maquette : `radial-gradient` posé
/// en absolu sur l'écran de 390 × 844, qui dérive lentement). Positions en pixels depuis
/// le haut de l'écran, sous la barre d'état ; `left` ou `right`.
class IntroBlob {
  const IntroBlob({this.left, this.right, required this.top, required this.size, required this.color, this.stop = .68});

  final double? left;
  final double? right;
  final double top;
  final double size;
  final Color color;

  /// Fin du dégradé, en fraction du rayon.
  final double stop;
}

/// Un écran de la présentation : illustration en haut, sur-titre, titre, texte.
class IntroSlide {
  const IntroSlide({
    required this.kicker,
    required this.title,
    required this.body,
    required this.illustration,
    this.blobs = const [],
    this.textTop = 0,
  });

  final String kicker;
  final String title;
  final String body;

  /// Dessinée sur une zone de 390 × [IntroScreen.artHeight] (coordonnées de la maquette),
  /// réduite d'un bloc si la place manque.
  final Widget illustration;
  final List<IntroBlob> blobs;

  /// Espace entre l'illustration et le sur-titre (maquette Suivre : 24).
  final double textTop;
}

/// Clés des boutons (tests des apps).
const introNextKey = ValueKey('intro-next');
const introSkipKey = ValueKey('intro-skip');
const introBackKey = ValueKey('intro-back');

/// Présentation au premier lancement (maquettes « Présentation ») : écrans à faire glisser ;
/// en haut, logo puis bouton retour, « Passer » puis logo au dernier écran ; points de
/// progression ; « Suivant » puis « Commencer ».
class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    required this.slides,
    required this.skip,
    required this.next,
    required this.start,
    required this.back,
    required this.onDone,
    this.initialPage = 0,
  });

  /// Hauteur de la zone d'illustration des maquettes.
  static const artHeight = 430.0;

  final List<IntroSlide> slides;
  final String skip;
  final String next;
  final String start;

  /// Libellé lu du bouton retour (« Écran précédent »).
  final String back;
  final VoidCallback onDone;

  /// Page affichée au départ (captures de chaque écran).
  final int initialPage;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final _pages = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _page == widget.slides.length - 1;

  void _go(int page) =>
      _pages.animateToPage(page, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  void _next() {
    if (_last) {
      widget.onDone();
      return;
    }
    _go(_page + 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    // Maquette : 28 sous le bouton, au-dessus de la barre de gestes du système.
    final bottom = math.max(28.0, padding.bottom);
    const header = 20.0 + 44;
    // Points, bouton, et au moins 16 entre le texte et les points.
    final footer = 16 + 6 + 22 + 58 + bottom;
    return Material(
      color: c.bg,
      child: MotionClock(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.slides.length,
                onPageChanged: (page) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = page);
                },
                itemBuilder: (context, index) =>
                    _SlidePage(slide: widget.slides[index], top: padding.top, header: header, footer: footer),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: padding.top + 20,
              height: 44,
              child: Row(
                children: [
                  if (_page == 0)
                    const IntroLogoTile()
                  else
                    _BackButton(label: widget.back, onPressed: () => _go(_page - 1)),
                  const Spacer(),
                  if (_last)
                    const IntroLogoTile()
                  else
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        key: introSkipKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onDone,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          child: Text(
                            widget.skip,
                            style: TaraText.bodyStrong.copyWith(color: c.accentText, height: 1.2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: '${_page + 1} / ${widget.slides.length}',
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.slides.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          _Dot(active: i == _page),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _IntroButton(
                    key: introNextKey,
                    label: _last ? widget.start : widget.next,
                    arrow: !_last,
                    onPressed: _next,
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

/// Une page : halos (qui glissent avec elle), illustration, textes.
class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.top, required this.header, required this.footer});

  final IntroSlide slide;
  final double top;
  final double header;
  final double footer;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final blob in slide.blobs)
          Positioned(
            left: blob.left,
            right: blob.right,
            top: top + blob.top,
            width: blob.size,
            height: blob.size,
            child: _Blob(blob: blob),
          ),
        Padding(
          padding: EdgeInsets.only(top: top + header, bottom: footer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final height = math.min(box.maxHeight, IntroScreen.artHeight);
                    return SizedBox(
                      height: height,
                      child: ExcludeSemantics(
                        child: FittedBox(
                          alignment: Alignment.topCenter,
                          child: SizedBox(width: 390, height: IntroScreen.artHeight, child: slide.illustration),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, slide.textTop, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.kicker.toUpperCase(),
                      style: TaraText.smallStrong.copyWith(color: c.accentText, letterSpacing: .96, height: 1.25),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: BalancedText(
                        slide.title,
                        style: TextStyle(
                          fontFamily: TaraText.sora,
                          fontSize: 32,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.64,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.body,
                      style: TaraText.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary.withValues(alpha: .74),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Texte réparti en lignes de longueur égale (CSS `text-wrap: balance` des titres).
class BalancedText extends StatelessWidget {
  const BalancedText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        int lines(double width) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: width);
          final count = painter.computeLineMetrics().length;
          painter.dispose();
          return count;
        }

        final max = box.maxWidth;
        final count = lines(max);
        var width = max;
        if (count > 1) {
          // Plus petite largeur qui garde le même nombre de lignes.
          var low = max / count;
          var high = max;
          while (high - low > 1) {
            final mid = (low + high) / 2;
            if (lines(mid) > count) {
              low = mid;
            } else {
              high = mid;
            }
          }
          width = high;
        }
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: width,
            child: Text(text, style: style),
          ),
        );
      },
    );
  }
}

/// Halo qui dérive lentement (maquette : `lq-drift` 20 s, aller-retour).
class _Blob extends StatelessWidget {
  const _Blob({required this.blob});
  final IntroBlob blob;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: MotionBuilder(
      period: const Duration(seconds: 40),
      builder: (context, t, child) {
        final p = Curves.easeInOut.transform(t < .5 ? t * 2 : 2 - t * 2);
        final offset = p < .5
            ? Offset.lerp(Offset.zero, const Offset(28, -22), p * 2)!
            : Offset.lerp(const Offset(28, -22), const Offset(-22, 26), p * 2 - 1)!;
        return Transform.translate(offset: offset, child: child);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [blob.color, blob.color.withValues(alpha: 0)], stops: [0, blob.stop]),
        ),
      ),
    ),
  );
}

/// Logo sur sa carte sombre arrondie (maquette : image 58 × 41, marges 6 et 8, coins 12).
class IntroLogoTile extends StatelessWidget {
  const IntroLogoTile({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFF16120E), borderRadius: BorderRadius.circular(12)),
    child: const SizedBox(
      width: 58,
      height: 41,
      child: Center(child: TaraLogo(width: 58, ink: Color(0xFFFFFFFF))),
    ),
  );
}

/// Retour à l'écran précédent : carré de verre 44, coins 14, chevron.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: introBackKey,
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.textPrimary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.textPrimary.withValues(alpha: .12)),
          ),
          alignment: Alignment.center,
          child: TaraIcon(TaraIcons.chevronLeft, size: 20, color: c.textPrimary),
        ),
      ),
    );
  }
}

/// Point de progression : 8 × 6 gris, 28 × 6 en dégradé qui coule pour l'écran affiché.
class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: active ? 28 : 8,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: active ? null : c.textPrimary.withValues(alpha: .24),
      ),
      child: active ? const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(3)), child: FlowBar()) : null,
    );
  }
}

/// Barre au dégradé de marque qui coule (maquette `lq-flow` 2,6 s : dégradé
/// ambre, orange, rouge, orange, ambre sur deux largeurs, qui glisse).
class FlowBar extends StatelessWidget {
  const FlowBar({super.key});

  @override
  Widget build(BuildContext context) => MotionBuilder(
    period: const Duration(milliseconds: 2600),
    builder: (context, t, _) => CustomPaint(painter: _FlowPainter(t), size: Size.infinite),
  );
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final span = size.width * 2;
    final start = -span * t;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(start, 0),
          Offset(start + span, 0),
          const [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, TaraBrand.orange, TaraBrand.amber],
          const [0, .25, .5, .75, 1],
          TileMode.repeated,
        ),
    );
  }

  @override
  bool shouldRepaint(_FlowPainter old) => old.t != t;
}

/// Bouton de la maquette : 58 de haut, coins 20, « Suivant » à gauche et flèche ambre
/// dans un carré sombre de 46 ; « Commencer » centré, sans flèche, au dernier écran.
class _IntroButton extends StatelessWidget {
  const _IntroButton({super.key, required this.label, required this.arrow, required this.onPressed});

  final String label;
  final bool arrow;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        height: 58,
        padding: EdgeInsets.fromLTRB(arrow ? 22 : 6, 6, 6, 6),
        decoration: BoxDecoration(
          gradient: TaraBrand.gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 90, 0, .32), blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: arrow ? TextAlign.left : TextAlign.center,
                style: TaraText.buttonStrong.copyWith(color: TaraBrand.onBrand),
              ),
            ),
            if (arrow)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: TaraBrand.onBrand, borderRadius: BorderRadius.circular(15)),
                alignment: Alignment.center,
                child: const TaraIcon(TaraIcons.arrowRight, size: 22, strokeWidth: 2.4, color: TaraBrand.amber),
              ),
          ],
        ),
      ),
    ),
  );
}
