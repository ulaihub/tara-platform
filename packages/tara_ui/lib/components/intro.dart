import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/liquid_background.dart';
import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'brand.dart';

/// Un écran de la présentation : illustration en haut, sur-titre, titre, texte.
class IntroSlide {
  const IntroSlide({required this.kicker, required this.title, required this.body, required this.illustration});

  final String kicker;
  final String title;
  final String body;
  final Widget illustration;
}

/// Clés des boutons (tests des apps).
const introNextKey = ValueKey('intro-next');
const introSkipKey = ValueKey('intro-skip');

/// Présentation au premier lancement (maquettes « Présentation ») : écrans à faire glisser,
/// « Passer » toujours visible, points de progression, « Suivant » puis « Commencer ».
class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    required this.slides,
    required this.skip,
    required this.next,
    required this.start,
    required this.onDone,
    this.initialPage = 0,
  });

  final List<IntroSlide> slides;
  final String skip;
  final String next;
  final String start;
  final VoidCallback onDone;

  /// Page affichée au départ (captures de chaque écran).
  final int initialPage;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final _pages = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -1.1), size: 320, colors: BlobSpec.brand, blur: 80),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _page == widget.slides.length - 1;

  void _next() {
    if (_last) {
      widget.onDone();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Material(
      color: c.bg,
      child: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: LiquidBackground(blobs: _blobs))),
          MotionClock(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      // Maquette : logo en haut à gauche au premier écran, à droite au dernier ;
                      // « Passer » sur les autres.
                      child: Row(
                        children: [
                          if (_page == 0) const _LogoTile(),
                          const Spacer(),
                          if (_last)
                            const _LogoTile()
                          else
                            GestureDetector(
                              key: introSkipKey,
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onDone,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  widget.skip,
                                  style: TaraText.bodyStrong.copyWith(color: c.accentText),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: widget.slides.length,
                      onPageChanged: (page) {
                        HapticFeedback.selectionClick();
                        setState(() => _page = page);
                      },
                      itemBuilder: (context, index) => _SlideView(slide: widget.slides[index]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Row(
                      children: [
                        // Maquette : un seul trait dégradé qui avance d'écran en écran.
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(left: _page * 14.0),
                          child: Container(
                            width: 28,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: TaraBrand.gradient,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                    child: _IntroButton(
                      key: introNextKey,
                      label: _last ? widget.start : widget.next,
                      arrow: !_last,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final IntroSlide slide;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Petit écran ou grand texte : l'illustration cède la place au texte.
        final art = (constraints.maxHeight * .56).clamp(150.0, 430.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: art, child: ExcludeSemantics(child: slide.illustration)),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.kicker.toUpperCase(),
                      style: TaraText.overline.copyWith(color: c.textPrimary, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      header: true,
                      child: Text(
                        slide.title,
                        style: TaraText.titleAccess.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(slide.body, style: TaraText.body.copyWith(color: c.textPrimary.withValues(alpha: .82))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Logo sur sa carte sombre arrondie (maquette).
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) => Container(
    width: 74,
    height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFF15100C),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .18), blurRadius: 14, offset: Offset(0, 6))],
    ),
    alignment: Alignment.center,
    child: const TaraLogo(width: 56, ink: Color(0xFFFFFFFF)),
  );
}

/// Bouton de la maquette : « Suivant » à gauche et flèche orange dans un carré sombre à
/// droite ; « Commencer » centré, sans flèche, au dernier écran.
class _IntroButton extends StatelessWidget {
  const _IntroButton({super.key, required this.label, required this.arrow, required this.onPressed});

  final String label;
  final bool arrow;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
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
          padding: const EdgeInsets.fromLTRB(22, 7, 7, 7),
          decoration: BoxDecoration(
            gradient: TaraBrand.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: c.brandShadow,
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF15100C), borderRadius: BorderRadius.circular(13)),
                  alignment: Alignment.center,
                  child: const TaraIcon(TaraIcons.arrowRight, size: 20, strokeWidth: 2.4, color: Color(0xFFFFB15C)),
                )
              else
                const SizedBox(width: 15),
            ],
          ),
        ),
      ),
    );
  }
}
