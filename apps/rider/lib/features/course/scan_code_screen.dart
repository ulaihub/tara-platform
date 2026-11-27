import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tara_core/codes/pickup_qr.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Source des codes lus : la caméra du téléphone (MobileScanner) ; remplacée dans les tests.
/// Elle appelle [onCode] à chaque QR lu, [onUnavailable] si la caméra est refusée ou absente.
typedef CodeSource = Widget Function(
  BuildContext context, {
  required ValueChanged<String> onCode,
  required VoidCallback onUnavailable,
});

/// Lampe de la caméra : allumée ou éteinte par l'écran de scan.
class TorchSwitch {
  MobileScannerController? controller;
  Future<void> toggle() async => controller?.toggleTorch();
}

final codeSourceProvider = Provider<CodeSource>((ref) => _cameraSource);

Widget _cameraSource(
  BuildContext context, {
  required ValueChanged<String> onCode,
  required VoidCallback onUnavailable,
}) => _Camera(onCode: onCode, onUnavailable: onUnavailable);

class _Camera extends StatefulWidget {
  const _Camera({required this.onCode, required this.onUnavailable});
  final ValueChanged<String> onCode;
  final VoidCallback onUnavailable;

  @override
  State<_Camera> createState() => _CameraState();
}

class _CameraState extends State<_Camera> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void initState() {
    super.initState();
    _ScanCodeScreenState._torch.controller = _controller;
  }

  @override
  void dispose() {
    _ScanCodeScreenState._torch.controller = null;
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: (capture) {
      for (final code in capture.barcodes) {
        if (code.rawValue case final raw?) widget.onCode(raw);
      }
    },
    errorBuilder: (context, error) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onUnavailable());
      return const ColoredBox(color: Color(0xFF14100D));
    },
  );
}

/// Lecture du QR du code d'enlèvement (maquette Scanner) : cadre de visée orange, vert une
/// fois le code lu. Le QR doit être celui de cette course (référence) ; « Taper les 4
/// chiffres » reste toujours possible. Renvoie le code lu, ou null.
class ScanCodeScreen extends ConsumerStatefulWidget {
  const ScanCodeScreen({super.key, required this.references, required this.context, required this.parcels});

  /// Références acceptées : celle de la course, ou celles des colis d'une tournée.
  final List<String> references;

  /// Sous le cadre : « Boutique Awa · colis n° 4, 9 et 12 ».
  final String context;

  /// Colis concernés (tournée) : annoncés une fois le code lu.
  final int parcels;

  @override
  ConsumerState<ScanCodeScreen> createState() => _ScanCodeScreenState();
}

class _ScanCodeScreenState extends ConsumerState<ScanCodeScreen> {
  static final _torch = TorchSwitch();

  String? _code;
  String? _problem;
  bool _torchOn = false;

