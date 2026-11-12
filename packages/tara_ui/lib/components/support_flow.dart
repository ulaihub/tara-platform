import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tara_core/api/support_api.dart';

import '../motion/liquid_background.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'buttons.dart';
import 'glass.dart';
import 'inputs.dart';
import 'layout.dart';

/// Libellés du service client, traduits par chaque app.
class SupportStrings {
  const SupportStrings({
    required this.back,
    required this.retry,
    required this.title,
    required this.intro,
    required this.newRequest,
    required this.empty,
    required this.callUs,
    required this.category,
    required this.status,
    required this.newTitle,
    required this.reasonLabel,
    required this.subjectLabel,
    required this.subjectHint,
    required this.messageLabel,
    required this.messageHint,
    required this.orderLine,
    required this.send,
    required this.replyHint,
    required this.replySend,
    required this.closedNote,
    required this.fromTara,
    required this.newAnswer,
    required this.waitingNote,
    required this.when,
    required this.errorText,
  });

  final String back;
  final String retry;
  final String title;
  final String intro;
  final String newRequest;
  final String empty;

  /// « Urgent ? Appelez le … » (numéro déjà mis en forme).
  final String Function(String phone) callUs;
  final String Function(SupportCategory category) category;
  final String Function(SupportStatus status) status;
  final String newTitle;
  final String reasonLabel;
  final String subjectLabel;
  final String subjectHint;
  final String messageLabel;
  final String messageHint;

  /// « Commande TR-7K3P9Q ».
  final String Function(String reference) orderLine;
  final String send;
  final String replyHint;
  final String replySend;
  final String closedNote;
  final String fromTara;
  final String newAnswer;

  /// Rappel sous une demande qui attend l'équipe.
  final String waitingNote;

  /// Date et heure lisibles (« 12 nov., 14:05 »).
  final String Function(DateTime at) when;

  /// Message d'une erreur (celui du serveur, ou réseau).
  final String Function(Object error) errorText;
}

const _blobs = [
  BlobSpec(alignment: Alignment(1.25, -1.0), size: 280, colors: BlobSpec.brand, blur: 70),
  BlobSpec(alignment: Alignment(-1.3, 0.9), size: 220, colors: BlobSpec.soft, blur: 64, delay: Duration(seconds: 6)),
];

const _subjectMin = 3;
const _messageMin = 2;

Widget _header(BuildContext context, {required String back, required VoidCallback onBack, required String title}) {
  final c = TaraColors.of(context);
  return Row(
    children: [
      GlassIconButton(icon: TaraIcons.chevronLeft, label: back, onPressed: onBack),
      const SizedBox(width: 12),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
      ),
    ],
  );
}

