import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_typography.dart';

/// Texte juridique écrit en Markdown simple (docs/juridique) : titres `#`, `##`, `###`,
/// paragraphes, listes `-` et `1.`, tableaux `|`, gras `**`. Les tableaux sont présentés en
/// fiches empilées, lisibles sur un téléphone.
class LegalMarkdown extends StatelessWidget {
  const LegalMarkdown(this.markdown, {super.key, this.showTitle = true, this.compact = false});

  final String markdown;

  /// Carte de lecture des conditions (maquettes) : titres 14 en gras, texte 13.
  final bool compact;

  /// Titre `#` du document : masqué quand l'écran l'affiche déjà.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final blocks = parseLegalMarkdown(markdown);
    final body = compact
        ? TaraText.label.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: c.textPrimary.withValues(alpha: .76),
          )
        : _body(c);
    final children = <Widget>[];
    for (final block in blocks) {
      if (block is LegalHeading && block.level == 1 && !showTitle) continue;
      if (children.isNotEmpty) {
        children.add(SizedBox(height: compact ? (block is LegalHeading ? 10 : 2) : (block is LegalHeading ? 22 : 12)));
      }
      children.add(switch (block) {
        LegalHeading() => Semantics(
          header: true,
          child: Text.rich(
            _inline(block.text, c),
            style: compact
                ? TaraText.text.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary)
                : switch (block.level) {
                    1 => TaraText.titlePanel,
                    2 => TaraText.cardTitle,
                    _ => TaraText.bodyStrong,
                  }.copyWith(color: c.textPrimary),
          ),
        ),
        LegalParagraph() => Text.rich(_inline(block.text, c), style: body),
        LegalList() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item) in block.items.indexed)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        block.ordered ? '${index + 1}.' : '•',
                        style: body.copyWith(color: c.accentText, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(child: Text.rich(_inline(item, c), style: body)),
                  ],
                ),
              ),
          ],
        ),
        LegalTable() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, row) in block.rows.indexed)
              Container(
                margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.chipBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(_inline(row.first, c), style: TaraText.text.copyWith(color: c.textPrimary)),
                    for (final (column, cell) in row.indexed.skip(1))
                      if (cell.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (column < block.header.length)
                                  TextSpan(
                                    text: '${block.header[column]} : ',
                                    style: TextStyle(color: c.textTertiary, fontWeight: FontWeight.w600),
                                  ),
                                _inline(cell, c),
                              ],
                            ),
                            style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  static TextStyle _body(TaraColors c) => TaraText.body.copyWith(color: c.textSecondary);

  /// Gras `**…**` ; le reste tel quel.
  static TextSpan _inline(String text, TaraColors c) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (final (index, part) in parts.indexed) {
      if (part.isEmpty) continue;
      final bold = index.isOdd && index < parts.length - 1;
      spans.add(
        TextSpan(
          text: part,
          style: bold ? TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700) : null,
        ),
      );
    }
    return TextSpan(children: spans);
  }
}

sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, this.text);
  final int level;
  final String text;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);
  final String text;
}

class LegalList extends LegalBlock {
  const LegalList({required this.ordered, required this.items});
  final bool ordered;
  final List<String> items;
}

class LegalTable extends LegalBlock {
  const LegalTable({required this.header, required this.rows});
  final List<String> header;
  final List<List<String>> rows;
}

final _heading = RegExp(r'^(#{1,3}) (.+)$');
final _bullet = RegExp(r'^[-*] (.*)$');
final _numbered = RegExp(r'^\d+\. (.*)$');
final _separator = RegExp(r'^\|[\s:|-]+\|$');

/// Découpe le texte en blocs : une ligne vide termine un paragraphe ou une liste ; une
/// ligne indentée prolonge l'élément de liste en cours.
List<LegalBlock> parseLegalMarkdown(String markdown) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];
  List<String>? items;
  var ordered = false;
  List<String>? header;
  final rows = <List<String>>[];

  void flush() {
    if (paragraph.isNotEmpty) blocks.add(LegalParagraph(paragraph.join(' ')));
    paragraph.clear();
    if (items != null) blocks.add(LegalList(ordered: ordered, items: items!));
    items = null;
    if (header != null) blocks.add(LegalTable(header: header!, rows: List.of(rows)));
    header = null;
    rows.clear();
  }

  List<String> cells(String line) => line.substring(1, line.length - 1).split('|').map((cell) => cell.trim()).toList();

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
      if (header == null) {
        flush();
        header = cells(trimmed);
      } else if (!_separator.hasMatch(trimmed)) {
        rows.add(cells(trimmed));
      }
      continue;
    }
    final heading = _heading.firstMatch(trimmed);
    if (heading != null && line == trimmed) {
      flush();
      blocks.add(LegalHeading(heading.group(1)!.length, heading.group(2)!.trim()));
      continue;
    }
    final bullet = line == trimmed ? _bullet.firstMatch(trimmed) : null;
    final number = line == trimmed ? _numbered.firstMatch(trimmed) : null;
    if (bullet != null || number != null) {
      final isOrdered = number != null;
      if (items == null || ordered != isOrdered || paragraph.isNotEmpty) {
        flush();
        items = [];
        ordered = isOrdered;
      }
      items!.add((bullet ?? number)!.group(1)!.trim());
      continue;
    }
    if (items != null && line != trimmed) {
      items![items!.length - 1] = '${items!.last} $trimmed';
      continue;
    }
    if (items != null) flush();
    paragraph.add(trimmed);
  }
  flush();
  return blocks;
}
