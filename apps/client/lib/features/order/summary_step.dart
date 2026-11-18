import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/wallet_choice.dart';
import '../home/home_screen.dart';
import 'order_draft.dart';
import 'package_step.dart';
import 'pickup_step.dart';
import 'when_step.dart';

/// Étape 5 · Récapitulatif : livraisons (jusqu'à 10), prix calculé par le serveur, code
/// promo, qui paie et comment. La commande part ensuite d'un geste (bouton à glisser du
/// parcours).
class SummaryStep extends ConsumerStatefulWidget {
  const SummaryStep({
    super.key,
    required this.draft,
    required this.me,
    required this.now,
    required this.showErrors,
    required this.onEdit,
    required this.onAdd,
    this.error,
  });

  final OrderDraft draft;
  final Me me;
  final DateTime Function() now;
  final bool showErrors;

  /// Modifier une livraison (retour à son destinataire).
  final ValueChanged<int> onEdit;
  final VoidCallback onAdd;

  /// Refus du serveur à la création de la commande.
  final String? error;

  @override
  ConsumerState<SummaryStep> createState() => _SummaryStepState();
}

class _SummaryStepState extends ConsumerState<SummaryStep> {
  late final _promo = TextEditingController(text: widget.draft.promoCode ?? '');
  late final _phone = TextEditingController();
  bool _applying = false;
  String? _promoError;

  OrderDraft get _draft => widget.draft;
  bool get _batch => _draft.deliveries.length > 1;

