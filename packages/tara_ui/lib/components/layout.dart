import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../format.dart';
import '../motion/effects.dart';
import '../motion/liquid_background.dart';
import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'glass.dart';

export 'tab_shell.dart' show FloatingTabBar, TabItem;

/// Gabarit commun d'un écran : fond du thème, formes liquides, horloge d'animation unique,
/// zone sûre. Les marges hautes de la maquette incluent la barre d'état : ici `SafeArea`.
class TaraScreen extends StatelessWidget {
  const TaraScreen({
    super.key,
    required this.child,
    this.blobs = const [],
    this.background,
    this.backgroundColor,
    this.safeTop = true,
    this.safeBottom = true,
    this.morph = const Duration(seconds: 14),
    this.drift = const Duration(seconds: 20),
  });

  final Widget child;
  final List<BlobSpec> blobs;

  /// Couche de fond supplémentaire (carte).
  final Widget? background;
  final Color? backgroundColor;
  final bool safeTop;
  final bool safeBottom;
  final Duration morph;
  final Duration drift;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return MotionClock(
      child: Material(
        color: backgroundColor ?? c.bg,
        child: Stack(
          children: [
            ?background,
            if (blobs.isNotEmpty)
              Positioned.fill(
                child: LiquidBackground(blobs: blobs, morph: morph, drift: drift),
              ),
            SafeArea(top: safeTop, bottom: safeBottom, child: child),
          ],
        ),
      ),
    );
  }
}

/// Montant en FCFA : chiffres Sora tabulaires et unité plus petite, en couleur secondaire.
class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key, this.style, this.unit = 'FCFA', this.color, this.unitStyle});

  final int amount;
  final TextStyle? style;
  final String unit;
  final Color? color;
  final TextStyle? unitStyle;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final main = (style ?? TaraText.amountL).copyWith(color: color ?? c.textPrimary);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: formatAmount(amount), style: main),
          TextSpan(
            text: ' $unit',
            style: (unitStyle ?? TaraText.unit).copyWith(color: c.textSecondary),
          ),
        ],
      ),
      semanticsLabel: '${formatAmount(amount)} $unit',
    );
  }
}

/// Avatar à initiales (rond sur l'accueil, carré arrondi pour un vendeur ou un client).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 46, this.round = true});

  final String name;
  final double size;
  final bool round;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFC46B), TaraBrand.orange],
          ),
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(initials(name), style: TaraText.cardTitle.copyWith(fontSize: 15, color: TaraBrand.onBrand)),
        ),
      ),
    );
  }
}

/// Tuile d'icône teintée (liste, pièces, historique).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 42, this.tone = TintTone.accent, this.radius = 14});

  final TaraIconData icon;
  final double size;
  final TintTone tone;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final (bg, fg) = switch (tone) {
      TintTone.accent => (c.accentTintBg, c.accentText),
      TintTone.success => (c.successTintBg, c.success),
      TintTone.danger => (c.dangerTint, c.dangerText),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: Center(
        child: TaraIcon(icon, size: size * .5, color: fg),
      ),
    );
  }
}

/// Ligne de liste : tuile d'icône, titre, sous-titre, élément à droite.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.detail,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;

  /// Précision posée juste après le titre, en plus discret, sur la même ligne (lieu d'une
  /// livraison) ; coupée par « … » si la ligne est trop courte, le titre restant entier.
  final String? detail;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxTrailing = constraints.maxWidth * .32;
                return Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (detail == null)
                            Text(
                              title,
                              style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                            )
                          else
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: title,
                                    style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text: '  ${detail!}',
                                    style: TaraText.label.copyWith(color: c.textTertiary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: TaraText.small.copyWith(color: c.textTertiary)),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      // Texte agrandi sur petit écran : l'élément de droite rétrécit un peu plutôt
                      // que de couper les noms de quartier au milieu d'un mot.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxTrailing),
                        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille d'information (« ● Nouvelle course · Moto », « Échec · Client absent »).
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label, this.dot, this.blinkDot = false, this.tone, this.icon});

  final String label;
  final Color? dot;
  final bool blinkDot;
  final TintTone? tone;
  final TaraIconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final (bg, border, fg) = switch (tone) {
      TintTone.accent => (c.accentTintBg, c.accentTintBorder, c.accentStrongText),
      TintTone.success => (c.successTintBg, c.successTintBorder, c.success),
      TintTone.danger => (c.dangerTint, c.dangerText.withValues(alpha: .35), c.dangerText),
      null => (c.glassBar, c.glassBorder, c.textPrimary),
    };
    Widget? dotWidget;
    if (dot != null) {
      final d = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      );
      dotWidget = blinkDot
          ? Blink(period: const Duration(milliseconds: 1200), smooth: true, minOpacity: .25, child: d)
          : d;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotWidget != null) ...[dotWidget, const SizedBox(width: 8)],
          if (icon != null) ...[TaraIcon(icon!, size: 16, color: fg), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              style: TaraText.label.copyWith(color: fg, fontWeight: FontWeight.w700, fontFeatures: TaraText.tabular),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau « Hors connexion » (A13) : tuile wifi barré, titre, détail, filet lumineux.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: c.warningBannerBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.warningBannerBorder),
          boxShadow: c.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.warningText.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(child: TaraIcon(TaraIcons.wifiOff, size: 20, color: c.warningText)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TaraText.bodyStrong.copyWith(color: c.textPrimary)),
                          const SizedBox(height: 1),
                          Text(detail, style: TaraText.small.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: FlowingGradient(
                  period: Duration(seconds: 3),
                  colors: [Color(0x00FFB000), TaraBrand.amber, TaraBrand.orange, Color(0x00FF6A00)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Position du livreur : pastille dégradée, bordure blanche, deux pulsations (A6), cône de direction.
class RiderPin extends StatelessWidget {
  const RiderPin({super.key, this.heading});

  /// Cap en degrés ; sans valeur, pas de cône.
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (heading != null)
            Transform.rotate(
              angle: degrees(heading!),
              child: CustomPaint(size: const Size(120, 120), painter: _ConePainter()),
            ),
          PulseRings(
            size: 24,
            color: Color.fromRGBO(255, 106, 0, c.isDark ? .45 : .40),
            from: .6,
            to: 2.6,
            startOpacity: .7,
            period: const Duration(milliseconds: 2400),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: TaraBrand.gradient,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 90, 0, 0.45), blurRadius: 12)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - 26, center.dy - 54)
      ..quadraticBezierTo(center.dx, center.dy - 62, center.dx + 26, center.dy - 54)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(colors: [Color.fromRGBO(255, 138, 0, 0.45), Color.fromRGBO(255, 138, 0, 0)])
            .createShader(Rect.fromCircle(center: center, radius: 60)),
    );
  }

  @override
  bool shouldRepaint(_ConePainter oldDelegate) => false;
}

