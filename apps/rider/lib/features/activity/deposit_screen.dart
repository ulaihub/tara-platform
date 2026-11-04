import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/offline/action_queue.dart' show newEventId;
import '../../core/realtime/realtime_client.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/phone_format.dart';
import '../course/collection_screen.dart' show guessOperator;
import '../course/course_scaffold.dart' show CourseFieldLabel;

enum _DepositState { idle, sending, waiting, done, failed }

/// Montants de recharge proposés ; un autre montant peut être tapé.
const topUpAmounts = [5000, 10000, 25000, 50000];
const topUpMin = 500;
const topUpMax = 500000;

/// Paiement Mobile Money à Tara depuis le téléphone du livreur (G5), confirmé en direct
/// (sinon relu toutes les 5 s) : recharge du solde prépayé, ou dépôt des espèces encore
/// dues (ancien fonctionnement).
class DepositScreen extends ConsumerStatefulWidget {
  /// Dépôt des espèces détenues, en une fois.
  const DepositScreen({super.key, required this.amount, required this.onBack, required this.onDone})
    : topUp = false,
      available = 0;

  /// Recharge du solde prépayé : montant au choix (frais de l'opérateur pour Tara).
  const DepositScreen.topUp({super.key, required this.available, required this.onBack, required this.onDone})
    : topUp = true,
      amount = 0;

  /// Espèces à déposer (dépôt).
  final int amount;

  /// Recharge plutôt que dépôt.
  final bool topUp;

  /// Solde disponible avant la recharge.
  final int available;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  final _phone = TextEditingController();
  final _other = TextEditingController();
  String? _operator;

  /// Montant choisi parmi les puces (l'autre montant tapé l'emporte).
  int _chip = topUpAmounts[1];
  _DepositState _state = _DepositState.idle;
  String? _error;
  String? _paymentId;

  /// Même demande renvoyée (réponse perdue) : pas de second paiement. Une demande changée
  /// (montant, numéro, opérateur) en est une autre.
  String _key = newEventId();
  String? _sentWith;