/// Aide et service client : les demandes de l'utilisateur (une réponse de Tara est
/// signalée), une nouvelle demande, et le numéro à appeler en cas d'urgence.
class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({
    super.key,
    required this.backend,
    required this.strings,
    required this.categories,
    required this.onBack,
    this.supportPhone,
    this.onCall,
  });

  final SupportBackend backend;
  final SupportStrings strings;

  /// Motifs proposés, dans l'ordre (ceux d'un expéditeur ou d'un livreur).
  final List<SupportCategory> categories;
  final VoidCallback onBack;

  /// Numéro du service client, déjà mis en forme, et l'appel.
  final String? supportPhone;
  final VoidCallback? onCall;

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  late Future<List<SupportTicket>> _tickets = widget.backend.tickets();

  void _reload() {
    final tickets = widget.backend.tickets();
    setState(() {
      _tickets = tickets;
    });
  }

  Future<void> _open(SupportTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (route) => SupportThreadScreen(
          backend: widget.backend,
          strings: widget.strings,
          ticket: ticket,
          onBack: () => Navigator.of(route).pop(),
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _new() async {
    final navigator = Navigator.of(context);
    final created = await navigator.push<SupportTicket>(
      MaterialPageRoute(
        builder: (route) => SupportNewScreen(
          backend: widget.backend,
          strings: widget.strings,
          categories: widget.categories,
          onBack: () => Navigator.of(route).pop(),
          onCreated: (ticket) => Navigator.of(route).pop(ticket),
        ),
      ),
    );
    if (!mounted) return;
    _reload();
    if (created != null) await _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = TaraColors.of(context);
    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          _header(context, back: s.back, onBack: widget.onBack, title: s.title),
          const SizedBox(height: 10),
          Text(s.intro, style: TaraText.body.copyWith(color: c.textSecondary)),
          if (widget.supportPhone case final phone? when widget.onCall != null) ...[
            const SizedBox(height: 12),
            TintBox(
              child: Row(
                children: [
                  TaraIcon(TaraIcons.phone, size: 18, color: c.accentText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TaraLink(label: s.callUs(phone), onPressed: widget.onCall),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FutureBuilder<List<SupportTicket>>(
            future: _tickets,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.errorText(snapshot.error!), style: TaraText.label.copyWith(color: c.dangerText)),
                    const SizedBox(height: 8),
                    TaraLink(label: s.retry, onPressed: _reload),
                  ],
                );
              }
              final tickets = snapshot.data;
              if (tickets == null) {
                return const Center(
                  child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                );
              }
              if (tickets.isEmpty) {
                return GlassCard(
                  radius: 22,
                  shadow: false,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const IconTile(icon: TaraIcons.headset),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.empty, style: TaraText.label.copyWith(color: c.textSecondary)),
                      ),
                    ],
                  ),
                );
              }
              return GlassCard(
                radius: 22,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (final ticket in tickets)
                      ListRow(
                        leading: IconTile(
                          icon: TaraIcons.message,
                          tone: ticket.answered && ticket.status.acceptsReplies ? TintTone.success : TintTone.accent,
                        ),
                        title: ticket.subject,
                        subtitle: '${ticket.reference} · ${s.status(ticket.status)} · ${s.when(ticket.updatedAt)}',
                        trailing: ticket.answered && ticket.status.acceptsReplies
                            ? InfoPill(label: s.newAnswer, tone: TintTone.success)
                            : TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
                        onTap: () => unawaited(_open(ticket)),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
        footer: PrimaryButton(label: s.newRequest, icon: TaraIcons.message, onPressed: () => unawaited(_new())),
      ),
    );
  }
}

/// Nouvelle demande : motif, titre, message ; sur une commande quand elle est ouverte
/// depuis le suivi d'une livraison.
class SupportNewScreen extends StatefulWidget {
  const SupportNewScreen({
    super.key,
    required this.backend,
    required this.strings,
    required this.categories,
    required this.onBack,
    required this.onCreated,
    this.orderId,
    this.orderReference,
  });

  final SupportBackend backend;
  final SupportStrings strings;
  final List<SupportCategory> categories;
  final VoidCallback onBack;
  final ValueChanged<SupportTicket> onCreated;
  final String? orderId;
  final String? orderReference;

  @override
  State<SupportNewScreen> createState() => _SupportNewScreenState();
}