  @override
  void initState() {
    super.initState();
    final draft = _draft;
    if (draft.payerPhone.isEmpty) {
      draft.payerPhone = digitsOf(widget.me.phone).replaceFirst(RegExp(r'^237(?=\d{9}$)'), '');
    }
    _phone.text = PhoneInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: draft.payerPhone))
        .text;
    _phone.addListener(() {
      final digits = digitsOf(_phone.text);
      if (digits == _draft.payerPhone) return;
      _draft
        ..payerPhone = digits
        ..touch();
    });
    // Codes promo : une seule livraison à la fois.
    if (_batch) draft.promoCode = null;
    draft.paymentMethod ??= _momoGuess;
    // Après la première image : le calcul des prix rafraîchit le parcours.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_quoteAll());
    });
  }

  @override
  void dispose() {
    _promo.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Le moyen choisi par l'expéditeur n'est plus remplacé par la suggestion.
  bool _methodChosen = false;

  String get _momoGuess => switch (guessOperator(_draft.payerPhone)) {
    'ORANGE' => 'MOMO_ORANGE',
    'MTN' => 'MOMO_MTN',
    _ => 'CASH',
  };

  /// Suggestion : une boutique dont les ventes couvrent la course paie avec elles (rien
  /// à valider sur le téléphone, rien à sortir) ; sinon Mobile Money de son opérateur.
  void _suggestMethod() {
    if (_methodChosen) return;
    // Boutique : son solde Tara puis ses ventes paient la course.
    final balance = ref.read(walletProvider).value?.spendable;
    final total = _draft.total;
    final enough = widget.me.merchant != null && balance != null && _draft.allQuoted && total > 0 && balance >= total;
    final pick = enough ? 'WALLET' : _momoGuess;
    if (_draft.paymentMethod == pick) return;
    _draft
      ..paymentMethod = pick
      ..touch();
  }

  Future<Quote> _quote(DeliveryDraft delivery, {String? promoCode}) => ref
      .read(clientApiProvider)
      .quote(
        pickupAddressId: _draft.pickup!.id,
        dropoffAddressId: delivery.dropoff!.id,
        packageSize: delivery.size,
        loadingHelp: delivery.bulky && delivery.loadingHelp,
        scheduledFor: _draft.later ? _draft.scheduledFor : null,
        promoCode: promoCode,
        declaredValue: delivery.declaredValue,
      );

  /// Prix de chaque livraison dont l'adresse est connue.
  Future<void> _quoteAll() async {
    for (final delivery in List.of(_draft.deliveries)) {
      delivery
        ..quote = null
        ..quoteError = null;
    }
    _draft.touch();
    for (final delivery in List.of(_draft.deliveries)) {
      if (delivery.dropoff == null) continue;
      try {
        delivery.quote = await _quote(delivery, promoCode: _batch ? null : _draft.promoCode);
      } catch (error) {
        if (!mounted) return;
        delivery.quoteError = errorMessage(context, error);
      }
      if (!mounted) return;
      _draft.touch();
    }
    _suggestMethod();
  }

  Future<void> _applyPromo() async {
    final code = _promo.text.trim().toUpperCase();
    final delivery = _draft.deliveries.first;
    if (code.isEmpty || delivery.dropoff == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _applying = true;
      _promoError = null;
    });
    try {
      final quote = await _quote(delivery, promoCode: code);
      delivery.quote = quote;
      if (quote.discountSource == 'VOLUME') {
        // Le tarif pro de la boutique est plus avantageux : le code n'est pas utilisé.
        _draft.touch();
        if (mounted) {
          setState(() => _promoError = AppLocalizations.of(context).promoBeatenByPro(percent(quote.proDiscountBps)));
        }
      } else {
        _draft
          ..promoCode = code
          ..touch();
      }
    } catch (error) {
      if (mounted) setState(() => _promoError = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _removePromo() async {
    _promo.clear();
    _draft.promoCode = null;
    setState(() => _promoError = null);
    await _quoteAll();
  }

  void _setPayer(String payer) {
    HapticFeedback.selectionClick();
    _draft
      ..feePayer = payer
      ..touch();
  }

  void _setMethod(String method) {
    HapticFeedback.selectionClick();
    _methodChosen = true;
    _draft
      ..paymentMethod = method
      ..touch();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final draft = _draft;
    // Taux des frais Mobile Money : la ligne s'affiche dès que Mobile Money est choisi.
    draft.mobileMoneyFeeBps = ref.watch(appConfigProvider).value?.mobileMoneyFeeBps ?? 0;
    final pickup = draft.pickup!;
    final shop = widget.me.merchant != null;
    final wallet = ref.watch(walletProvider).value;
    // Ventes connues après le prix : la suggestion peut changer.
    ref.listen(walletProvider, (_, _) => _suggestMethod());
    final walletOption = walletChoice(l, shop: shop, wallet: wallet, total: draft.total);
    final pending = draft.deliveries.where((d) => d.dropoff == null).toList();
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TaraText.label.copyWith(color: c.textSecondary)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.summaryTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: 8),
        Text(l.summaryBody, style: TaraText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 18),
        AddressChoice(
          icon: TaraIcons.package,
          title: pickup.label ?? l.stepPickup,
          subtitle: [
            pickup.summary,
            if (draft.later && draft.scheduledFor != null)
              scheduleText(l, locale, draft.scheduledFor!, widget.now())
            else
              l.whenNowShort,
          ].join('\n'),
          selected: false,
          onTap: () {},
        ),
        const SizedBox(height: 10),
        for (final (i, delivery) in draft.deliveries.indexed) ...[
          _DeliveryCard(
            index: i,
            delivery: delivery,
            numbered: _batch,
            onEdit: () => widget.onEdit(i),
            onRemove: _batch ? () => draft.removeDelivery(i) : null,
          ),
          const SizedBox(height: 10),
        ],
        if (draft.deliveries.length < OrderDraft.maxDeliveries) ...[
          GlassButton(label: l.addDelivery, icon: TaraIcons.package, color: c.accentText, onPressed: widget.onAdd),
          const SizedBox(height: 6),
          Text(l.addDeliveryHint, style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 10),
          ErrorLine(l.linkPendingBlock(pending.first.recipientName.trim().split(RegExp(r'\s+')).first)),
        ],
        const SizedBox(height: 18),
        _PriceCard(draft: draft),
        // Frais d'échec (E6), annoncés avant de commander : rien ne se découvre après. Plusieurs
        // colis : chacun annonce les siens sur sa carte (moto et tricycle n'ont pas les mêmes).
        if (_batch && draft.deliveries.any((d) => (d.quote?.retryFee ?? 0) > 0 || (d.quote?.returnFee ?? 0) > 0)) ...[
          const SizedBox(height: 8),
          Text(l.batchFailureFeesNote, style: TaraText.small.copyWith(color: c.textTertiary)),
          const SizedBox(height: 6),
          Text(l.batchRefusalFeeNote, style: TaraText.small.copyWith(color: c.textTertiary)),
        ] else if (draft.deliveries.map((d) => d.quote).whereType<Quote>().firstOrNull case final quote?
            when quote.retryFee > 0 || quote.returnFee > 0) ...[
          const SizedBox(height: 8),
          Text(
            l.failureFeesNote('${formatAmount(quote.retryFee)} F', '${formatAmount(quote.returnFee)} F'),
            style: TaraText.small.copyWith(color: c.textTertiary),
          ),
          // Colis non conforme refusé à l'enlèvement : le déplacement se paie, annoncé ici.
          if (quote.retryFee > 0) ...[
            const SizedBox(height: 6),
            Text(
              l.refusalFeeNote('${formatAmount(quote.retryFee)} F'),
              style: TaraText.small.copyWith(color: c.textTertiary),
            ),
          ],
        ],
        if (!_batch) ...[
          const SizedBox(height: 18),
          if (draft.promoCode case final code?)
            Row(
              children: [
                TaraIcon(TaraIcons.check, size: 18, color: c.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.promoApplied(code),
                    style: TaraText.label.copyWith(color: c.success, fontWeight: FontWeight.w700),
                  ),
                ),
                TaraLink(label: l.removeDelivery, onPressed: () => unawaited(_removePromo())),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TaraTextField(
                    label: l.promoLabel,
                    hint: l.promoHint,
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_applyPromo()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: GlassButton(
                    label: l.applyPromo,
                    height: 48,
                    color: c.accentText,
                    onPressed: _applying ? null : () => unawaited(_applyPromo()),
                  ),
                ),
              ],
            ),
          if (_promoError != null) ...[const SizedBox(height: 6), ErrorLine(_promoError!)],
        ],
        const SizedBox(height: 20),
        label(l.whoPays),
        ChoiceChips<String>(
          options: [ChoiceOption('SENDER', l.payerMe), ChoiceOption('RECIPIENT', l.payerRecipient)],
          selected: draft.feePayer,
          onSelected: _setPayer,
        ),
        const SizedBox(height: 8),
        if (!draft.senderPays)
          Text(l.recipientPaysBody, style: TaraText.small.copyWith(color: c.textTertiary))
        else ...[
          const SizedBox(height: 12),
          label(l.paymentLabel),
          for (final (method, icon, title, body) in [
            ('MOMO_MTN', TaraIcons.phone, l.payMtn, l.payMomoBody),
            ('MOMO_ORANGE', TaraIcons.phone, l.payOrange, l.payMomoBody),
            ('WALLET', TaraIcons.wallet, walletOption.title, walletOption.body),
            ('CASH', TaraIcons.cash, l.payCash, l.payCashBody),
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
            if (widget.showErrors && !isCameroonMobile(draft.payerPhone)) ...[
              const SizedBox(height: 6),
              ErrorLine(l.phoneInvalid),
            ],
          ],
          if (widget.showErrors && !draft.hasPayment && !draft.momo) ...[
            const SizedBox(height: 6),
            ErrorLine(l.paymentRequired),
          ],
        ],
        if (widget.error != null) ...[const SizedBox(height: 14), ErrorLine(widget.error!)],
      ],
    );
  }
}

