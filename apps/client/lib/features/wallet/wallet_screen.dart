import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/money/mobile_money_fees.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/pin_flow.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pin.dart';
import '../home/home_screen.dart' show walletProvider;

/// Reversements et retraits récents.
final payoutsProvider = FutureProvider<List<Payout>>((ref) => ref.read(clientApiProvider).payouts());

/// « 12 500 F », espace insécable comme partout dans l'app.
String _f(int amount) => '${formatAmount(amount)} F';

/// Taux en points de base, en pourcentage lisible : 250 → « 2,5 % ».
String _percent(num bps) => '${NumberFormat('#0.##', 'fr').format(bps / 100)}\u00a0%';

/// Clé d'idempotence : une demande renvoyée (réseau coupé) n'en crée pas une seconde.
String _key() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Portefeuille de l'expéditeur (non dessiné : style Tara). Boutique : ventes à recevoir,
/// reversement (quotidien, ou immédiat pour les offres payantes), relevés mensuels PDF (G2,
/// G3, G7). Pour tous : solde Tara, recharge et retrait par Mobile Money (G1, G8), et chaque
/// mouvement ligne par ligne.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, required this.me, required this.onBack, this.now});

  final Me me;
  final VoidCallback onBack;

  /// Horloge (tests) : mois des relevés.
  final DateTime Function()? now;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

