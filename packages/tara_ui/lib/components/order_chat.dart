import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tara_core/api/order_chat_api.dart';

import '../motion/effects.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'buttons.dart';
import 'glass.dart';
import 'inputs.dart';
import 'layout.dart';

/// Libellés de la conversation, traduits par chaque app.
class OrderChatStrings {
  const OrderChatStrings({
    required this.back,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.send,
    required this.empty,
    required this.closed,
    required this.read,
    required this.quickReplies,
    required this.when,
    required this.errorText,
  });

  final String back;

  /// Nom de l'autre personne (« Rosine K. », « Boutique Mama Ngo »).
  final String title;

  /// Référence de la commande, étape.
  final String subtitle;
  final String hint;
  final String send;
  final String empty;
  final String closed;

  /// « Lu », sous le dernier message envoyé et lu.
  final String read;

  /// Réponses en un toucher (« J'arrive », « Je suis devant »).
  final List<String> quickReplies;
  final String Function(DateTime at) when;
  final String Function(Object error) errorText;
}

/// Clé du bouton d'envoi (tests des apps).
const orderChatSendKey = ValueKey('order-chat-send');

/// Conversation entre l'expéditeur et le livreur d'une commande : bulles, réponses
/// rapides, et champ de message tant que la course est en cours. Les messages reçus en
/// direct arrivent par [incoming].
class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({
    super.key,
    required this.load,
    required this.send,
    required this.strings,
    required this.onBack,
    this.incoming,
  });

  final Future<OrderChat> Function() load;
  final Future<OrderChatMessage> Function(String body) send;
  final OrderChatStrings strings;
  final VoidCallback onBack;
  final Stream<OrderChatMessage>? incoming;

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _text = TextEditingController();
  List<OrderChatMessage> _messages = const [];
  bool _open = true;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  StreamSubscription<OrderChatMessage>? _live;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _live = widget.incoming?.listen((message) {
      if (!mounted || _messages.any((m) => m.id == message.id)) return;
      HapticFeedback.lightImpact();
      setState(() => _messages = [..._messages, message]);
      // Ouverte : relue pour que l'autre voie « Lu ».
      unawaited(_reload());
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    _text.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final chat = await widget.load();
      if (!mounted) return;
      setState(() {
        _messages = chat.messages;
        _open = chat.open;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = widget.strings.errorText(error);
        });
      }
    }
  }

  Future<void> _send(String body) async {
    final text = body.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await widget.send(text);
      if (!mounted) return;
      _text.clear();
      setState(() => _messages = [..._messages, message]);
    } catch (error) {
      if (mounted) setState(() => _error = widget.strings.errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = TaraColors.of(context);
    final lastMine = _messages.lastIndexWhere((m) => m.mine);
    return TaraScreen(
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: s.back, onPressed: widget.onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                      Text(s.subtitle, style: TaraText.small.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Spin(period: Duration(milliseconds: 900), child: TaraIcon(TaraIcons.refresh, size: 22)),
            )
          else if (_messages.isEmpty)
            Text(s.empty, style: TaraText.text.copyWith(color: c.textSecondary)),
          for (final (index, message) in _messages.indexed) ...[
            Align(
              alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: message.mine
                    ? TintBox(
                        radius: 18,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: _Bubble(
                          message: message,
                          when: s.when,
                          read: index == lastMine && message.read ? s.read : null,
                        ),
                      )
                    : GlassCard(
                        radius: 18,
                        shadow: false,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: _Bubble(message: message, when: s.when),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!_open && !_loading) ...[
            const SizedBox(height: 8),
            InfoNote(text: s.closed, icon: TaraIcons.alertCircle),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Text(error, style: TaraText.label.copyWith(color: c.dangerText)),
          ],
        ],
        footer: _open
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: s.quickReplies.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final reply = s.quickReplies[index];
                        return GlassButton(
                          label: reply,
                          height: 36,
                          radius: 18,
                          onPressed: _sending ? null : () => unawaited(_send(reply)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TaraTextField(
                    hint: s.hint,
                    controller: _text,
                    maxLines: 3,
                    maxLength: 500,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    trailing: _SendButton(
                      label: s.send,
                      busy: _sending,
                      onPressed: _sending || _text.text.trim().isEmpty ? null : () => unawaited(_send(_text.text)),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: orderChatSendKey,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled || busy ? 1 : .45,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: TaraBrand.gradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: enabled ? c.brandShadow : null,
            ),
            child: const Center(child: TaraIcon(TaraIcons.send, size: 19, strokeWidth: 2.2, color: TaraBrand.onBrand)),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.when, this.read});

  final OrderChatMessage message;
  final String Function(DateTime at) when;
  final String? read;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.body, style: TaraText.body.copyWith(color: c.textPrimary, height: 1.35)),
          const SizedBox(height: 4),
          Text([when(message.at.toLocal()), ?read].join(' · '), style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}