/// Une livraison du récapitulatif : destinataire, adresse (ou attente de son point), colis.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.index,
    required this.delivery,
    required this.numbered,
    required this.onEdit,
    this.onRemove,
  });

  final int index;
  final DeliveryDraft delivery;
  final bool numbered;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final d = delivery;
    final first = d.recipientName.trim().split(RegExp(r'\s+')).first;
    final package = [
      contentsText(l, d.contents ?? 'OTHER'),
      d.bulky ? l.sizeBulky : d.size,
      if (d.bulky && d.loadingHelp) l.loadingHelpShort,
      if (d.fragile) l.fragileTitle,
      if (d.codAmount > 0) '${l.codLabel} : ${formatAmount(d.codAmount)} F',
    ].join(' · ');
    return GlassCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (numbered)
                      Text(
                        l.deliveryNumber(index + 1).toUpperCase(),
                        style: TaraText.overline.copyWith(color: c.accentText),
                      ),
                    Text(
                      d.recipientName.trim(),
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        displayPhone(d.recipientPhone),
                        if (d.dropoff case final address?) address.summary else l.waitingPoint(first),
                      ].join(' · '),
                      style: TaraText.small.copyWith(color: d.dropoff == null ? c.dangerText : c.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(package, style: TaraText.small.copyWith(color: c.textTertiary)),
                    // Plusieurs colis : les frais d'échec de chacun (moto ≠ tricycle).
                    if (d.quote case final quote? when numbered && (quote.retryFee > 0 || quote.returnFee > 0)) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.cardFailureFees(
                          '${formatAmount(quote.retryFee)}\u00a0F',
                          '${formatAmount(quote.returnFee)}\u00a0F',
                        ),
                        style: TaraText.small.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (d.quote case final quote?)
                Text(
                  '${formatAmount(quote.totalPrice)} F',
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                )
              else if (d.dropoff != null && d.quoteError == null)
                const GooLoader(compact: true),
            ],
          ),
          if (d.quoteError != null) ...[const SizedBox(height: 6), ErrorLine(d.quoteError!)],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onRemove != null) TaraLink(label: l.removeDelivery, onPressed: onRemove),
              const SizedBox(width: 12),
              TaraLink(label: l.change, onPressed: onEdit),
            ],
          ),
        ],
      ),
    );
  }
}