  void _read(String raw) {
    if (_code != null) return;
    final l = AppLocalizations.of(context);
    for (final reference in widget.references) {
      if (pickupCodeFromQr(raw, reference: reference) case final code?) {
        TaraFeedback.play(context, TaraSound.received);
        setState(() {
          _code = code;
          _problem = null;
        });
        return;
      }
    }
    final problem = isPickupQr(raw) ? l.scanWrongOrder : l.scanNotTara;
    if (problem != _problem) setState(() => _problem = problem);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ok = _code != null;
    final corner = ok ? const Color(0xFF4ADE9B) : const Color(0xFFFF8A3D);
    final source = ref.watch(codeSourceProvider);
    const white = Colors.white;
    return Scaffold(
      backgroundColor: const Color(0xFF14100D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          source(
            context,
            onCode: _read,
            onUnavailable: () {
              if (mounted) setState(() => _problem = l.scanNoCamera);
            },
          ),
          // Voile sombre autour du cadre de visée.
          LayoutBuilder(
            builder: (context, box) {
              final frame = Rect.fromLTWH((box.maxWidth - 250) / 2, 190, 250, 250);
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _VeilPainter(frame))),
                  Positioned.fromRect(
                    rect: frame,
                    child: Semantics(
                      label: ok ? l.scanOk : l.scanAimPickup,
                      liveRegion: true,
                      child: CustomPaint(
                        painter: _CornersPainter(corner),
                        child: ok
                            ? Center(
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: const BoxDecoration(color: Color(0xFF10A06E), shape: BoxShape.circle),
                                  child: const Center(
                                    child: TaraIcon(TaraIcons.check, size: 44, strokeWidth: 3, color: white),
                                  ),
                                ),
                              )
                            : const _ScanLine(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: frame.bottom + 22,
                    child: Column(
                      children: [
                        Text(
                          ok ? l.scanOk : (_problem ?? l.scanAimPickup),
                          textAlign: TextAlign.center,
                          style: TaraText.text.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ok
                                ? const Color(0xFF4ADE9B)
                                : _problem == null
                                ? white
                                : const Color(0xFFFFB15C),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: white.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: white.withValues(alpha: .14)),
                          ),
                          child: Text(
                            widget.context,
                            textAlign: TextAlign.center,
                            style: TaraText.small.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: white.withValues(alpha: .86),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // En-tête : retour, titre, lampe.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const TaraIcon(TaraIcons.chevronLeft, size: 22, color: white),
                    ),
                    Expanded(
                      child: Text(
                        l.scanTitlePickup,
                        textAlign: TextAlign.center,
                        style: TaraText.text.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: white),
                      ),
                    ),
                    IconButton(
                      tooltip: l.scanTorch,
                      isSelected: _torchOn,
                      onPressed: () {
                        setState(() => _torchOn = !_torchOn);
                        unawaited(_torch.toggle().catchError((Object _) {}));
                      },
                      icon: TaraIcon(TaraIcons.bolt, size: 22, color: _torchOn ? const Color(0xFFFFB000) : white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Feuille du bas : aide et « Taper les 4 chiffres », ou le code vérifié.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(22, 22, 30, .92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: white.withValues(alpha: .10))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: ok
                    ? [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const TaraIcon(TaraIcons.check, size: 18, color: Color(0xFF4ADE9B)),
                            const SizedBox(width: 8),
                            Text(
                              widget.parcels > 1 ? l.scanVerifiedParcels(widget.parcels) : l.scanVerified,
                              style: TaraText.label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4ADE9B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(label: l.scanContinue, onPressed: () => Navigator.of(context).pop(_code)),
                      ]
                    : [
                        Text(
                          l.scanHelperPickup,
                          textAlign: TextAlign.center,
                          style: TaraText.small.copyWith(
                            fontSize: 13,
                            height: 1.45,
                            color: white.withValues(alpha: .74),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            foregroundColor: white,
                            side: BorderSide(color: white.withValues(alpha: .18)),
                            backgroundColor: white.withValues(alpha: .06),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          icon: const TaraIcon(TaraIcons.keypad, size: 18, color: white),
                          label: Text(
                            l.scanTypeDigits,
                            style: TaraText.text.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: white),
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

class _VeilPainter extends CustomPainter {
  _VeilPainter(this.frame);
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(30)));
    canvas.drawPath(path, Paint()..color = const Color.fromRGBO(6, 5, 8, .66));
  }

  @override
  bool shouldRepaint(_VeilPainter old) => old.frame != frame;
}

/// Quatre coins arrondis du cadre de visée.
class _CornersPainter extends CustomPainter {
  _CornersPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const r = 30.0;
    const len = 46.0;
    final w = size.width;
    final h = size.height;
    void corner(Offset a, Offset b, Offset c) {
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..arcToPoint(b, radius: const Radius.circular(r), clockwise: true)
          ..lineTo(c.dx, c.dy),
        paint,
      );
    }

    canvas
      ..drawLine(const Offset(0, len), const Offset(0, r), paint)
      ..drawLine(Offset(w, h - len), Offset(w, h - r), paint);
    corner(const Offset(0, r), const Offset(r, 0), const Offset(len, 0));
    corner(Offset(w - r, 0), Offset(w, r), Offset(w, len));
    corner(Offset(w, h - r), Offset(w - r, h), Offset(w - len, h));
    corner(Offset(r, h), Offset(0, h - r), Offset(0, h - len));
    canvas.drawLine(Offset(w - len, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(len, h), Offset(r, h), paint);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}

/// Ligne lumineuse qui balaie le cadre pendant la recherche.
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Align(
      alignment: Alignment(0, -0.88 + 1.76 * _controller.value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            colors: [Color(0x00FF8A00), Color(0xFFFFB000), Color(0xFFFF6A00), Color(0x00FF3D00)],
            stops: [0, .3, .7, 1],
          ),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 106, 0, .55), blurRadius: 18, spreadRadius: 4)],
        ),
      ),
    ),
  );
}