enum _Panel { none, topUp, withdraw }

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.75), size: 240, colors: BlobSpec.soft, blur: 64, delay: Duration(seconds: 5)),
  ];

  late String _account = widget.me.merchant == null ? 'customer' : 'merchant';
  final _lines = <WalletLine>[];
  String? _cursor;
  bool _loadingLines = true;
  bool _linesFailed = false;

  _Panel _panel = _Panel.none;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLines(reset: true));
  }

  Future<void> _loadLines({bool reset = false}) async {
    final account = _account;
    setState(() {
      _loadingLines = true;
      _linesFailed = false;
      if (reset) {
        _lines.clear();
        _cursor = null;
      }
    });
    try {
      final page = await ref.read(clientApiProvider).walletLines(account: account, cursor: reset ? null : _cursor);
      if (!mounted || account != _account) return;
      setState(() {
        _lines.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted) setState(() => _linesFailed = true);
    } finally {
      if (mounted && account == _account) setState(() => _loadingLines = false);
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(walletProvider)
      ..invalidate(payoutsProvider);
    await _loadLines(reset: true);
  }

  void _open(_Panel panel) => setState(() {
    _panel = _panel == panel ? _Panel.none : panel;
    _error = null;
    _notice = null;
  });

  /// Code secret donné pour afficher le solde avant le retrait : il confirme aussi le retrait.
  PinProof? _proof;

  /// Retrait : le solde masqué s'affiche d'abord avec le code secret (ou l'empreinte).
  Future<void> _openWithdraw() async {
    if (_panel == _Panel.withdraw) return _open(_Panel.withdraw);
    final visibility = ref.read(balanceVisibilityProvider);
    if (!visibility.visible) {
      final pin = ref.read(pinApiProvider);
      try {
        final proof = await withPin<PinProof>(
          context,
          pinServices(context, ref),
          reason: AppLocalizations.of(context).pinReasonBalance,
          action: (given) async {
            await pin.verify(given);
            return given;
          },
        );
        if (proof == null || !mounted) return;
        _proof = proof;
        visibility.show();
      } catch (error) {
        if (mounted) setState(() => _error = errorMessage(context, error));
        return;
      }
    }
    _open(_Panel.withdraw);
  }

  /// Action d'argent confirmée par le code secret : celui déjà donné, sinon demandé ici.
  Future<T?> _withPin<T>(String reason, Future<T> Function(PinProof proof) action) async {
    if (_proof case final given?) {
      try {
        return await action(given);
      } on ApiException catch (error) {
        if (!error.code.startsWith('PIN_') && error.code != 'BIOMETRIC_INVALID') rethrow;
        _proof = null;
      }
    }
    if (!mounted) return null;
    return withPin<T>(context, pinServices(context, ref), reason: reason, action: action);
  }

  /// Argent arrivé ou parti : soldes, mouvements et reversements relus, son de pièce.
  void _done(String notice) {
    TaraFeedback.play(context, TaraSound.cash);
    setState(() {
      _panel = _Panel.none;
      _notice = notice;
    });
    unawaited(_refresh());
  }

  Future<void> _payoutNow(int amount) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = _key();
      final payout = await _withPin(
        l.pinReasonWithdraw(balanceText(ref.read(balanceVisibilityProvider), amount)),
        (proof) => ref.read(clientApiProvider).payoutNow(key: key, proof: proof),
      );
      if (payout != null && mounted) _done(l.payoutRequested);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(String operator, int amount) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = _key();
      final payout = await _withPin(
        l.pinReasonWithdraw(_f(amount)),
        (proof) =>
            ref.read(clientApiProvider).withdraw(phone: widget.me.phone, operator: operator, key: key, proof: proof),
      );
      if (payout != null && mounted) _done(l.withdrawDone);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final wallet = ref.watch(walletProvider);
    final data = wallet.value;
    final merchant = widget.me.merchant != null;
    return TaraScreen(
      blobs: _blobs,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(l.walletTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
            ),
            const SizedBox(height: 16),
            if (data == null)
              wallet.hasError
                  ? _Retry(onRetry: () => ref.invalidate(walletProvider))
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: GooLoader(compact: true)),
                    )
            else ...[
              if (_notice != null) ...[
                TintBox(
                  tone: TintTone.success,
                  child: Row(
                    children: [
                      TaraIcon(TaraIcons.check, size: 20, color: c.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_notice!, style: TaraText.label.copyWith(color: c.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (merchant) ...[
                _ShopCard(wallet: data, busy: _busy, onPayoutNow: _payoutNow),
                const SizedBox(height: 12),
              ],
              // Boutique : un seul solde, ses ventes (elles paient aussi ses livraisons). Le
              // solde Tara n'apparaît que s'il en reste un d'avant la boutique, à retirer.
              if (!merchant || data.customerBalance != 0)
                _BalanceCard(
                  wallet: data,
                  shop: merchant,
                  panel: _panel,
                  busy: _busy,
                  phone: widget.me.phone,
                  onTopUp: () => _open(_Panel.topUp),
                  onWithdraw: () => unawaited(_openWithdraw()),
                  onCancel: () => _open(_panel),
                  onToppedUp: (amount) => _done(l.topUpDone(_f(amount))),
                  onWithdrawConfirm: _withdraw,
                ),
              if (_error != null) ...[const SizedBox(height: 10), ErrorLine(_error!)],
            ],
            const SizedBox(height: 24),
            SectionHeader(title: l.movements),
            const SizedBox(height: 8),
            if (merchant && (data?.customerBalance ?? 0) != 0) ...[
              LiquidSegmented<String>(
                compact: true,
                segments: [('merchant', l.movementsShop), ('customer', l.movementsBalance)],
                selected: _account,
                onChanged: (account) {
                  if (account == _account) return;
                  setState(() => _account = account);
                  unawaited(_loadLines(reset: true));
                },
              ),
              const SizedBox(height: 10),
            ],
            _Lines(
              lines: _lines,
              loading: _loadingLines,
              failed: _linesFailed,
              hasMore: _cursor != null,
              account: _account,
              onMore: () => unawaited(_loadLines()),
              onRetry: () => unawaited(_loadLines(reset: _lines.isEmpty)),
            ),
            const _Payouts(),
            if (merchant) _Statements(now: widget.now?.call() ?? DateTime.now()),
          ],
        ),
      ),
    );
  }
}

/// Boutique : ventes encaissées à recevoir, quand et où elles arrivent ; reversement
/// immédiat pour les offres payantes ; frais d'échec à régler si le solde est négatif.
class _ShopCard extends ConsumerWidget {
  const _ShopCard({required this.wallet, required this.busy, required this.onPayoutNow});

  final Wallet wallet;
  final bool busy;
  final ValueChanged<int> onPayoutNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(balanceVisibilityProvider);
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final balance = wallet.merchantBalance ?? 0;
    final phone = displayPhone(wallet.payoutPhone ?? '');
    final open = wallet.openPayout;
    return TintBox(
      tone: balance < 0 ? TintTone.danger : TintTone.success,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TaraIcon(TaraIcons.wallet, size: 22, color: balance < 0 ? c.dangerText : c.success),
              const SizedBox(width: 8),
              Text(l.shopToReceive, style: TaraText.label.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          // Masqué par défaut, comme sur MoMo ; une dette reste toujours affichée.
          if (balance < 0)
            AmountText(balance, unit: 'F', style: TaraText.amountL, color: c.dangerTextStrong)
          else
            MaskedBalance(balance, style: TaraText.amountL),
          const SizedBox(height: 4),
          Text(
            wallet.payoutSchedule == 'DAILY'
                ? l.shopPayoutDaily('${wallet.payoutHour}', phone)
                : l.shopPayoutOnDemand(phone),
            style: TaraText.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            l.shopToday(_f(wallet.todaySales), wallet.todayDeliveries),
            style: TaraText.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(l.shopPaysDeliveries, style: TaraText.small.copyWith(color: c.textSecondary)),
          if (wallet.withdrawalFeeBps > 0 && wallet.withdrawalFeeSharePercent > 0) ...[
            const SizedBox(height: 2),
            Text(
              // Seule la part de la boutique est annoncée (taux effectif).
              l.shopWithdrawalRule(
                _f(wallet.withdrawalFreeFrom),
                _percent(wallet.withdrawalFeeBps * wallet.withdrawalFeeSharePercent / 100),
              ),
              style: TaraText.small.copyWith(color: c.textSecondary),
            ),
          ],
          if (balance < 0) ...[
            const SizedBox(height: 10),
            Text(l.shopDebt(_f(-balance)), style: TaraText.label.copyWith(color: c.dangerTextStrong)),
          ],
          if (open != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InfoPill(label: l.payoutOpen(_f(open.amount)), tone: TintTone.accent, icon: TaraIcons.clock),
            ),
          ] else if (wallet.canPayoutBalanceNow) ...[
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: visibility,
              builder: (context, _) => PrimaryButton(
                label: l.payoutNow(balanceText(visibility, balance)),
                loading: busy,
                onPressed: () => onPayoutNow(balance),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Solde Tara : à quoi il sert, recharge par Mobile Money, retrait de tout le solde.
class _BalanceCard extends ConsumerStatefulWidget {
  const _BalanceCard({
    required this.wallet,
    required this.shop,
    required this.panel,
    required this.busy,
    required this.phone,
    required this.onTopUp,
    required this.onWithdraw,
    required this.onCancel,
    required this.onToppedUp,
    required this.onWithdrawConfirm,
  });

  final Wallet wallet;

  /// Boutique : ancien solde Tara, à retirer seulement (ses livraisons se paient avec ses
  /// ventes, qui sont reversées chaque jour : une recharge repartirait le soir même).
  final bool shop;
  final _Panel panel;
  final bool busy;
  final String phone;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;
  final VoidCallback onCancel;
  final ValueChanged<int> onToppedUp;
  final Future<void> Function(String operator, int amount) onWithdrawConfirm;

  @override
  ConsumerState<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<_BalanceCard> {
  static const _amounts = [2000, 5000, 10000, 20000];

  /// Bornes d'une recharge (comme l'app livreur).
  static const _min = 500;
  static const _max = 500000;

  /// Montant choisi parmi les puces ; un autre montant tapé l'emporte.
  int _chip = 5000;
  final _other = TextEditingController();
  int get _amount => int.tryParse(_other.text) ?? _chip;

  /// Frais Mobile Money payés en plus de la recharge (réglages de l'app).
  int get _fee => mobileMoneyFee(_amount, ref.watch(appConfigProvider).value?.mobileMoneyFeeBps ?? 0);
  String _operator = 'MTN';
  late final _payer = TextEditingController(text: _grouped(widget.phone));
  bool _paying = false;
  String? _paymentId;
  bool _failed = false;
  String? _error;
  Timer? _poll;

  static String _grouped(String phone) => PhoneInputFormatter()
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: digitsOf(phone).replaceFirst(RegExp('^237'), '')),
      )
      .text;

  @override
  void didUpdateWidget(_BalanceCard old) {
    super.didUpdateWidget(old);
    if (old.panel != widget.panel) _stop();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _payer.dispose();
    _other.dispose();
    super.dispose();
  }

  void _stop() {
    _poll?.cancel();
    _paymentId = null;
    _failed = false;
    _error = null;
  }

  Future<void> _pay() async {
    final l = AppLocalizations.of(context);
    final phone = digitsOf(_payer.text);
    if (!isCameroonMobile(phone)) {
      setState(() => _error = l.phoneInvalid);
      return;
    }
    if (_amount < _min || _amount > _max) {
      setState(() => _error = l.topUpRange(_f(_min), _f(_max)));
      return;
    }
    setState(() {
      _paying = true;
      _failed = false;
      _error = null;
    });
    try {
      final payment = await ref
          .read(clientApiProvider)
          .topUp(amount: _amount, phone: phone, operator: _operator, key: _key());
      if (!mounted) return;
      setState(() => _paymentId = payment.id);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_check()));
      if (payment.status != 'PENDING') unawaited(_check());
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Demande validée sur le téléphone : le solde est crédité.
  Future<void> _check() async {
    final id = _paymentId;
    if (id == null) return;
    final Payment payment;
    try {
      payment = await ref.read(clientApiProvider).payment(id);
    } on ApiException {
      return; // Réseau : nouvel essai au prochain tour.
    }
    if (!mounted || _paymentId != id) return;
    switch (payment.status) {
      case 'SUCCEEDED':
        _poll?.cancel();
        setState(() => _paymentId = null);
        widget.onToppedUp(payment.amount);
      case 'FAILED' || 'CANCELLED':
        _poll?.cancel();
        setState(() {
          _paymentId = null;
          _failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final balance = widget.wallet.customerBalance;
    // Retrait gratuit de tout le solde, même petit : rien ne reste chez Tara.
    final canWithdraw = balance > 0 && widget.wallet.openPayout == null;
    final pending = _paymentId != null;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.taraBalance, style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 4),
          MaskedBalance(balance, style: TaraText.amountL),
          const SizedBox(height: 4),
          Text(
            widget.shop ? l.taraBalanceShopBody : l.taraBalanceBody,
            style: TaraText.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 14),
          if (widget.panel == _Panel.none)
            Row(
              children: [
                if (!widget.shop)
                  Expanded(
                    child: GlassButton(
                      label: l.topUpAction,
                      icon: TaraIcons.wallet,
                      height: 48,
                      color: c.accentText,
                      onPressed: widget.onTopUp,
                    ),
                  ),
                if (canWithdraw) ...[
                  if (!widget.shop) const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: l.withdrawAction,
                      icon: TaraIcons.send,
                      height: 48,
                      onPressed: widget.onWithdraw,
                    ),
                  ),
                ],
              ],
            ),
          if (widget.panel == _Panel.topUp) ...[
            Text(l.topUpHowMuch, style: TaraText.text.copyWith(color: c.textPrimary)),
            const SizedBox(height: 8),
            ChoiceChips<int>(
              columns: 4,
              height: 44,
              options: [for (final amount in _amounts) ChoiceOption(amount, formatAmount(amount))],
              selected: _other.text.isEmpty ? _chip : null,
              onSelected: pending
                  ? (_) {}
                  : (amount) => setState(() {
                      _other.clear();
                      _chip = amount;
                    }),
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: pending,
              child: TaraTextField(
                label: l.topUpOther,
                hint: l.topUpOtherHint,
                controller: _other,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(height: 10),
            ChoiceChips<String>(
              options: [ChoiceOption('MTN', l.payMtn), ChoiceOption('ORANGE', l.payOrange)],
              selected: _operator,
              onSelected: pending ? (_) {} : (operator) => setState(() => _operator = operator),
            ),
            const SizedBox(height: 10),
            TaraTextField(
              label: l.payerPhoneLabel,
              hint: l.phoneHint,
              controller: _payer,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
            ),
            if (pending) ...[
              const SizedBox(height: 10),
              TintBox(
                tone: TintTone.accent,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.topUpPending(_f(_amount)), style: TaraText.label.copyWith(color: c.textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    const GooLoader(compact: true),
                  ],
                ),
              ),
            ],
            if (_failed) ...[const SizedBox(height: 10), ErrorLine(l.topUpFailed)],
            if (_error != null) ...[const SizedBox(height: 10), ErrorLine(_error!)],
            const SizedBox(height: 12),
            if (_fee > 0) ...[
              Text(l.topUpFeeNote(_f(_fee)), style: TaraText.small.copyWith(color: c.textSecondary)),
              const SizedBox(height: 8),
            ],
            if (!pending) PrimaryButton(label: l.topUpPay(_f(_amount + _fee)), loading: _paying, onPressed: _pay),
            Center(
              child: TaraLink(
                label: l.cancel,
                onPressed: () {
                  setState(_stop);
                  widget.onCancel();
                },
              ),
            ),
          ],
          if (widget.panel == _Panel.withdraw) ...[
            Text(
              l.withdrawBody(_f(balance), displayPhone(widget.phone)),
              style: TaraText.label.copyWith(color: c.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 10),
            ChoiceChips<String>(
              options: [ChoiceOption('MTN', l.payMtn), ChoiceOption('ORANGE', l.payOrange)],
              selected: _operator,
              onSelected: (operator) => setState(() => _operator = operator),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: l.withdrawConfirm(_f(balance)),
              loading: widget.busy,
              onPressed: () => unawaited(widget.onWithdrawConfirm(_operator, balance)),
            ),
            Center(
              child: TaraLink(label: l.cancel, onPressed: widget.onCancel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mouvements ligne par ligne : nature, commande, date, montant (+ vert, − neutre).
class _Lines extends StatelessWidget {
  const _Lines({
    required this.lines,
    required this.loading,
    required this.failed,
    required this.hasMore,
    required this.account,
    required this.onMore,
    required this.onRetry,
  });

  final List<WalletLine> lines;
  final bool loading;
  final bool failed;
  final bool hasMore;
  final String account;
  final VoidCallback onMore;
  final VoidCallback onRetry;

  static String title(AppLocalizations l, WalletLine line, String account) => switch (line.kind) {
    'COD_COLLECTED' => l.lineCodCollected,
    'ORDER_CHARGED' => l.lineOrderCharged,
    'ORDER_RELEASED' => l.lineOrderReleased,
    'FAILURE_FEE_CHARGED' => l.lineFailureFee,
    'CREDIT_GRANTED' => l.lineCredit,
    'PAYMENT_RECEIVED' => l.lineTopUp,
    'PAYOUT_REQUESTED' || 'PAYOUT_SENT' => account == 'merchant' ? l.linePayout : l.lineWithdrawal,
    'PAYOUT_FAILED' => l.linePayoutFailed,
    'REFUND' => l.lineRefund,
    _ => line.description,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateFormat(locale == 'fr' ? "d MMM, HH'h'mm" : 'd MMM, HH:mm', locale);
    if (lines.isEmpty) {
      if (loading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: GooLoader(compact: true)),
        );
      }
      if (failed) return _Retry(onRetry: onRetry);
      return GlassCard(
        radius: 20,
        shadow: false,
        padding: const EdgeInsets.all(16),
        child: Text(l.movementsEmpty, style: TaraText.label.copyWith(color: c.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          radius: 22,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (index, line) in lines.indexed) ...[
                if (index > 0) Divider(height: 1, color: c.glassBorder),
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        IconTile(
                          icon: line.amount >= 0 ? TaraIcons.arrowRight : TaraIcons.send,
                          size: 38,
                          radius: 12,
                          tone: line.amount >= 0 ? TintTone.success : TintTone.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title(l, line, account), style: TaraText.text.copyWith(color: c.textPrimary)),
                              Text(
                                [?line.orderReference, date.format(line.at.toLocal())].join(' · '),
                                style: TaraText.small.copyWith(color: c.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${line.amount >= 0 ? '+' : '−'}${_f(line.amount.abs())}',
                          style: TaraText.text.copyWith(
                            color: line.amount >= 0 ? c.success : c.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: TaraText.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasMore || loading)
          Center(
            child: loading
                ? const Padding(padding: EdgeInsets.all(12), child: GooLoader(compact: true))
                : TaraLink(label: l.seeMore, onPressed: onMore),
          ),
      ],
    );
  }
}

/// Derniers reversements et retraits, avec leur état.
class _Payouts extends ConsumerWidget {
  const _Payouts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final payouts = ref.watch(payoutsProvider).value;
    if (payouts == null || payouts.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateFormat('d MMM', locale);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l.payoutsTitle),
          const SizedBox(height: 8),
          GlassCard(
            radius: 22,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (index, payout) in payouts.indexed) ...[
                  if (index > 0) Divider(height: 1, color: c.glassBorder),
                  MergeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${payout.beneficiary == 'MERCHANT' ? l.linePayout : l.lineWithdrawal} · ${_f(payout.amount)}',
                                  style: TaraText.text.copyWith(color: c.textPrimary),
                                ),
                                Text(
                                  date.format((payout.completedAt ?? payout.requestedAt).toLocal()),
                                  style: TaraText.small.copyWith(color: c.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          InfoPill(
                            label: payout.status == 'SUCCEEDED'
                                ? l.payoutStatusDone
                                : payout.open
                                ? l.payoutStatusOpen
                                : l.payoutStatusFailed,
                            tone: payout.status == 'SUCCEEDED'
                                ? TintTone.success
                                : payout.open
                                ? TintTone.accent
                                : TintTone.danger,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Relevés mensuels PDF de la boutique (G7) : le mois en cours et les cinq précédents,
/// téléchargés puis partagés (WhatsApp, e-mail, enregistrement).
class _Statements extends ConsumerStatefulWidget {
  const _Statements({required this.now});

  final DateTime now;

  @override
  ConsumerState<_Statements> createState() => _StatementsState();
}

class _StatementsState extends ConsumerState<_Statements> {
  String? _loading;
  String? _error;

  Future<void> _share(DateTime month, String label) async {
    final l = AppLocalizations.of(context);
    final key = DateFormat('yyyy-MM').format(month);
    setState(() {
      _loading = key;
      _error = null;
    });
    try {
      final bytes = await ref.read(clientApiProvider).statement(key);
      await ref.read(shareFileProvider)(bytes, 'releve-tara-$key.pdf', 'application/pdf', l.statementShare(label));
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final monthName = DateFormat('MMMM yyyy', locale);
    final months = [for (var i = 0; i < 6; i++) DateTime(widget.now.year, widget.now.month - i)];
    String capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l.statementsTitle),
          const SizedBox(height: 4),
          Text(l.statementsBody, style: TaraText.small.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          GlassCard(
            radius: 22,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (index, month) in months.indexed) ...[
                  if (index > 0) Divider(height: 1, color: c.glassBorder),
                  Builder(
                    builder: (context) {
                      final name = capitalized(monthName.format(month));
                      final key = DateFormat('yyyy-MM').format(month);
                      return ListRow(
                        leading: const IconTile(icon: TaraIcons.download, size: 38, radius: 12),
                        title: index == 0 ? l.statementCurrent(name) : name,
                        trailing: _loading == key
                            ? const GooLoader(compact: true)
                            : TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
                        onTap: _loading == null ? () => unawaited(_share(month, name)) : null,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 8), ErrorLine(_error!)],
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorLine(l.genericError),
        const SizedBox(height: 8),
        GlassButton(label: l.retry, height: 44, onPressed: onRetry),
      ],
    );
  }
}
