import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tara_colors.dart';
import '../tara_effects.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'glass.dart';

/// Onglet de la barre flottante.
@immutable
class TabItem {
  const TabItem(this.icon, this.label);
  final TaraIconData icon;
  final String label;
}

/// Barre d'onglets flottante en verre clair (glassmorphisme) : le contenu passe dessous,
/// flouté et aux couleurs avivées ; une lentille de verre teintée glisse vers l'onglet
/// choisi avec un léger rebond. Effets réduits : surface opaque sans flou ; animations
/// réduites : la lentille se déplace sans transition.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({super.key, required this.items, required this.current, required this.onSelected});

  final List<TabItem> items;
  final int current;
  final ValueChanged<int> onSelected;

  /// Hauteur de la barre et marge sous elle (hors zone système).
  static const barHeight = 64.0;
  static const bottomMargin = 12.0;
  static const height = barHeight + bottomMargin;

  static const _radius = 28.0;
  static const _elastic = Cubic(0.6, -0.35, 0.3, 1.45);

  @override
  Widget build(BuildContext context) {
    final effects = TaraEffects.of(context);
    // Posée au-dessus des écrans : sans ce Material transparent, ses textes n'auraient pas
    // de style de base (soulignés en jaune par Flutter).
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, bottomMargin),
        child: GlassDock(
          radius: _radius,
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: barHeight - 12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: effects.decorativeMotion ? const Duration(milliseconds: 520) : Duration.zero,
                      curve: _elastic,
                      left: width * current,
                      top: 0,
                      bottom: 0,
                      width: width,
                      child: const _Lens(),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _TabButton(item: items[i], selected: i == current, onTap: () => onSelected(i)),
                          ),
                      ],
                    ),
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

/// Lentille de verre teintée sous l'onglet choisi : dégradé orange léger, bord clair.
class _Lens extends StatelessWidget {
  const _Lens();

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(255, 176, 0, c.isDark ? .24 : .26),
            Color.fromRGBO(255, 106, 0, c.isDark ? .14 : .14),
          ],
        ),
        border: Border.all(color: c.glassHighlight.withValues(alpha: c.isDark ? .22 : .9)),
        boxShadow: [BoxShadow(color: Color.fromRGBO(255, 106, 0, c.isDark ? .22 : .16), blurRadius: 18)],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.item, required this.selected, required this.onTap});
  final TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final color = selected ? c.accentText : c.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TaraIcon(item.icon, size: 22, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TaraText.overline.copyWith(
                  letterSpacing: 0,
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Écrans à onglets : le contenu occupe tout l'écran et défile sous la barre en verre ;
/// le changement d'onglet passe par une transition vitrée ([GlassTabSwitcher]). Les listes
/// réservent [bottomInset] en bas pour que leur dernier élément dépasse la barre. Un
/// sous-écran plein écran ouvert dans un onglet (recharge, pièces…) masque la barre en
/// s'enveloppant de [HideTabBar].
class TaraTabShell extends StatefulWidget {
  const TaraTabShell({
    super.key,
    required this.items,
    required this.current,
    required this.onSelected,
    required this.child,
    this.showBar = true,
  });

  final List<TabItem> items;
  final int current;
  final ValueChanged<int> onSelected;

  /// Écran de l'onglet courant (changé à chaque onglet).
  final Widget child;

  /// Barre masquée (écran plein, comme une course en cours).
  final bool showBar;

  /// Place à laisser en bas d'une liste pour qu'elle défile entièrement au-dessus de la
  /// barre ; 0 hors d'un écran à onglets.
  static double bottomInset(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TabInset>()?.inset ?? 0;

  @override
  State<TaraTabShell> createState() => _TaraTabShellState();
}

class _TaraTabShellState extends State<TaraTabShell> {
  /// Sous-écrans ouverts qui masquent la barre.
  final _hiders = <Object>{};

  void _setHidden(Object owner, {required bool hidden}) {
    if (!mounted) return;
    setState(() => hidden ? _hiders.add(owner) : _hiders.remove(owner));
  }

  @override
  Widget build(BuildContext context) {
    final effects = TaraEffects.of(context);
    final inset = widget.showBar ? FloatingTabBar.height + MediaQuery.paddingOf(context).bottom : 0.0;
    final visible = widget.showBar && _hiders.isEmpty;
    final duration = effects.decorativeMotion ? const Duration(milliseconds: 260) : Duration.zero;
    return Stack(
      children: [
        Positioned.fill(
          child: _TabInset(
            inset: inset,
            shell: this,
            child: GlassTabSwitcher(
              child: KeyedSubtree(key: ValueKey(widget.current), child: widget.child),
            ),
          ),
        ),
        if (widget.showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, 1.2),
                duration: duration,
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: duration,
                  child: SafeArea(
                    top: false,
                    child: FloatingTabBar(items: widget.items, current: widget.current, onSelected: widget.onSelected),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TabInset extends InheritedWidget {
  const _TabInset({required this.inset, required this.shell, required super.child});
  final double inset;
  final _TaraTabShellState shell;

  @override
  bool updateShouldNotify(_TabInset oldWidget) => oldWidget.inset != inset;
}

/// Sous-écran plein écran ouvert dans un onglet : tant qu'il est affiché, la barre
/// d'onglets se retire (glisse vers le bas).
class HideTabBar extends StatefulWidget {
  const HideTabBar({super.key, required this.child});

  final Widget child;

  @override
  State<HideTabBar> createState() => _HideTabBarState();
}

class _HideTabBarState extends State<HideTabBar> {
  _TaraTabShellState? _shell;

  @override
  void initState() {
    super.initState();
    // Après la construction : la barre ne peut pas changer pendant que l'arbre se bâtit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _shell = context.getInheritedWidgetOfExactType<_TabInset>()?.shell;
      _shell?._setHidden(this, hidden: true);
    });
  }

  @override
  void dispose() {
    final shell = _shell;
    if (shell != null) WidgetsBinding.instance.addPostFrameCallback((_) => shell._setHidden(this, hidden: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Transition vitrée entre deux onglets : l'écran qui part se floute et s'efface, celui
/// qui arrive sort du flou en se posant (léger zoom), un reflet de verre le traverse.
/// Effets réduits : fondu seul ; animations réduites : changement immédiat.
class GlassTabSwitcher extends StatelessWidget {
  const GlassTabSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effects = TaraEffects.of(context);
    return AnimatedSwitcher(
      duration: effects.decorativeMotion ? const Duration(milliseconds: 420) : Duration.zero,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => _GlassTransition(animation: animation, blur: effects.blur, child: child),
      child: child,
    );
  }
}

class _GlassTransition extends AnimatedWidget {
  const _GlassTransition({required Animation<double> animation, required this.blur, required this.child})
    : super(listenable: animation);

  final bool blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value.clamp(0.0, 1.0);
    final c = TaraColors.of(context);
    final sigma = (1 - t) * 14;
    // Structure fixe (le flou est seulement désactivé) : l'écran garde son état.
    return Opacity(
      opacity: t,
      child: Transform.scale(
        scale: .97 + .03 * t,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            ImageFiltered(
              enabled: blur && sigma > .2,
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
            // Reflet de verre qui balaie l'écran pendant la transition.
            if (blur)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: math.sin(math.pi * t) * .7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.6 + 2.4 * t, -1),
                          end: Alignment(-.6 + 2.4 * t, 1),
                          colors: [
                            c.glassHighlight.withValues(alpha: 0),
                            c.glassHighlight.withValues(alpha: c.isDark ? .10 : .30),
                            c.glassHighlight.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
