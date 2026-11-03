import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/effects.dart';
import '../motion/liquid_wave.dart';
import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'glass.dart';

/// Pilule « En ligne » de l'accueil (A8) : point de statut, libellé, interrupteur dégradé
/// dont le bouton blanc ondule. Un toucher fait passer hors ligne.
class OnlineToggle extends StatefulWidget {
  const OnlineToggle({super.key, required this.label, required this.semanticLabel, required this.onToggle});

  final String label;
  final String semanticLabel;
  final VoidCallback onToggle;

  @override
  State<OnlineToggle> createState() => _OnlineToggleState();
}

class _OnlineToggleState extends State<OnlineToggle> {
  bool _leaving = false;

  void _tap() {
    HapticFeedback.mediumImpact();
    setState(() => _leaving = true);
    // Déplacement de 300 ms avec étirement, puis passage hors ligne.
    Timer(const Duration(milliseconds: 300), widget.onToggle);
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      toggled: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _leaving ? null : _tap,
        child: GlassCard(
          radius: 22,
          fill: c.glassBar,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(16, 9, 9, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: c.online,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.online.withValues(alpha: .55), blurRadius: 8, spreadRadius: 1)],
                ),
              ),
              const SizedBox(width: 9),
              Text(widget.label, style: TaraText.bodyStrong.copyWith(color: c.textPrimary)),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(19)),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: _leaving ? Alignment.centerLeft : Alignment.centerRight,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _leaving ? 1 : 0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, stretch, _) => Transform.scale(
                      scaleX: 1 + .15 * math.sin(stretch * math.pi),
                      child: MotionBuilder(
                        period: const Duration(milliseconds: 2400),
                        builder: (context, t, _) {
                          final w = Curves.easeInOut.transform(t < .5 ? t * 2 : (1 - t) * 2);
                          double r(double from, double to) => 15 * (from + (to - from) * w) / .5;
                          return Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.elliptical(r(.5, .46), r(.5, .54)),
                                topRight: Radius.elliptical(r(.5, .54), r(.5, .46)),
                                bottomRight: Radius.elliptical(r(.5, .50), r(.5, .54)),
                                bottomLeft: Radius.elliptical(r(.5, .50), r(.5, .46)),
                              ),
                              boxShadow: const [
                                BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton rond « Passer en ligne » (210 px) : verre, vague liquide basse (A2), deux ondes (A6).
class PowerButton extends StatelessWidget {
  const PowerButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 210,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onPressed!();
              },
        child: PulseRings(
          size: size,
          color: c.isDark ? const Color.fromRGBO(255, 138, 0, 0.55) : const Color.fromRGBO(255, 106, 0, 0.6),
          strokeWidth: 1.5,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.isDark ? const Color.fromRGBO(0, 0, 0, 0.5) : const Color.fromRGBO(140, 70, 10, 0.18),
                  blurRadius: 60,
                  offset: const Offset(0, 30),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: GlassCard(
                      radius: size / 2,
                      shadow: false,
                      padding: EdgeInsets.zero,
                      fill: c.isDark
                          ? const Color.fromRGBO(255, 255, 255, 0.07)
                          : const Color.fromRGBO(255, 255, 255, 0.62),
                      border: c.isDark
                          ? const Color.fromRGBO(255, 255, 255, 0.18)
                          : const Color.fromRGBO(255, 255, 255, 0.95),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Surface à 138 px sur 210 dans la maquette.
                  Positioned.fill(
                    child: LiquidFill(
                      level: .35,
                      front: TaraBrand.verticalGradient,
                      back: c.isDark ? const Color.fromRGBO(255, 61, 0, 0.45) : const Color.fromRGBO(255, 106, 0, 0.35),
                      frontPeriod: const Duration(seconds: 6),
                      backPeriod: const Duration(seconds: 9),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TaraIcon(TaraIcons.power, size: 40, strokeWidth: 2.2, color: c.textPrimary),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TaraText.cardTitle.copyWith(fontSize: 18, color: c.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compte à rebours de la proposition (A3) : anneau dégradé, disque de verre et niveau de
/// liquide égal au temps restant, chiffre géant. Le niveau change même sans animation.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.total,
    required this.unitLabel,
    required this.semanticLabel,
    this.size = 236,
  });

  final int remaining;
  final int total;
  final String unitLabel;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final ratio = total == 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    return Semantics(
      liveRegion: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              builder: (context, v, _) => CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(progress: v, track: c.track),
              ),
            ),
            // Disque intérieur : toute la surface sous l'anneau, pas la taille du chiffre.
            Positioned.fill(
              left: 14,
              top: 14,
              right: 14,
              bottom: 14,
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: GlassCard(
                        radius: size,
                        shadow: false,
                        padding: EdgeInsets.zero,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned.fill(
                      child: LiquidFill(
                        level: ratio,
                        levelDuration: const Duration(seconds: 1),
                        front: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                          stops: [0, .18, .5],
                        ),
                        back: c.isDark
                            ? const Color.fromRGBO(255, 61, 0, 0.5)
                            : const Color.fromRGBO(255, 106, 0, 0.35),
                        frontPeriod: const Duration(seconds: 5),
                        backPeriod: const Duration(seconds: 8),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$remaining',
                          style: TaraText.giantNumber.copyWith(
                            color: c.textPrimary,
                            shadows: [
                              c.isDark
                                  ? const Shadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.35),
                                      blurRadius: 20,
                                      offset: Offset(0, 4),
                                    )
                                  : const Shadow(color: Color.fromRGBO(255, 255, 255, 0.8), blurRadius: 12),
                            ],
                          ),
                        ),
                        Text(unitLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track});

  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = TaraBrand.gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track;
}

/// Bouton SOS à maintenir 3 s (A15) : le liquide rouge monte (+1/12 toutes les 250 ms) ;
/// relâché trop tôt, il redescend. À 100 %, l'alerte part (vibration forte).
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.sent,
    required this.onSent,
    required this.idleHint,
    required this.holdingHint,
    required this.sentHint,
    required this.semanticLabel,
    this.size = 236,
  });

  final bool sent;
  final VoidCallback onSent;
  final String idleHint;
  final String Function(int secondsLeft) holdingHint;
  final String sentHint;
  final String semanticLabel;
  final double size;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton> {
  static const _steps = 12;
  int _step = 0;
  Timer? _timer;

  void _start() {
    if (widget.sent || _timer != null) return;
    HapticFeedback.lightImpact();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      setState(() => _step++);
      if (_step >= _steps) {
        timer.cancel();
        _timer = null;
        HapticFeedback.heavyImpact();
        widget.onSent();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (!widget.sent && _step < _steps) setState(() => _step = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final level = widget.sent ? 1.0 : _step / _steps;
    final holding = _step > 0 && !widget.sent;
    final secondsLeft = math.max(1, (3 - level * 3).ceil());
    final hint = widget.sent ? widget.sentHint : (holding ? widget.holdingHint(secondsLeft) : widget.idleHint);
    final dark = c.isDark;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      // Lecteur d'écran : un appui long déclenche l'alerte sans maintien chronométré.
      onLongPress: widget.sent ? null : widget.onSent,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: PulseRings(
          size: widget.size,
          color: dark ? const Color.fromRGBO(255, 77, 90, 0.6) : const Color.fromRGBO(229, 37, 53, 0.55),
          strokeWidth: 2,
          from: .95,
          to: 1.5,
          startOpacity: .9,
          period: const Duration(milliseconds: 2200),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: dark
                  ? null
                  : const LinearGradient(
                      begin: Alignment(-0.34, -0.94),
                      end: Alignment(0.34, 0.94),
                      colors: [Color(0xFFFF5A66), TaraBrand.sos, Color(0xFFC81E2C)],
                      stops: [0, .55, 1],
                    ),
              color: dark ? const Color.fromRGBO(229, 37, 53, 0.16) : null,
              border: Border.all(
                color: dark ? const Color.fromRGBO(255, 154, 162, 0.55) : const Color.fromRGBO(255, 255, 255, 0.9),
                width: dark ? 2 : 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: dark ? const Color.fromRGBO(179, 18, 31, 0.45) : const Color.fromRGBO(200, 30, 44, 0.35),
                  blurRadius: 60,
                  offset: const Offset(0, 30),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: LiquidFill(
                      level: level,
                      levelDuration: const Duration(milliseconds: 250),
                      front: dark
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFF4D5A), TaraBrand.sos, Color(0xFFB3121F)],
                              stops: [0, .3, 1],
                            )
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFA50F1C), Color(0xFF8F0E19), Color(0xFF6E0A13)],
                              stops: [0, .4, 1],
                            ),
                      back: dark ? const Color.fromRGBO(179, 18, 31, 0.7) : const Color.fromRGBO(120, 8, 18, 0.45),
                      frontPeriod: const Duration(seconds: 4),
                      backPeriod: const Duration(seconds: 7),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SOS', style: TaraText.sos.copyWith(color: const Color(0xFFFFFFFF))),
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        style: TaraText.label.copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
