import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/brand.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/operator_logo.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/card_decor.dart';
import '../common/pin.dart';

/// Cartes du portefeuille (maquette Portefeuille) : la carte sombre « Ventes à recevoir »
/// et la carte claire « Solde Tara », l'une derrière l'autre en perspective. On touche
/// la carte de derrière : elle bascule devant (l'autre s'écarte vers la gauche en
/// tournant, puis repasse derrière). Le groupe s'incline sous le doigt et un reflet suit
/// le doigt. Chaque carte vit : filigrane du logo qui flotte, trajet en pointillé où
/// voyage un point lumineux, traits de vitesse, reflet qui passe ; sur la carte claire,
/// trame de points et ondes. Couleurs fixes dans les deux thèmes. Particulier : la carte
/// « Solde Tara » seule. Sans animations : cartes immobiles, bascule sans mouvement.
class WalletCards extends StatefulWidget {
  const WalletCards({
    super.key,
    required this.wallet,
    required this.merchant,
    required this.front,
    required this.onSwap,
  });

  final Wallet wallet;
  final bool merchant;

  /// `merchant` (ventes devant) ou `customer` (solde Tara devant).
  final String front;
  final ValueChanged<String> onSwap;

  /// Hauteur d'une carte : elle grandit avec la taille du texte du téléphone.
  static double cardHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return 196 + (scale - 1).clamp(0, 1) * 110;
  }

  /// Décalage de la carte de derrière, qui dépasse au-dessus de celle de devant.
  static const lift = 30.0;

  @override
  State<WalletCards> createState() => _WalletCardsState();
}

/// Position d'une carte : déplacement (x, y, profondeur) et rotations, en degrés.
@immutable
class _Pose {
  const _Pose(this.x, this.y, this.z, this.turnY, this.turnZ);
  final double x, y, z, turnY, turnZ;

  static const front = _Pose(0, 0, 0, 0, 0);
  static const back = _Pose(0, -WalletCards.lift, -60, 0, 0);

  // Milieu des bascules de la maquette (à 45 % de l'animation).
  static const toBackMid = _Pose(-150, 6, 40, -42, -8);
  static const toFrontMid = _Pose(20, -16, -24, 10, 2);

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
    a.turnY + (b.turnY - a.turnY) * t,
    a.turnZ + (b.turnZ - a.turnZ) * t,
  );
}