class _SupportNewScreenState extends State<SupportNewScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  SupportCategory? _category;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject.addListener(() => setState(() {}));
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _ready =>
      _category != null && _subject.text.trim().length >= _subjectMin && _message.text.trim().length >= _messageMin;

  Future<void> _send() async {
    final category = _category;
    if (category == null || !_ready) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final ticket = await widget.backend.open(
        category: category,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        orderId: widget.orderId,
      );
      if (mounted) widget.onCreated(ticket);
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
    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          _header(context, back: s.back, onBack: widget.onBack, title: s.newTitle),
          if (widget.orderReference case final reference?) ...[
            const SizedBox(height: 12),
            InfoPill(label: s.orderLine(reference), icon: TaraIcons.package, tone: TintTone.accent),
          ],
          const SizedBox(height: 18),
          Text(s.reasonLabel, style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          ChoiceChips<SupportCategory>(
            options: [for (final category in widget.categories) ChoiceOption(category, s.category(category))],
            selected: _category,
            onSelected: (category) => setState(() => _category = category),
          ),
          const SizedBox(height: 16),
          TaraTextField(
            label: s.subjectLabel,
            hint: s.subjectHint,
            controller: _subject,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TaraTextField(
            label: s.messageLabel,
            hint: s.messageHint,
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Text(error, style: TaraText.label.copyWith(color: c.dangerText)),
          ],
        ],
        footer: PrimaryButton(
          label: s.send,
          icon: TaraIcons.send,
          loading: _sending,
          onPressed: _ready ? () => unawaited(_send()) : null,
        ),
      ),
    );
  }
}

/// Échanges d'une demande : messages de l'utilisateur et réponses de Tara, et sa réponse
/// tant que la demande n'est pas close.
class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({
    super.key,
    required this.backend,
    required this.strings,
    required this.ticket,
    required this.onBack,
  });

  final SupportBackend backend;
  final SupportStrings strings;
  final SupportTicket ticket;
  final VoidCallback onBack;

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  late SupportTicket _ticket = widget.ticket;
  final _reply = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    // Relue à l'ouverture : une réponse a pu arriver depuis la liste.
    unawaited(
      widget.backend.ticket(_ticket.id).then((fresh) {
        if (mounted) setState(() => _ticket = fresh);
      }, onError: (Object _) {}),
    );
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.length < _messageMin) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await widget.backend.reply(_ticket.id, body);
      if (!mounted) return;
      _reply.clear();
      setState(() => _ticket = updated);
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
    final ticket = _ticket;
    final waiting = ticket.status.acceptsReplies && !ticket.answered;
    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 8,
        content: [
          _header(context, back: s.back, onBack: widget.onBack, title: ticket.subject),
          const SizedBox(height: 8),
          Text(
            [
              ticket.reference,
              s.status(ticket.status),
              if (ticket.orderReference case final reference?) s.orderLine(reference),
            ].join(' · '),
            style: TaraText.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final message in ticket.messages) ...[
            Align(
              alignment: message.fromTara ? Alignment.centerLeft : Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: message.fromTara
                    ? GlassCard(
                        radius: 18,
                        shadow: false,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: _Bubble(title: s.fromTara, message: message, when: s.when, accent: true),
                      )
                    : TintBox(
                        radius: 18,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: _Bubble(title: null, message: message, when: s.when, accent: false),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (waiting) ...[
            const SizedBox(height: 4),
            Text(s.waitingNote, style: TaraText.small.copyWith(color: c.textTertiary)),
          ],
          if (!ticket.status.acceptsReplies) ...[
            const SizedBox(height: 8),
            InfoNote(text: s.closedNote, icon: TaraIcons.alertCircle),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Text(error, style: TaraText.label.copyWith(color: c.dangerText)),
          ],
        ],
        footer: ticket.status.acceptsReplies
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TaraTextField(
                      hint: s.replyHint,
                      controller: _reply,
                      maxLines: 4,
                      maxLength: 2000,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassIconButton(
                    icon: TaraIcons.send,
                    label: s.replySend,
                    onPressed: _sending || _reply.text.trim().length < _messageMin ? null : () => unawaited(_send()),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.title, required this.message, required this.when, required this.accent});

  final String? title;
  final SupportMessage message;
  final String Function(DateTime at) when;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title case final title?)
            Text(
              title,
              style: TaraText.small.copyWith(color: c.accentText, fontWeight: FontWeight.w700),
            ),
          Text(message.body, style: TaraText.body.copyWith(color: c.textPrimary, height: 1.35)),
          const SizedBox(height: 4),
          Text(when(message.at.toLocal()), style: TaraText.small.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}
