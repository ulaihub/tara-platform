import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/wallet_choice.dart';
import '../home/home_screen.dart';
import '../order/order_placed.dart';
import '../order/pickup_step.dart';
import 'bulk_draft.dart';

/// Envoi en masse · vérifier et envoyer : ce qui part tout de suite, ce qui attend l'adresse
/// du client, ce qui reste à compléter ; le prix ; le paiement ; un geste pour tout envoyer.
/// Renvoie `true` (par Navigator.pop) une fois l'envoi parti et vu.
class BulkSendScreen extends ConsumerStatefulWidget {
  const BulkSendScreen({super.key, required this.draft, required this.me, this.onTrack, this.now});

  final BulkDraft draft;
  final Me me;
  final ValueChanged<String>? onTrack;
  final DateTime Function()? now;

  @override
  ConsumerState<BulkSendScreen> createState() => _BulkSendScreenState();
}

class _BulkSendScreenState extends ConsumerState<BulkSendScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 260, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 220, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 4)),
  ];

  BulkDraft get _draft => widget.draft;
  late final _phone = TextEditingController(
    text: _draft.payerPhone.isNotEmpty ? displayPhone(_draft.payerPhone) : _defaultPhone(),
  );
  bool _quoting = true;
  bool _tried = false;

  // Envoi : clé d'idempotence (un nouvel essai après une coupure ne crée pas de doublon).
  String? _key;
  bool _sending = false;
  String? _sendError;

  /// Ce qui est parti : les clients envoyés, dans l'ordre (numéro = rang + 1).
  List<BulkLine>? _sent;
  Placement? _placed;
  int _incompleteLeft = 0;

  // Paiement Mobile Money des colis prêts.
  Payment? _payment;
  bool _paying = false;
  String? _payError;
  Timer? _paymentPoll;
  StreamSubscription<RealtimeEvent>? _events;
  final _assigned = <String>{};

  String _defaultPhone() {
    final national = digitsOf(widget.me.phone).replaceFirst(RegExp('^237'), '');
    if (isCameroonMobile(national)) _draft.payerPhone = national;
    return isCameroonMobile(national) ? displayPhone(national) : '';
  }

  @override
  void initState() {
    super.initState();
    _phone.addListener(() {
      _draft
        ..payerPhone = digitsOf(_phone.text)
        ..touch();
    });
    _draft.addListener(_changed);
    _events = ref.read(realtimeProvider).stream.listen(_onEvent);
    unawaited(_quoteAll());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _draft.removeListener(_changed);
    _phone.dispose();
    _paymentPoll?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }

  void _onEvent(RealtimeEvent event) {
    switch (event.name) {
      case 'payment.status' when event.payload['paymentId'] == _payment?.id:
        unawaited(_refreshPayment());
      case 'order.status' when event.payload['status'] == 'ASSIGNED':
        final id = event.payload['orderId'];
        final placed = _placed;
        if (placed == null || _assigned.contains(id) || !placed.orders.any((o) => o.id == id)) return;
        TaraFeedback.play(context, TaraSound.received);
        setState(() => _assigned.add(id! as String));
    }
  }

  /// Prix de tous les colis prêts, en un appel.
  Future<void> _quoteAll() async {
    final ready = _draft.ready;
    for (final line in ready) {
      line
        ..quote = null
        ..quoteError = null;
    }
    setState(() => _quoting = true);
    if (ready.isNotEmpty) {
      try {
        final result = await ref
            .read(clientApiProvider)
            .quoteMany(
              pickupAddressId: _draft.pickup!.id,
              items: [
                for (final line in ready)
                  (dropoffAddressId: line.dropoff!.id, packageSize: line.size ?? _draft.defaultSize),
              ],
            );
        for (final (i, item) in result.items.indexed) {
          if (i >= ready.length) break;
          ready[i]
            ..quote = item.quote
            ..quoteError = item.error;
        }
      } catch (error) {
        if (mounted) setState(() => _sendError = errorMessage(context, error));
      }
    }
    if (!mounted) return;
    _suggestMethod();
    setState(() => _quoting = false);
  }

  /// Boutique : ses ventes paient d'office si elles suffisent ; sinon Mobile Money.
  void _suggestMethod() {
    if (_draft.paymentMethod != null) return;
    final wallet = ref.read(walletProvider).value;
    final balance = widget.me.merchant != null ? wallet?.spendable : wallet?.customerBalance;
    _draft.paymentMethod = balance != null && balance >= _draft.total && _draft.total > 0 ? 'WALLET' : 'MOMO_MTN';
  }

  static String _newKey() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  List<BulkLine> get _errors => [
    for (final l in _draft.ready)
      if (l.quoteError != null) l,
  ];

  bool get _canSend =>
      !_quoting && _draft.allQuoted && _errors.isEmpty && _draft.sendable.isNotEmpty && _draft.hasPayment;

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_canSend) {
      setState(() => _tried = true);
      return;
    }
    final api = ref.read(clientApiProvider);
    final lines = _draft.sendable;
    _key ??= _newKey();
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final placement = await api.createBatch(
        idempotencyKey: _key!,
        shared: _draft.sharedJson(),
        deliveries: [for (final line in lines) line.toApi(_draft.defaultSize)],
      );
      ref
        ..invalidate(activeOrdersProvider)
        ..invalidate(walletProvider);
      if (!mounted) return;
      final incomplete = _draft.incomplete.length;
      final momo = _draft.momo;
      _draft.removeSent();
      setState(() {
        _sent = lines;
        _placed = placement;
        _incompleteLeft = incomplete;
      });
      if (momo && placement.orders.isNotEmpty) {
        await _requestPayment();
      } else {
        TaraFeedback.play(context, TaraSound.sent);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      TaraFeedback.play(context, TaraSound.error);
      setState(() => _sendError = errorMessage(context, error));
    } catch (error) {
      if (mounted) setState(() => _sendError = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _requestPayment() async {
    final placed = _placed!;
    final api = ref.read(clientApiProvider);
    final phone = '+237${_draft.payerPhone}';
    final operator = _draft.paymentMethod == 'MOMO_ORANGE' ? 'ORANGE' : 'MTN';
    setState(() {
      _paying = true;
      _payError = null;
    });
    try {
      final payment = placed.orders.length > 1
          ? await api.payBatch(placed.batchId!, phone: phone, operator: operator)
          : await api.payOrder(placed.orders.first.id, phone: phone, operator: operator);
      if (!mounted) return;
      setState(() => _payment = payment);
      _paymentPoll?.cancel();
      _paymentPoll = Timer.periodic(const Duration(seconds: 4), (_) => unawaited(_refreshPayment()));
    } catch (error) {
      if (mounted) setState(() => _payError = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _refreshPayment() async {
    final current = _payment;
    if (current == null || current.status != 'PENDING') return;
    try {
      final fresh = await ref.read(clientApiProvider).payment(current.id);
      if (!mounted || fresh.status == 'PENDING') return;
      _paymentPoll?.cancel();
      setState(() => _payment = fresh);
      TaraFeedback.play(context, fresh.status == 'SUCCEEDED' ? TaraSound.sent : TaraSound.error);
      if (fresh.status == 'SUCCEEDED') ref.invalidate(activeOrdersProvider);
    } catch (_) {
      // Réseau absent : nouvel essai au tour suivant.
    }
  }

  Future<void> _cancelUnpaid() async {
    final l = AppLocalizations.of(context);
    setState(() => _paying = true);
    try {
      for (final order in _placed!.orders) {
        await ref.read(clientApiProvider).cancelOrder(order.id, l.cancelReasonUnpaid);
      }
      ref.invalidate(activeOrdersProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _paying = false;
          _payError = errorMessage(context, error);
        });
      }
    }
  }

  void _setMethod(String method) {
    HapticFeedback.selectionClick();
    _draft
      ..paymentMethod = method
      ..touch();
  }

  @override
  Widget build(BuildContext context) {
    final placed = _placed;
    if (placed != null) {
      final momoDue = _payment?.status != 'SUCCEEDED' && placed.orders.isNotEmpty && _draft.momo;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(true);
        },
        child: TaraScreen(
          safeBottom: false,
          blobs: _blobs,
          child: momoDue
              ? PaymentPending(
                  amount: placed.total + _draft.mobileMoneyFeeAmount,
                  phone: _draft.payerPhone,
                  failed: _payment != null && _payment!.status != 'PENDING' || (_payment == null && _payError != null),
                  busy: _paying,
                  error: _payError,
                  onRetry: () => unawaited(_requestPayment()),
                  onCancel: () => unawaited(_cancelUnpaid()),
                  reference: placed.orders.firstOrNull?.reference,
                  method: _draft.paymentMethod,
                  onBack: () => Navigator.of(context).pop(true),
                )
              : BulkSent(
                  placement: placed,
                  lines: _sent!,
                  assigned: _assigned,
                  incompleteLeft: _incompleteLeft,
                  onDone: () => Navigator.of(context).pop(true),
                ),
        ),
      );
    }
    return _review(context);
  }

  Widget _review(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final draft = _draft;
    draft.mobileMoneyFeeBps = ref.watch(appConfigProvider).value?.mobileMoneyFeeBps ?? 0;
    final shop = widget.me.merchant != null;
    final wallet = ref.watch(walletProvider).value;
    final walletOption = walletChoice(l, shop: shop, wallet: wallet, total: draft.total);
    final ready = draft.ready.length;
    final waiting = draft.waiting.length;
    final incomplete = draft.incomplete.length;
    final total = draft.total;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TaraText.label.copyWith(color: c.textSecondary)),
    );
    Widget fact(TaraIconData icon, TintTone tone, String text, {Widget? action}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 30, radius: 10, tone: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TaraText.text.copyWith(color: c.textPrimary, height: 1.35)),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
    Widget line(String name, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: strong
                  ? TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700)
                  : TaraText.text.copyWith(color: c.textSecondary),
            ),
          ),
          Text(
            value,
            style: strong
                ? TaraText.amountL.copyWith(color: c.textPrimary)
                : TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
            child: Row(
              children: [
                GlassIconButton(
                  icon: TaraIcons.chevronLeft,
                  label: l.back,
                  onPressed: _sending ? null : () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.bulkSendTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ScrollWithFooter(
              horizontal: 20,
              top: 16,
              content: [
                GlassCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        [draft.pickup?.label ?? l.stepPickup, l.bulkWhenNow].join(' · '),
                        style: TaraText.label.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      if (ready > 0) fact(TaraIcons.check, TintTone.success, l.bulkReadyLine(ready)),
                      if (waiting > 0) fact(TaraIcons.clock, TintTone.accent, l.bulkWaitingLine(waiting)),
                      if (incomplete > 0)
                        fact(
                          TaraIcons.alertCircle,
                          TintTone.danger,
                          l.bulkIncompleteLine(incomplete),
                          action: TaraLink(label: l.bulkFix, onPressed: () => Navigator.of(context).pop(false)),
                        ),
                    ],
                  ),
                ),
                for (final error in _errors) ...[
                  const SizedBox(height: 8),
                  ErrorLine(l.bulkQuoteError(draft.sendable.indexOf(error) + 1, error.firstName, error.quoteError!)),
                ],
                const SizedBox(height: 12),
                GlassCard(
                  radius: 22,
                  shadow: false,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      line(l.bulkCourses(ready), _quoting ? '…' : '${formatAmount(total)} F'),
                      if (draft.collectTotal > 0) line(l.bulkCollect, '${formatAmount(draft.collectTotal)} F'),
                      if (draft.mobileMoneyFeeAmount > 0)
                        line(l.mobileMoneyFeeLine, '+${formatAmount(draft.mobileMoneyFeeAmount)} F'),
                      Divider(height: 14, color: c.glassBorder),
                      line(l.bulkPayNow, '${formatAmount(draft.amountToPay)} F', strong: true),
                      if (waiting > 0) ...[
                        const SizedBox(height: 6),
                        Text(l.bulkWaitingPaidLater, style: TaraText.small.copyWith(color: c.textTertiary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                label(l.whoPays),
                ChoiceChips<String>(
                  options: [ChoiceOption('SENDER', l.payerMe), ChoiceOption('RECIPIENT', l.payerRecipient)],
                  selected: draft.feePayer,
                  onSelected: (payer) {
                    HapticFeedback.selectionClick();
                    draft
                      ..feePayer = payer
                      ..touch();
                  },
                ),
                const SizedBox(height: 8),
                if (!draft.senderPays)
                  Text(l.recipientPaysBody, style: TaraText.small.copyWith(color: c.textTertiary))
                else ...[
                  const SizedBox(height: 12),
                  label(l.paymentLabel),
                  for (final (method, icon, title, body) in [
                    ('WALLET', TaraIcons.wallet, walletOption.title, walletOption.body),
                    ('MOMO_MTN', TaraIcons.phone, l.payMtn, l.payMomoBody),
                    ('MOMO_ORANGE', TaraIcons.phone, l.payOrange, l.payMomoBody),
                  ]) ...[
                    AddressChoice(
                      icon: icon,
                      title: title,
                      subtitle: body,
                      selected: draft.paymentMethod == method,
                      onTap: () => _setMethod(method),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (draft.momo) ...[
                    const SizedBox(height: 6),
                    TaraTextField(
                      label: l.payerPhoneLabel,
                      hint: l.phoneHint,
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneInputFormatter()],
                      leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
                    ),
                    if (_tried && !isCameroonMobile(draft.payerPhone)) ...[
                      const SizedBox(height: 6),
                      ErrorLine(l.phoneInvalid),
                    ],
                  ],
                ],
                if (_tried && draft.sendable.isEmpty) ...[const SizedBox(height: 10), ErrorLine(l.bulkNothingToSend)],
                if (_sendError != null) ...[const SizedBox(height: 14), ErrorLine(_sendError!)],
              ],
              footer: SwipeButton(
                label: _quoting ? l.quoting : l.bulkSend(draft.sendable.length),
                semanticLabel: l.bulkSendSemantics,
                icon: TaraIcons.arrowRight,
                loading: _sending,
                onConfirmed: _quoting || draft.sendable.isEmpty ? null : () => unawaited(_send()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Envoi parti : le code d'enlèvement (affiché une seule fois), et chaque colis avec son
/// numéro à écrire dessus — « recherche d'un livreur » ou « attend son point ».
class BulkSent extends StatelessWidget {
  const BulkSent({
    super.key,
    required this.placement,
    required this.lines,
    required this.assigned,
    required this.incompleteLeft,
    required this.onDone,
  });

  final Placement placement;

  /// Les clients envoyés, dans l'ordre : le colis n° N est lines[N - 1].
  final List<BulkLine> lines;
  final Set<String> assigned;
  final int incompleteLeft;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final code = placement.pickupCode;
    final ordersByNumber = {for (final o in placement.orders) o.batchNumber ?? 0: o};
    final waiting = placement.pending.length;
    String nameOf(int number) => number - 1 < lines.length ? lines[number - 1].name.trim() : '';
    return Stack(
      children: [
        ScrollWithFooter(
          horizontal: 20,
          top: 36,
          content: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: TaraBrand.gradient,
                  shape: BoxShape.circle,
                  boxShadow: c.brandShadow,
                ),
                child: const Center(
                  child: TaraIcon(TaraIcons.check, size: 40, strokeWidth: 3, color: TaraBrand.onBrand),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                l.bulkSentTitle,
                textAlign: TextAlign.center,
                style: TaraText.titleForm.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.bulkSentSubtitle(lines.length),
              textAlign: TextAlign.center,
              style: TaraText.label.copyWith(color: c.textSecondary),
            ),
            if (code != null) ...[
              const SizedBox(height: 22),
              GlassCard(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  children: [
                    Text(l.pickupCodeLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '${l.pickupCodeLabel} : ${code.split('').join(' ')}',
                      excludeSemantics: true,
                      child: Text(
                        code.split('').join(' '),
                        style: TaraText.amountXL.copyWith(color: c.textPrimary, letterSpacing: 6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.pickupCodeHelpBatch,
                      textAlign: TextAlign.center,
                      style: TaraText.small.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
            if (waiting > 0) ...[
              const SizedBox(height: 14),
              TintBox(
                child: Text(l.bulkSentWaitingNote(waiting), style: TaraText.small.copyWith(color: c.textPrimary)),
              ),
            ],
            if (incompleteLeft > 0) ...[
              const SizedBox(height: 8),
              Text(
                l.bulkSentIncomplete(incompleteLeft),
                textAlign: TextAlign.center,
                style: TaraText.small.copyWith(color: c.textTertiary),
              ),
            ],
            const SizedBox(height: 14),
            GlassCard(
              radius: 22,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.writeNumbersTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(l.writeNumbersBody, style: TaraText.small.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 8),
                  for (var number = 1; number <= lines.length; number++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: MergeSemantics(
                        child: Row(
                          children: [
                            Semantics(
                              label: l.parcelNumberSemantics(number),
                              excludeSemantics: true,
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: TaraBrand.gradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$number',
                                  style: TaraText.titlePanel.copyWith(
                                    color: TaraBrand.onBrand,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                nameOf(number),
                                style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (ordersByNumber[number] case final order?)
                              assigned.contains(order.id)
                                  ? InfoPill(label: l.riderFoundShort, tone: TintTone.success, icon: TaraIcons.check)
                                  : InfoPill(label: l.riderSearchingShort, dot: c.accentText, blinkDot: true)
                            else
                              InfoPill(label: l.bulkSentWaiting, icon: TaraIcons.clock),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          footer: PrimaryButton(label: l.backHome, icon: TaraIcons.home, onPressed: onDone),
        ),
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}
