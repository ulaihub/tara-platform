import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import 'bulk_draft.dart';
import 'paste_parser.dart';

/// Quartiers connus de Tara, pour écrire le quartier d'une liste collée comme il faut.
final neighborhoodNamesProvider = FutureProvider<List<String>>((ref) async {
  final all = await ref.read(clientApiProvider).neighborhoods();
  return [for (final n in all) n.name];
});

/// Envoi en masse · coller une liste (WhatsApp, notes) : Tara la lit sur le téléphone et
/// montre ce qu'il a compris, ligne par ligne, avant d'ajouter les clients.
class PasteScreen extends ConsumerStatefulWidget {
  const PasteScreen({super.key, required this.room, required this.known, this.initialText});

  /// Places encore libres dans la liste (100 au plus).
  final int room;

  /// Clients connus par numéro national : leur adresse est reprise.
  final Map<String, Recipient> known;

  /// Texte déjà collé (tests).
  final String? initialText;

  @override
  ConsumerState<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends ConsumerState<PasteScreen> {
  static const _blobs = [BlobSpec(alignment: Alignment(1.25, -1.05), size: 240, colors: BlobSpec.brand, blur: 70)];

  late final _text = TextEditingController(text: widget.initialText ?? '');

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    _text.text = _text.text.trim().isEmpty ? text : '${_text.text.trimRight()}\n$text';
  }

  List<ParsedLine> _parsed(List<String> neighborhoods) =>
      parseList(_text.text, neighborhoods: neighborhoods, limit: widget.room);

  BulkLine _toLine(ParsedLine parsed) {
    final line = BulkLine.parsed(parsed);
    final known = widget.known[line.phone];
    if (known != null) line.dropoff = known.lastAddress;
    return line;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final neighborhoods = ref.watch(neighborhoodNamesProvider).value ?? const <String>[];
    final parsed = _parsed(neighborhoods);
    final ok = parsed.where((p) => p.ok).length;
    // Une ligne à corriger s'ajoute aussi : elle reste « à compléter » dans la liste.
    final addable = parsed.where((p) => p.name.isNotEmpty || p.phone != null).toList();
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
            child: Row(
              children: [
                GlassIconButton(icon: TaraIcons.close, label: l.close, onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.pasteTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ScrollWithFooter(
              horizontal: 20,
              top: 12,
              content: [
                Text(l.pasteBody, style: TaraText.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: 14),
                TaraTextField(
                  label: l.pasteLabel,
                  hint: l.pasteHint,
                  controller: _text,
                  keyboardType: TextInputType.multiline,
                  minLines: 5,
                  maxLines: 8,
                  height: 150,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TaraLink(label: l.pasteFromClipboard, onPressed: () => unawaited(_fromClipboard())),
                ),
                if (parsed.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(l.pasteUnderstood, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                      ),
                      InfoPill(
                        label: l.pasteScore(ok, parsed.length),
                        tone: ok == parsed.length ? TintTone.success : TintTone.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    radius: 20,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, line) in parsed.indexed) ...[
                          if (i > 0) Divider(height: 1, color: c.glassBorder),
                          _ParsedRow(line: line, known: widget.known.containsKey(line.phone)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(l.pasteNote, style: TaraText.small.copyWith(color: c.textTertiary, height: 1.45)),
                ],
              ],
              footer: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.pastePrivacy,
                    textAlign: TextAlign.center,
                    style: TaraText.small.copyWith(color: c.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: l.bulkAddCount(addable.length),
                    icon: TaraIcons.plus,
                    onPressed: addable.isEmpty
                        ? null
                        : () => Navigator.of(context).pop([for (final p in addable) _toLine(p)]),
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

class _ParsedRow extends StatelessWidget {
  const _ParsedRow({required this.line, required this.known});

  final ParsedLine line;
  final bool known;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final problem = switch (line.problem) {
      LineProblem.phoneIncomplete => l.bulkPhoneIncomplete(line.rawPhone ?? ''),
      LineProblem.phoneMissing => l.bulkPhoneMissing,
      LineProblem.nameMissing => l.bulkNameMissing,
      null => null,
    };
    final hint = line.neighborhood ?? line.hint;
    final place = hint.isEmpty ? null : hint;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          TaraIcon(
            problem == null ? TaraIcons.check : TaraIcons.alertCircle,
            size: 20,
            strokeWidth: 2.4,
            color: problem == null ? c.success : c.dangerText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: line.name.isEmpty ? '—' : line.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: [
                      '',
                      if (line.phone != null) displayPhone(line.phone!),
                      ?problem,
                      if (known) l.pasteKnownAddress else ?place,
                    ].join(' · '),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TaraText.small.copyWith(color: problem == null ? c.textPrimary : c.dangerText),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            line.amount > 0 ? '${formatAmount(line.amount)} F' : '—',
            style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