/// Point d'enlèvement : point orange 9 px, bordure blanche 3, halo.
class PickupPin extends StatelessWidget {
  const PickupPin({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 15,
    height: 15,
    decoration: BoxDecoration(
      color: TaraBrand.orange,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
      boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 106, 0, 0.25), spreadRadius: 8)],
    ),
  );
}

/// Destination : anneau blanc de 5 px autour d'un cœur orange, avec pulsations.
class DestinationPin extends StatelessWidget {
  const DestinationPin({super.key});

  @override
  Widget build(BuildContext context) => PulseRings(
    size: 24,
    color: const Color.fromRGBO(255, 106, 0, 0.35),
    from: .8,
    to: 2.2,
    period: const Duration(milliseconds: 2400),
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: TaraBrand.orange,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 5),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.3), blurRadius: 10, offset: Offset(0, 4))],
      ),
    ),
  );
}

/// Ligne « titre de section » avec lien à droite (Détails, Tout voir).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
        ),
        ?action,
      ],
    );
  }
}

/// Formulaire : contenu qui défile jusqu'en bas de l'écran, sous les actions posées dans un
/// socle en verre flottant (comme la barre d'onglets), au-dessus du clavier. L'écran ne
/// réserve pas la zone système du bas (`TaraScreen(safeBottom: false)`) : le socle s'en
/// écarte lui-même et le contenu y défile. Le bouton
/// principal reste visible même sur un petit écran avec texte agrandi ; le contenu garde
/// assez de marge pour finir au-dessus du socle.
class ScrollWithFooter extends StatefulWidget {
  const ScrollWithFooter({super.key, required this.content, required this.footer, this.horizontal = 24, this.top = 16});

  /// Contenu qui défile, de haut en bas.
  final List<Widget> content;
  final Widget footer;
  final double horizontal;
  final double top;

  /// Marge du socle sous lui et autour du bouton.
  static const dockMargin = 12.0;
  static const dockPadding = 6.0;

  @override
  State<ScrollWithFooter> createState() => _ScrollWithFooterState();
}

class _ScrollWithFooterState extends State<ScrollWithFooter> {
  /// Hauteur du socle, relue après sa mise en page (estimée pour la première image).
  double _footerHeight = 58 + 2 * ScrollWithFooter.dockPadding + ScrollWithFooter.dockMargin;

  @override
  Widget build(BuildContext context) {
    final h = widget.horizontal;
    const pad = ScrollWithFooter.dockPadding;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(h, widget.top, h, _footerHeight + 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.content),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SizeReporter(
              onHeight: (height) {
                if ((height - _footerHeight).abs() > .5) setState(() => _footerHeight = height);
              },
              child: Padding(
                // Sous le socle : la zone système du bas (le contenu y passe aussi).
                padding: EdgeInsets.fromLTRB(
                  h - pad,
                  0,
                  h - pad,
                  ScrollWithFooter.dockMargin + MediaQuery.paddingOf(context).bottom,
                ),
                child: GlassDock(
                  radius: 25 + pad,
                  padding: const EdgeInsets.all(pad),
                  child: SizedBox(width: double.infinity, child: widget.footer),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Donne la hauteur de son enfant après chaque mise en page où elle change.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onHeight = onHeight;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