/// Détail du prix : course, suppléments, réduction (une livraison) ou prix de chaque
/// livraison (lot), puis le total.
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.draft});

  final OrderDraft draft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    String amount(int value) => '${formatAmount(value)} F';
    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TaraText.label.copyWith(color: c.textSecondary)),
          ),
          Text(
            value,
            style: TaraText.label.copyWith(color: color ?? c.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    final deliveries = draft.deliveries;
    final single = deliveries.length == 1 ? deliveries.first.quote : null;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (single != null) ...[
            line(single.vehicleType == 'TRICYCLE' ? l.priceBaseTricycle : l.priceBase, amount(single.basePrice)),
            for (final surcharge in single.surcharges)
              line(switch (surcharge.code) {
                'EXPRESS' => l.surchargeExpress,
                'HEAVY_PARCEL' => l.surchargeHeavy,
                'HANDLING' => l.surchargeHandling,
                'NIGHT' => l.surchargeNight,
                'WEATHER' => l.surchargeWeather,
                _ => l.surchargeOther,
              }, '+${amount(surcharge.amount)}'),
            if (single.discountTotal > 0)
              line(
                single.discountSource == 'VOLUME' ? l.proDiscountLine(percent(single.proDiscountBps)) : l.discount,
                '−${amount(single.discountTotal)}',
                color: c.success,
              ),
            if (single.valueFee > 0) line(l.valueFeeLine, '+${amount(single.valueFee)}'),
          ] else if (deliveries.length > 1)
            for (final (i, d) in deliveries.indexed)
              line('${i + 1}. ${d.recipientName.trim()}', d.quote == null ? '…' : amount(d.quote!.totalPrice)),
          // Frais de l'opérateur, payés en plus seulement par Mobile Money.
          if (draft.allQuoted && draft.mobileMoneyFeeAmount > 0)
            line(l.mobileMoneyFeeLine, '+${amount(draft.mobileMoneyFeeAmount)}'),
          if (single != null || deliveries.length > 1) Divider(height: 18, color: c.glassBorder),
          Row(
            children: [
              Expanded(
                child: Text(
                  deliveries.length > 1 ? '${l.totalLabel} · ${l.deliveriesCount(deliveries.length)}' : l.totalLabel,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              if (draft.allQuoted)
                Text(
                  amount(draft.amountToPay),
                  style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontFeatures: TaraText.tabular),
                )
              else
                Text(l.quoting, style: TaraText.label.copyWith(color: c.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pourcentage lisible depuis des points de base : 1000 → « 10 % », 1250 → « 12,5 % ».
String percent(int bps) {
  final whole = bps % 100 == 0;
  final value = whole ? '${bps ~/ 100}' : (bps / 100).toStringAsFixed(1).replaceAll('.', ',');
  return '$value %';
}