  /// Montant de la dernière demande envoyée (affiché une fois payé).
  int _sent = 0;
  StreamSubscription<RealtimeEvent>? _events;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() {
      final guess = guessOperator(digitsOf(_phone.text));
      setState(() {
        _error = null;
        if (guess != null && _state == _DepositState.idle) _operator = guess;
      });
    });
    _other.addListener(() => setState(() => _error = null));
    unawaited(_prefillPhone());
  }

  int get _amount => widget.topUp ? (int.tryParse(_other.text) ?? _chip) : widget.amount;
  bool get _amountValid => widget.topUp ? _amount >= topUpMin && _amount <= topUpMax : _amount > 0;

  /// Numéro du livreur proposé par défaut (modifiable).
  Future<void> _prefillPhone() async {
    try {
      final me = await ref.read(riderApiProvider).me();
      final digits = digitsOf(me['phone'] as String? ?? '').replaceFirst(RegExp('^237'), '');
      if (!mounted || _phone.text.isNotEmpty) return;
      _phone.text = PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
    } catch (_) {
      // Sans réseau : le livreur tape son numéro.
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _poll?.cancel();
    _phone.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final digits = digitsOf(_phone.text);
    final operator = _operator;
    if (!isCameroonMobile(digits) || operator == null) {
      setState(() => _error = l.phoneInvalid);
      return;
    }
    if (!_amountValid) {
      setState(() => _error = l.topUpRange('${formatAmount(topUpMin)} F', '${formatAmount(topUpMax)} F'));
      return;
    }
    final request = '$_amount|$digits|$operator';
    if (_sentWith != null && _sentWith != request) _key = newEventId();
    _sentWith = request;
    _sent = _amount;
    setState(() {
      _state = _DepositState.sending;
      _error = null;
    });
    unawaited(_events?.cancel());
    _events = ref.read(realtimeProvider).stream.listen(_onEvent);
    try {
      final api = ref.read(riderApiProvider);
      final payment = widget.topUp
          ? await api.topUp(amount: _amount, phone: '+237$digits', operator: operator, idempotencyKey: _key)
          : await api.depositCash(amount: _amount, phone: '+237$digits', operator: operator, idempotencyKey: _key);
      if (!mounted) return;
      _paymentId = payment.id;
      _apply(payment.status);
      if (_state == _DepositState.sending) setState(() => _state = _DepositState.waiting);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_check()));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _DepositState.idle;
        _error = error.isNetwork ? l.momoNeedsNetwork : errorMessage(context, error);
      });
    }
  }

  void _onEvent(RealtimeEvent event) {
    if (event.name != 'payment.status' || event.payload['paymentId'] != _paymentId) return;
    _apply(event.payload['status'] as String?);
  }

  Future<void> _check() async {
    final id = _paymentId;
    if (id == null || _state != _DepositState.waiting) return;
    try {
      _apply((await ref.read(riderApiProvider).payment(id)).status);
    } catch (_) {
      // Réseau coupé : prochain passage.
    }
  }

  void _apply(String? status) {
    if (!mounted) return;
    switch (status) {
      case 'SUCCEEDED':
        _poll?.cancel();
        setState(() => _state = _DepositState.done);
      case 'FAILED' || 'CANCELLED':
        _poll?.cancel();
        setState(() {
          _state = _DepositState.failed;
          // Nouvelle demande : nouvel identifiant.
          _key = newEventId();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final operators = ref.watch(riderConfigProvider).value?.operators ?? const <MobileMoneyOperator>[];
    final topUp = widget.topUp;
    final busy = _state == _DepositState.sending || _state == _DepositState.waiting;
    final done = _state == _DepositState.done;
    final amount = '${formatAmount(done ? _sent : _amount)} F';

    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: busy ? null : widget.onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    topUp ? l.topUpTitle : l.depositTitle,
                    style: TaraText.titleCourse.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topUp ? l.balanceAvailable : l.cashToDeposit,
                  style: TaraText.label.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 4),
                AmountText(topUp ? widget.available + (done ? _sent : 0) : widget.amount, style: TaraText.amountL),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (done)
            TintBox(
              tone: TintTone.success,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  topUp ? l.topUpDone(amount) : l.depositDone(amount),
                  style: TaraText.text.copyWith(color: c.textPrimary),
                ),
              ),
            )
          else ...[
            if (topUp) ...[
              CourseFieldLabel(l.topUpAmount),
              const SizedBox(height: 8),
              ChoiceChips<int>(
                options: [for (final value in topUpAmounts) ChoiceOption(value, '${formatAmount(value)} F')],
                selected: _other.text.isEmpty ? _chip : null,
                onSelected: (value) {
                  if (busy) return;
                  _other.clear();
                  setState(() => _chip = value);
                },
                height: 50,
              ),
              const SizedBox(height: 10),
              IgnorePointer(
                ignoring: busy,
                child: TaraTextField(
                  label: l.topUpOther,
                  hint: l.topUpOtherHint,
                  controller: _other,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                ),
              ),
              const SizedBox(height: 16),
            ],
            CourseFieldLabel(l.depositOperator),
            const SizedBox(height: 8),
            ChoiceChips<String>(
              options: [for (final operator in operators) ChoiceOption(operator.code, operator.name)],
              selected: _operator,
              onSelected: (value) {
                if (!busy) setState(() => _operator = value);
              },
            ),
            const SizedBox(height: 14),
            TaraTextField(
              label: l.depositNumber,
              hint: l.phoneHint,
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
            ),
            const SizedBox(height: 12),
            TintBox(
              child: Row(
                children: [
                  if (busy) ...[const SizedBox(width: 44, child: GooLoader(compact: true)), const SizedBox(width: 10)],
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        busy
                            ? l.depositWaiting
                            : topUp
                            ? l.topUpBody(amount)
                            : l.depositBody(amount),
                        style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(topUp ? l.topUpOffice : l.depositOffice, style: TaraText.small.copyWith(color: c.textTertiary)),
            if (_state == _DepositState.failed) ...[
              const SizedBox(height: 12),
              ErrorLine(topUp ? l.topUpFailed : l.depositFailed),
            ],
          ],
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: done
            ? PrimaryButton(label: l.close, icon: TaraIcons.check, onPressed: widget.onDone)
            : PrimaryButton(
                label: l.depositSend,
                icon: TaraIcons.arrowRight,
                loading: busy,
                onPressed: _operator == null || _amount <= 0 ? null : _send,
              ),
      ),
    );
  }
}
