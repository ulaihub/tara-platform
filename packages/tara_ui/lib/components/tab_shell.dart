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

/// Bouton d'action posé au centre de la barre, en relief au-dessus d'elle (« + » :
/// nouvelle livraison). Ce n'est pas un onglet : il ouvre un écran.
@immutable
class TabAction {
  const TabAction({required this.icon, required this.label, required this.onPressed});
  final TaraIconData icon;

  /// Lu par le lecteur d'écran (« Nouvelle livraison »).
  final String label;
  final VoidCallback onPressed;
}

/// Barre d'onglets flottante en verre clair (glassmorphisme) : le contenu passe dessous,
/// flouté et aux couleurs avivées ; un trait au dégradé de la marque glisse au-dessus de l'onglet
/// choisi avec un léger rebond. Effets réduits : surface opaque sans flou ; animations
/// réduites : le trait se déplace sans transition.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.current,
    required this.onSelected,
    this.action,
    this.pill = false,
  });

  final List<TabItem> items;
  final int current;
  final ValueChanged<int> onSelected;

  /// Bouton central en relief, entre la première et la seconde moitié des onglets.
  final TabAction? action;

  /// Barre fine en pilule (app livreur) : icônes seules, l'onglet choisi devient une
  /// pastille sombre avec son nom, qui glisse et s'élargit.
  final bool pill;

  /// Hauteur de la barre fine et place totale qu'elle prend (hors zone système).
  static const pillBarHeight = 50.0;
  static const pillHeight = pillBarHeight + bottomMargin;

  /// Place à réserver sous les listes selon le style de barre.
  static double heightOf({required bool pill}) => pill ? pillHeight : height;

  /// Hauteur de la barre et marge sous elle (hors zone système).
  static const barHeight = 74.0;
  static const bottomMargin = 14.0;
  static const height = barHeight + bottomMargin;

  static const _radius = 26.0;
  static const _elastic = Cubic(0.6, -0.35, 0.3, 1.45);

  @override
  Widget build(BuildContext context) {
    if (pill) return _PillTabBar(items: items, current: current, onSelected: onSelected);
    final effects = TaraEffects.of(context);
    // Posée au-dessus des écrans : sans ce Material transparent, ses textes n'auraient pas
    // de style de base (soulignés en jaune par Flutter).
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, bottomMargin),
        child: GlassDock(
          radius: _radius,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: SizedBox(
            height: barHeight - 16,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final center = action == null ? null : items.length ~/ 2;
                final slots = items.length + (center == null ? 0 : 1);
                final width = constraints.maxWidth / slots;
                int slotOf(int tab) => center != null && tab >= center ? tab + 1 : tab;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Trait au dégradé de la marque au-dessus de l'onglet choisi (maquette).
                    AnimatedPositioned(
                      duration: effects.decorativeMotion ? const Duration(milliseconds: 520) : Duration.zero,
                      curve: _elastic,
                      left: width * slotOf(current) + (width - 20) / 2,
                      top: -8,
                      width: 20,
                      height: 4,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: TaraBrand.gradient,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i == center) Expanded(child: _CenterAction(action: action!)),
                          Expanded(
                            child: _TabButton(item: items[i], selected: i == current, onTap: () => onSelected(i)),
                          ),
                        ],
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

/// Barre fine en pilule : verre clair ajusté aux onglets, centré ; l'onglet choisi est une
/// pastille sombre (claire en thème sombre) avec icône et nom, les autres une icône seule.
class _PillTabBar extends StatelessWidget {
  const _PillTabBar({required this.items, required this.current, required this.onSelected});

  final List<TabItem> items;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.only(bottom: FloatingTabBar.bottomMargin),
        child: Center(
          child: GlassDock(
            radius: FloatingTabBar.pillBarHeight / 2,
            padding: const EdgeInsets.all(5),
            child: SizedBox(
              height: FloatingTabBar.pillBarHeight - 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _PillTab(item: items[i], selected: i == current, onTap: () => onSelected(i)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({required this.item, required this.selected, required this.onTap});
  final TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    final duration = effects.decorativeMotion ? const Duration(milliseconds: 320) : Duration.zero;
    // Pastille choisie : encre du thème (sombre en clair, claire en sombre), texte inversé.
    final fill = c.textPrimary;
    final ink = selected ? c.bg : c.textPrimary.withValues(alpha: .62);
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
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 52),
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 14),
          decoration: BoxDecoration(
            color: selected ? fill : fill.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TaraIcon(item.icon, size: 20, strokeWidth: selected ? 2 : 1.8, color: ink),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    maxLines: 1,
                    style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « + » en relief au centre de la barre : disque au dégradé de la marque qui
/// dépasse au-dessus du verre, ombre orange, léger enfoncement au toucher.
class _CenterAction extends StatefulWidget {
  const _CenterAction({required this.action});
  final TabAction action;

  @override
  State<_CenterAction> createState() => _CenterActionState();
}

class _CenterActionState extends State<_CenterAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    const size = 58.0;
    return Semantics(
      button: true,
      label: widget.action.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.action.onPressed();
        },
        child: OverflowBox(
          maxHeight: size + 20,
          child: Transform.translate(
            offset: const Offset(0, -14),
            child: AnimatedScale(
              scale: _down ? .92 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: TaraBrand.gradient,
                  boxShadow: const [
                    BoxShadow(color: Color.fromRGBO(255, 90, 0, .38), blurRadius: 26, offset: Offset(0, 12)),
                  ],
                ),
                child: Center(
                  child: TaraIcon(widget.action.icon, size: 26, strokeWidth: 2.4, color: TaraBrand.onBrand),
                ),
              ),
            ),
          ),
        ),
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
            // Onglet choisi : icône en dégradé de la marque, trait plus épais (maquette).
            if (selected)
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                  stops: [0, .55, 1],
                ).createShader(bounds),
                child: TaraIcon(item.icon, size: 24, strokeWidth: 2, color: const Color(0xFFFFFFFF)),
              )
            else
              TaraIcon(item.icon, size: 24, strokeWidth: 1.8, color: c.textPrimary.withValues(alpha: .66)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TaraText.overline.copyWith(
                  letterSpacing: 0,
                  fontSize: 11,
                  color: selected ? color : c.textPrimary.withValues(alpha: .66),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
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
    this.action,
    this.pill = false,
  });

  /// Barre fine en pilule (voir [FloatingTabBar.pill]).
  final bool pill;

  final List<TabItem> items;
  final int current;
  final ValueChanged<int> onSelected;

  /// Bouton central en relief (« + » : nouvelle livraison).
  final TabAction? action;

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
    final inset = widget.showBar
        ? FloatingTabBar.heightOf(pill: widget.pill) + MediaQuery.paddingOf(context).bottom
        : 0.0;
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
                    child: FloatingTabBar(
                      items: widget.items,
                      current: widget.current,
                      onSelected: widget.onSelected,
                      action: widget.action,
                      pill: widget.pill,
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
