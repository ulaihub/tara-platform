import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../tara_effects.dart';

/// Horloge partagée par toutes les animations décoratives d'un écran (§5.4) : un seul
/// `Ticker`, arrêté quand l'app passe en arrière-plan, quand l'écran n'est plus visible
/// (TickerMode) ou quand le téléphone demande de réduire les animations.
class MotionClock extends StatefulWidget {
  const MotionClock({super.key, required this.child, this.initialOffset = Duration.zero});

  final Widget child;

  /// Décalage de départ (captures d'écran reproductibles, phases variées).
  final Duration initialOffset;

  /// Temps écoulé de l'horloge la plus proche ; immobile à zéro s'il n'y en a pas.
  static ValueListenable<Duration> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionScope>()?.time ?? _still;

  static final ValueNotifier<Duration> _still = ValueNotifier(Duration.zero);

  @override
  State<MotionClock> createState() => _MotionClockState();
}

class _MotionClockState extends State<MotionClock> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ValueNotifier<Duration> _time = ValueNotifier(widget.initialOffset);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _base = Duration.zero;
  bool _resumed = true;

  void _onTick(Duration elapsed) => _time.value = _base + elapsed;

  @override
  void initState() {
    super.initState();
    _base = widget.initialOffset;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final run = _resumed && TaraEffects.of(context).decorativeMotion;
    if (run && !_ticker.isActive) {
      _base = _time.value;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MotionScope(time: _time, child: widget.child);
}

class _MotionScope extends InheritedWidget {
  const _MotionScope({required this.time, required super.child});

  final ValueListenable<Duration> time;

  @override
  bool updateShouldNotify(_MotionScope oldWidget) => oldWidget.time != time;
}

/// Reconstruit `builder` à chaque image avec la phase `t ∈ [0, 1)` d'un cycle de `period`.
/// Sans mouvement (réglage du téléphone, horloge absente), `t` reste à `stillPhase`.
class MotionBuilder extends StatelessWidget {
  const MotionBuilder({
    super.key,
    required this.period,
    required this.builder,
    this.delay = Duration.zero,
    this.stillPhase = 0,
    this.child,
  });

  final Duration period;

  /// Décalage de phase (équivalent de `animation-delay` négatif).
  final Duration delay;
  final double stillPhase;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!TaraEffects.of(context).decorativeMotion) return builder(context, stillPhase, child);
    return ValueListenableBuilder<Duration>(
      valueListenable: MotionClock.of(context),
      child: child,
      builder: (context, time, child) {
        final micros = (time + delay).inMicroseconds % period.inMicroseconds;
        return builder(context, micros / period.inMicroseconds, child);
      },
    );
  }
}
