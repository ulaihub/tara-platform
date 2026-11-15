import 'dart:async';

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
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/offline/action_queue.dart' show newEventId;
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../course/course_scaffold.dart' show CourseFieldLabel;

/// Plus petit retrait partiel (comme le serveur) ; tout le solde peut toujours être retiré.
const withdrawMin = 500;

enum _WithdrawState { idle, sending, processing, approval, done, failed }

/// Retrait des gains vers le Mobile Money du livreur (G5) : tout le disponible par défaut ou
/// un autre montant, frais et montant reçu affichés avant de confirmer. Le retrait part sur
/// le numéro du compte, le seul permis.
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key, required this.wallet, required this.onBack, required this.onDone});

  final RiderWallet wallet;
  final VoidCallback onBack;

  /// Fermeture après une demande envoyée : le solde est relu.
  final VoidCallback onDone;

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70)];

  final _other = TextEditingController();
  String? _phone;
  String? _operator;
  _WithdrawState _state = _WithdrawState.idle;
  String? _error;
  Payout? _payout;

  /// Même demande renvoyée (réponse perdue) : pas de second retrait. Une demande changée
  /// (montant, opérateur) en est une autre.
  String _key = newEventId();
  String? _sentWith;
  StreamSubscription<RealtimeEvent>? _events;

  @override
  void initState() {
    super.initState();
    _other.addListener(() => setState(() => _error = null));
    unawaited(_loadPhone());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _other.dispose();
    super.dispose();
  }

  int get _available => widget.wallet.available;

  /// Autre montant tapé, sinon tout le disponible.
  int get _amount => int.tryParse(_other.text) ?? _available;
  bool get _amountValid => _amount == _available || (_amount >= withdrawMin && _amount <= _available);

  Future<void> _loadPhone() async {
    try {
      final phone = (await ref.read(riderApiProvider).me())['phone'] as String?;
      if (!mounted || phone == null) return;
      setState(() {
        _phone = phone;
        _operator ??= guessOperator(digitsOf(phone).replaceFirst(RegExp('^237'), ''));
      });
    } catch (_) {
      // Sans réseau : le bouton attend le numéro.
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final phone = _phone;
    final operator = _operator;
    if (phone == null || operator == null) return;
    if (!_amountValid) {
      setState(() => _error = l.withdrawRange(_f(withdrawMin), _f(_available)));
      return;
    }
    final amount = _amount;
    final request = '$amount|$operator';
    if (_sentWith != null && _sentWith != request) _key = newEventId();
    _sentWith = request;
    setState(() {
      _state = _WithdrawState.sending;
      _error = null;
    });
    unawaited(_events?.cancel());
    _events = ref.read(realtimeProvider).stream.listen(_onEvent);
    try {
      final payout = await ref
          .read(riderApiProvider)
          .withdraw(
            // Tout le disponible : le serveur le recalcule (rien ne reste si le solde a bougé).
            amount: amount == _available ? null : amount,
            phone: phone,
            operator: operator,
            idempotencyKey: _key,
          );
      if (!mounted) return;
      _payout = payout;
      _apply(payout.status);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _WithdrawState.idle;
        _error = errorMessage(context, error);
      });
    }
  }

  void _onEvent(RealtimeEvent event) {
    if (event.name != 'payout.status' || event.payload['payoutId'] != _payout?.id) return;
    _apply(event.payload['status'] as String?);
  }

  void _apply(String? status) {
    if (!mounted) return;
    switch (status) {
      case 'SUCCEEDED':
        if (_state != _WithdrawState.done) TaraFeedback.play(context, TaraSound.cash);
        setState(() => _state = _WithdrawState.done);
      case 'FAILED' || 'CANCELLED':
        setState(() {
          _state = _WithdrawState.failed;
          // Nouvelle demande : nouvel identifiant.
          _key = newEventId();
          _sentWith = null;
        });
      case 'AWAITING_APPROVAL':
        setState(() => _state = _WithdrawState.approval);
      case 'PENDING' || 'PROCESSING':
        setState(() => _state = _WithdrawState.processing);
    }
  }

  static String _f(int amount) => '${formatAmount(amount)} F';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final operators = ref.watch(riderConfigProvider).value?.operators ?? const <MobileMoneyOperator>[];
    final wallet = widget.wallet;
    final busy = _state == _WithdrawState.sending;
    final sent = switch (_state) {
      _WithdrawState.processing || _WithdrawState.approval || _WithdrawState.done => true,
      _ => false,
    };
    final amount = _payout?.amount ?? _amount;
    final fee = _payout?.withdrawalFee ?? wallet.withdrawalFeeFor(amount);
    final received = _payout?.received ?? amount - fee;

    return TaraScreen(
      safeBottom: false,
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
                  child: Text(l.withdrawTitle, style: TaraText.titleCourse.copyWith(color: c.textPrimary)),
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
                Text(l.balanceAvailable, style: TaraText.label.copyWith(color: c.textSecondary)),
                const SizedBox(height: 4),
                AmountText(sent ? _available - amount : _available, style: TaraText.amountL),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (sent)
            TintBox(
              tone: _state == _WithdrawState.done ? TintTone.success : TintTone.accent,
              child: Semantics(
                liveRegion: true,
                child: Text(switch (_state) {
                  _WithdrawState.done => l.withdrawSent(_f(received)),
                  _WithdrawState.approval => l.withdrawApproval(_f(received)),
                  _ => l.withdrawProcessing(_f(received)),
                }, style: TaraText.text.copyWith(color: c.textPrimary)),
              ),
            )
          else ...[
            CourseFieldLabel(l.topUpAmount),
            const SizedBox(height: 8),
            ChoiceChips<int>(
              options: [ChoiceOption(_available, l.withdrawAll(_f(_available)))],
              selected: _other.text.isEmpty ? _available : null,
              onSelected: (_) {
                if (!busy) _other.clear();
              },
              height: 50,
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: busy,
              child: TaraTextField(
                label: l.topUpOther,
                hint: l.withdrawOtherHint,
                controller: _other,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              ),
            ),
            const SizedBox(height: 16),
            CourseFieldLabel(l.depositOperator),
            const SizedBox(height: 8),
            ChoiceChips<String>(
              options: [for (final operator in operators) ChoiceOption(operator.code, operator.name)],
              selected: _operator,
              onSelected: (value) {
                if (!busy) setState(() => _operator = value);
              },
            ),
            if (_phone case final phone?) ...[
              const SizedBox(height: 8),
              Text(l.withdrawTo(displayPhone(phone)), style: TaraText.small.copyWith(color: c.textSecondary)),
            ],
            const SizedBox(height: 16),
            TintBox(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.withdrawReceive, style: TaraText.label.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    AmountText(
                      _amountValid ? received : 0,
                      style: TaraText.titlePanel.copyWith(fontFeatures: TaraText.tabular),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fee == 0 ? l.withdrawFree : l.withdrawFeeFull(_f(fee)),
                      style: TaraText.small.copyWith(color: c.textSecondary),
                    ),
                    if (fee > 0)
                      Text(
                        l.withdrawFreeFrom(_f(wallet.withdrawalFreeFrom)),
                        style: TaraText.small.copyWith(color: c.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            if (_state == _WithdrawState.failed) ...[const SizedBox(height: 12), ErrorLine(l.withdrawFailed)],
          ],
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: sent
            ? PrimaryButton(label: l.close, icon: TaraIcons.check, onPressed: widget.onDone)
            : PrimaryButton(
                label: l.withdrawConfirm(_f(_amountValid ? received : 0)),
                icon: TaraIcons.arrowRight,
                loading: busy,
                onPressed: _phone == null || _operator == null || _available <= 0 ? null : _send,
              ),
      ),
    );
  }
}
