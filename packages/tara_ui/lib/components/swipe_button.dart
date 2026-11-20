import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/effects.dart';
import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';

/// Bouton à glisser pour confirmer une action qui engage (accepter une course…) : on fait
/// glisser la pastille orange jusqu'au bout du rail. Une petite vibration marque chaque
/// quart, une franche la confirmation ; relâchée trop tôt, la pastille revient. Un simple
/// toucher la fait frémir pour montrer le geste. Les lecteurs d'écran l'activent d'un
/// double toucher.
class SwipeButton extends StatefulWidget {
  const SwipeButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.semanticLabel,
    this.loading = false,
    this.height = 58,
    this.icon = TaraIcons.arrowRight,
    this.plain = false,
  });

  /// Libellé court sur le rail (« Accepter ») ; les chevrons animés montrent le geste.
  final String label;

  /// Libellé lu par les lecteurs d'écran (« Glisser pour accepter »), [label] sinon.
  final String? semanticLabel;

  /// null : bouton désactivé.
  final VoidCallback? onConfirmed;

  /// Requête en cours après la confirmation : la pastille reste au bout et tourne ; elle
  /// revient au départ quand le chargement s'arrête sans que l'écran change (échec).
  final bool loading;
  final double height;
  final TaraIconData icon;

  /// Style des maquettes de course : rail neutre, consigne centrée (« Glisser pour
  /// accepter »), pastille au double chevron.
  final bool plain;

  /// Part du rail à parcourir pour confirmer.
  static const threshold = .82;

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController(vsync: this);
  static const _pad = 4.0;
  double _travel = 1;
  bool _confirmed = false;
  int _quarter = 0;
  Timer? _reset;

  bool get _enabled => widget.onConfirmed != null;

  @override
  void didUpdateWidget(SwipeButton old) {
    super.didUpdateWidget(old);
    if (old.loading && !widget.loading && _confirmed) _back();
  }

  @override
  void dispose() {
    _reset?.cancel();
    _position.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails details) {
    if (!_enabled || _confirmed) return;
    _position.value = (_position.value + details.primaryDelta! / _travel).clamp(0, 1);
    final quarter = (_position.value * 4).floor();
    if (quarter > _quarter) unawaited(HapticFeedback.selectionClick());
    _quarter = quarter;
  }

  void _release(DragEndDetails details) {
    if (!_enabled || _confirmed) return;
    final flung = (details.primaryVelocity ?? 0) > 1400 && _position.value > .45;
    if (_position.value >= SwipeButton.threshold || flung) {
      unawaited(_confirm());
    } else {
      _back();
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirmed = true);
    unawaited(HapticFeedback.heavyImpact());
    await _position.animateTo(1, duration: const Duration(milliseconds: 140), curve: Curves.easeOut);
    if (!mounted) return;
    widget.onConfirmed?.call();
    // Action immédiate (sans chargement) : la pastille revient d'elle-même.
    _reset = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _confirmed && !widget.loading) _back();
    });
  }

  void _back() {
    _reset?.cancel();
    setState(() {
      _confirmed = false;
      _quarter = 0;
    });
    unawaited(_position.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic));
  }

  /// Toucher sans glisser : la pastille avance un peu puis revient, pour montrer le geste.
  Future<void> _hint() async {
    if (!_enabled || _confirmed || _position.isAnimating) return;
    unawaited(HapticFeedback.selectionClick());
    await _position.animateTo(.18, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    if (!mounted || _confirmed) return;
    await _position.animateTo(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final knob = widget.height - 2 * _pad;
    const radius = 20.0;
    return Semantics(
      button: true,
      enabled: _enabled && !widget.loading,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      onTap: _enabled && !_confirmed ? () => unawaited(_confirm()) : null,
      child: GestureDetector(
        onHorizontalDragUpdate: _drag,
        onHorizontalDragEnd: _release,
        onTap: () => unawaited(_hint()),
        child: Opacity(
          opacity: _enabled ? 1 : .45,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _travel = math.max(1, constraints.maxWidth - knob - 2 * _pad);
              return Container(
                height: widget.height,
                decoration: widget.plain
                    ? BoxDecoration(
                        color: c.textPrimary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(radius),
                      )
                    : BoxDecoration(
                        gradient: c.chipSelected,
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(color: c.chipSelectedBorder, width: c.chipSelectedBorderWidth),
                      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius - 1),
                  child: AnimatedBuilder(
                    animation: _position,
                    builder: (context, _) {
                      final t = _position.value;
                      final left = _pad + _travel * t;
                      return Stack(
                        children: [
                          // Traînée orange derrière la pastille.
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: left + knob + _pad,
                            child: Opacity(
                              opacity: (t * 1.4).clamp(0, 1),
                              child: const DecoratedBox(decoration: BoxDecoration(gradient: TaraBrand.gradient)),
                            ),
                          ),
                          if (_enabled && t == 0 && !widget.plain) Sheen(opacity: c.isDark ? .35 : .5),
                          Positioned.fill(
                            left: knob + _pad + 8,
                            right: 12,
                            child: Opacity(
                              opacity: (1 - t * 1.8).clamp(0, 1),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.label,
                                        maxLines: 1,
                                        style: widget.plain
                                            ? TaraText.bodyStrong.copyWith(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: c.textPrimary,
                                              )
                                            : TaraText.buttonStrong.copyWith(color: c.accentText),
                                      ),
                                      if (!widget.plain) ...[const SizedBox(width: 8), _Chevrons(color: c.accentText)],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: left,
                            top: _pad,
                            child: Container(
                              width: knob,
                              height: knob,
                              decoration: BoxDecoration(
                                gradient: TaraBrand.gradient,
                                borderRadius: BorderRadius.circular(widget.plain ? 16 : radius - _pad),
                                boxShadow: widget.plain ? null : c.brandShadow,
                              ),
                              child: Center(
                                child: widget.loading
                                    ? const Spin(
                                        period: Duration(milliseconds: 900),
                                        child: TaraIcon(
                                          TaraIcons.refresh,
                                          size: 22,
                                          strokeWidth: 2.4,
                                          color: TaraBrand.onBrand,
                                        ),
                                      )
                                    : TaraIcon(
                                        _confirmed
                                            ? TaraIcons.check
                                            : (widget.plain ? TaraIcons.chevronsRight : widget.icon),
                                        size: widget.plain && !_confirmed ? 22 : 24,
                                        strokeWidth: 2.4,
                                        color: TaraBrand.onBrand,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Trois chevrons qui s'allument tour à tour, vers la droite : le sens du geste.
class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder(
      period: const Duration(milliseconds: 1400),
      stillPhase: .99,
      builder: (context, t, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Opacity(
              opacity: .25 + .75 * _pulse(t, i),
              child: TaraIcon(TaraIcons.chevronRight, size: 16, strokeWidth: 2.6, color: color),
            ),
        ],
      ),
    );
  }

  /// Chaque chevron s'allume un tiers de période après le précédent.
  static double _pulse(double t, int i) {
    final phase = (t - i / 3) % 1;
    return phase < .5 ? math.sin(phase * 2 * math.pi).abs() : 0;
  }
}