class _WalletCardsState extends State<WalletCards> with SingleTickerProviderStateMixin {
  static const _ease = Cubic(.6, 0, .3, 1);

  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    value: 1,
  );

  /// Inclinaison au repos et sous le doigt (degrés), et position du reflet (0..1).
  static const _restTilt = Offset(7, -9);
  static const _restLight = Offset(.3, .2);
  Offset _tilt = _restTilt;
  Offset _light = _restLight;

  @override
  void didUpdateWidget(WalletCards old) {
    super.didUpdateWidget(old);
    if (old.front != widget.front) {
      if (TaraEffects.of(context).decorativeMotion) {
        _swap.forward(from: 0);
      } else {
        _swap.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  void _follow(Offset local, Size size) {
    final x = (local.dx / size.width).clamp(0.0, 1.0);
    final y = (local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _tilt = Offset(7 + (.5 - y) * 14, (x - .5) * 24);
      _light = Offset(x, y);
    });
  }

  void _rest() => setState(() {
    _tilt = _restTilt;
    _light = _restLight;
  });

  /// Pose d'une carte pendant la bascule : chaque moitié de la maquette a sa courbe.
  _Pose _pose({required bool toFront}) {
    final t = _swap.value;
    final (from, mid, to) = toFront
        ? (_Pose.back, _Pose.toFrontMid, _Pose.front)
        : (_Pose.front, _Pose.toBackMid, _Pose.back);
    if (t >= 1) return to;
    if (t < .45) return _Pose.lerp(from, mid, _ease.transform(t / .45));
    return _Pose.lerp(mid, to, _ease.transform((t - .45) / .55));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final height = WalletCards.cardHeight(context);
    final merchant = widget.merchant;
    final salesFront = merchant && widget.front == 'merchant';
    final sales = _SalesCard(wallet: widget.wallet, light: _light);
    final tara = _TaraCard(wallet: widget.wallet, shop: merchant, light: _light);

    Widget card({required String account, required Widget face}) {
      final isFront = account == widget.front || !merchant;
      final label = account == 'merchant'
          ? (isFront ? l.walletSalesFront : l.walletSalesShow)
          : (isFront ? l.walletTaraFront : l.walletTaraShow);
      return Semantics(
        button: !isFront,
        label: label,
        // Carte de derrière : seule son action est annoncée ; son contenu se lit devant.
        excludeSemantics: !isFront,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isFront
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onSwap(account);
                },
          child: face,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Particulier : une seule carte, pas de bande de carte de derrière au-dessus.
        final lift = merchant ? WalletCards.lift : 0.0;
        final size = Size(constraints.maxWidth, height + lift);
        return GestureDetector(
          // Le groupe s'incline sous le doigt, puis revient en place.
          onPanDown: (details) => _follow(details.localPosition, size),
          onPanUpdate: (details) => _follow(details.localPosition, size),
          onPanEnd: (_) => _rest(),
          onPanCancel: _rest,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: _tilt),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, tilt, _) => AnimatedBuilder(
              animation: _swap,
              builder: (context, _) {
                Widget place(String account, Widget face, {required bool isFront}) {
                  final pose = merchant ? _pose(toFront: isFront) : _Pose.front;
                  final matrix = Matrix4.identity()
                    ..setEntry(3, 2, 1 / 1000)
                    ..rotateX(tilt.dx * math.pi / 180)
                    ..rotateY(tilt.dy * math.pi / 180)
                    // Profondeur CSS (négative = plus loin) : la perspective de Flutter
                    // compte l'axe dans l'autre sens.
                    ..translateByDouble(pose.x, pose.y, -pose.z, 1)
                    ..rotateY(pose.turnY * math.pi / 180)
                    ..rotateZ(pose.turnZ * math.pi / 180);
                  return Positioned(
                    left: 0,
                    right: 0,
                    top: lift,
                    height: height,
                    child: Transform(
                      transform: matrix,
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: isFront ? 1 : .9,
                        child: card(account: account, face: face),
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: size.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // La carte de derrière d'abord, celle de devant par-dessus.
                      if (merchant) ...[
                        if (salesFront)
                          place('customer', tara, isFront: false)
                        else
                          place('merchant', sales, isFront: false),
                        if (salesFront)
                          place('merchant', sales, isFront: true)
                        else
                          place('customer', tara, isFront: true),
                      ] else
                        place('customer', tara, isFront: true),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Repère de la carte de devant sous les cartes : la pastille active s'allonge.
class WalletCardDots extends StatelessWidget {
  const WalletCardDots({super.key, required this.salesFront});
  final bool salesFront;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    Widget dot(bool on) => AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: on ? 26 : 8,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: on ? TaraBrand.gradient : null,
        color: on ? null : c.textPrimary.withValues(alpha: .18),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [dot(salesFront), const SizedBox(width: 8), dot(!salesFront)],
      ),
    );
  }
}

/// Fond commun : dégradé, bord, ombre, puis les décors (sous le contenu).
class _Face extends StatelessWidget {
  const _Face({
    required this.gradient,
    required this.border,
    required this.shadow,
    required this.decor,
    required this.header,
    required this.amount,
    required this.footer,
  });

  final Gradient gradient;
  final Color border;
  final Color shadow;
  final List<Widget> decor;
  final Widget header;
  final Widget amount;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: shadow, blurRadius: 44, offset: const Offset(0, 22))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border),
          ),
          child: Stack(
            children: [
              ...decor,
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const Spacer(), amount, const SizedBox(height: 4), footer],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reflet qui suit le doigt.
Widget _glow(Offset light, Color color) => Positioned.fill(
  child: IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(light.dx * 2 - 1, light.dy * 2 - 1),
          radius: .9,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  ),
);

/// Carte sombre des ventes à recevoir.
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.wallet, required this.light});
  final Wallet wallet;
  final Offset light;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final balance = wallet.merchantBalance ?? 0;
    var phone = digitsOf(wallet.payoutPhone ?? '');
    if (phone.startsWith('237') && phone.length == 12) phone = phone.substring(3);
    final operator = guessOperator(phone);
    final tail = phone.length >= 2 ? '••${phone.substring(phone.length - 2)}' : '';
    const soft = Color.fromRGBO(255, 255, 255, .72);
    return _Face(
      gradient: const LinearGradient(
        begin: Alignment(-.5, -1),
        end: Alignment(.5, 1),
        colors: [Color(0xFF2A170A), Color(0xFF16120E)],
        stops: [0, .62],
      ),
      border: const Color.fromRGBO(255, 177, 92, .28),
      shadow: const Color.fromRGBO(60, 25, 0, .28),
      decor: [
        _glow(light, const Color.fromRGBO(255, 255, 255, .20)),
        // Filigrane : le logo Tara qui flotte doucement, à peine visible.
        Positioned(
          right: -34,
          top: -6,
          width: 236,
          height: 168,
          child: IgnorePointer(
            child: MotionBuilder(
              period: const Duration(seconds: 7),
              builder: (context, t, child) {
                final wave = (1 - math.cos(t * 2 * math.pi)) / 2;
                return Transform.translate(
                  offset: Offset(0, -8 * wave),
                  child: Transform.rotate(angle: -3 * wave * math.pi / 180, child: child),
                );
              },
              child: const Opacity(
                opacity: .13,
                child: Center(
                  child: TaraLogo(width: 236, ink: Color(0xFFFFFFFF), semanticLabel: ''),
                ),
              ),
            ),
          ),
        ),
        // Trajet en pointillé et point lumineux qui le parcourt.
        const Positioned.fill(
          child: RouteTrail(route: RouteTrail.walletCard, base: Size(352, 196)),
        ),
        // Traits de vitesse.
        Positioned(
          right: 18,
          bottom: 22,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (width, color, delay) in [
                  (64.0, const Color(0xFFFF6A00), 0),
                  (42.0, const Color(0xFFFF8A3D), 200),
                  (22.0, TaraBrand.amber, 400),
                ]) ...[
                  MotionBuilder(
                    period: const Duration(milliseconds: 1600),
                    delay: Duration(milliseconds: 1600 - delay),
                    builder: (context, t, child) =>
                        Transform.translate(offset: Offset(-7 * (1 - math.cos(t * 2 * math.pi)) / 2, 0), child: child),
                    child: Container(
                      width: width,
                      height: 7,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ),
        const SheenSweep(color: Color.fromRGBO(255, 255, 255, .11), delay: Duration(milliseconds: 1200)),
      ],
      header: Row(
        children: [
          Expanded(
            child: Text(
              l.shopToReceive,
              style: TaraText.label.copyWith(
                color: const Color.fromRGBO(255, 255, 255, .74),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (wallet.todaySales > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(74, 222, 155, .16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pastille qui clignote : des ventes arrivent aujourd'hui.
                  MotionBuilder(
                    period: const Duration(milliseconds: 1600),
                    builder: (context, t, child) =>
                        Opacity(opacity: 1 - .65 * (1 - math.cos(t * 2 * math.pi)) / 2, child: child),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Color(0xFF4ADE9B), shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.shopTodayChip('${formatAmount(wallet.todaySales)} F'),
                    style: TaraText.smallStrong.copyWith(color: const Color(0xFF4ADE9B), fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Masqué par défaut, comme sur MoMo ; une dette reste toujours affichée.
      amount: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: balance < 0
            ? AmountText(balance, unit: 'F', style: TaraText.amountL, color: const Color(0xFFFF4D5A))
            : MaskedBalance(balance, style: TaraText.amountL, color: const Color(0xFFFFFFFF), showEye: false),
      ),
      footer: Row(
        children: [
          Flexible(
            child: Text(
              wallet.payoutSchedule == 'DAILY'
                  ? '${l.shopPayoutTonight('${wallet.payoutHour}')} · '
                  : '${l.shopPayoutWhenAsked} · ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TaraText.small.copyWith(color: soft, fontWeight: FontWeight.w600),
            ),
          ),
          if (operator != null) ...[OperatorLogo(operator, size: 18), const SizedBox(width: 6)],
          Text(
            tail,
            style: TaraText.small.copyWith(color: soft, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Carte claire du solde Tara.
class _TaraCard extends StatelessWidget {
  const _TaraCard({required this.wallet, required this.shop, required this.light});
  final Wallet wallet;
  final bool shop;
  final Offset light;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const ink = Color(0xFF16120E);
    const soft = Color.fromRGBO(22, 18, 14, .70);
    final minimum = wallet.customerWithdrawalMinimum;
    return _Face(
      gradient: const LinearGradient(
        begin: Alignment(-.35, -1),
        end: Alignment(.35, 1),
        colors: [Color(0xFFFFFFFF), Color(0xFFFFF1E2)],
      ),
      border: const Color.fromRGBO(255, 255, 255, .95),
      shadow: const Color.fromRGBO(140, 70, 10, .16),
      decor: [
        _glow(light, const Color.fromRGBO(255, 255, 255, .65)),
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _DotGridPainter())),
        ),
        // Ondes qui partent du coin, comme une notification qui arrive.
        Positioned(
          right: -7,
          top: -13,
          width: 90,
          height: 90,
          child: IgnorePointer(
            child: Stack(
              children: [
                for (final delay in [0, 1200, 2400])
                  Positioned.fill(
                    child: MotionBuilder(
                      period: const Duration(milliseconds: 3600),
                      delay: Duration(milliseconds: 3600 - delay),
                      stillPhase: .3,
                      builder: (context, t, _) {
                        final p = Curves.easeOut.transform(t);
                        return Transform.scale(
                          scale: .35 + 1.65 * p,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Color.fromRGBO(255, 106, 0, .40 * .9 * (1 - p)), width: 1.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SheenSweep(color: Color.fromRGBO(255, 255, 255, .75), delay: Duration(seconds: 3)),
      ],
      header: Row(
        children: [
          Expanded(
            child: Text(
              l.taraBalance,
              style: TaraText.label.copyWith(color: const Color.fromRGBO(22, 18, 14, .72), fontWeight: FontWeight.w700),
            ),
          ),
          const TaraLogo(width: 40, ink: ink, semanticLabel: ''),
        ],
      ),
      amount: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: MaskedBalance(wallet.customerBalance, style: TaraText.amountL, color: ink, showEye: false),
      ),
      footer: Text(
        [
          if (shop) l.taraCardShopLine else l.taraCardLine,
          if (minimum > 0) l.taraCardWithdrawFrom('${formatAmount(minimum)} F'),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TaraText.small.copyWith(color: soft, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Trame de points orangés, nette en haut à droite et qui s'efface vers le bas à gauche.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Sens du dégradé de la maquette (200°) : visible au départ, effacé à 62 %.
    const angle = 200 * math.pi / 180;
    final dx = math.sin(angle), dy = -math.cos(angle);
    final corners = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
    final projections = [for (final p in corners) p.dx * dx + p.dy * dy];
    final low = projections.reduce(math.min), high = projections.reduce(math.max);
    final paint = Paint();
    for (double y = 7; y < size.height; y += 14) {
      for (double x = 7; x < size.width; x += 14) {
        final t = ((x * dx + y * dy) - low) / (high - low);
        final alpha = (1 - t / .62).clamp(0.0, 1.0);
        if (alpha <= 0) continue;
        paint.color = Color.fromRGBO(194, 65, 12, .13 * alpha);
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}
