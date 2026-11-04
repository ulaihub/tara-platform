import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'order_draft.dart';
import 'prohibited_items.dart';

/// Libellé d'une nature de contenu (C1) dans la langue de l'app.
String contentsText(AppLocalizations l, String code) => switch (code) {
  'DOCUMENTS' => l.contentsDocuments,
  'CLOTHING' => l.contentsClothing,
  'MEDICINE' => l.contentsMedicine,
  'LAUNDRY' => l.contentsLaundry,
  'HOUSEHOLD' => l.contentsHousehold,
  'ELECTRONICS' => l.contentsElectronics,
  'FOOD' => l.contentsFood,
  'BEAUTY' => l.contentsBeauty,
  'SECONDHAND' => l.contentsSecondhand,
  _ => l.contentsOther,
};

String _descriptionHint(AppLocalizations l, String? code) => switch (code) {
  'DOCUMENTS' => l.descriptionHintDocuments,
  'CLOTHING' => l.descriptionHintClothing,
  'MEDICINE' => l.descriptionHintMedicine,
  'LAUNDRY' => l.descriptionHintLaundry,
  'HOUSEHOLD' => l.descriptionHintHousehold,
  'ELECTRONICS' => l.descriptionHintElectronics,
  'FOOD' => l.descriptionHintFood,
  'BEAUTY' => l.descriptionHintBeauty,
  'SECONDHAND' => l.descriptionHintSecondhand,
  _ => l.descriptionHintOther,
};

/// Tailles (C2) et poids maximal de chacune.
const packageSizes = [('S', 2), ('M', 5), ('L', 10), ('XL', 20)];

/// Étape 3 · Colis : nature (tout type d'objet), précision, taille, fragile, montant à
/// encaisser (marchands), valeur, instructions, rappel des objets interdits. La nature
/// suggère taille et fragilité tant que l'expéditeur ne les a pas choisies.
class PackageStep extends StatefulWidget {
  const PackageStep({super.key, required this.draft, required this.merchant, required this.showErrors});

  final OrderDraft draft;

  /// Le montant à encaisser est réservé aux marchands.
  final bool merchant;
  final bool showErrors;

  @override
  State<PackageStep> createState() => _PackageStepState();
}

class _PackageStepState extends State<PackageStep> {
  late final _description = TextEditingController(text: _d.description);
  late final _cod = TextEditingController(text: _d.codAmount == 0 ? '' : formatAmount(_d.codAmount));
  late final _value = TextEditingController(text: _d.declaredValue == null ? '' : formatAmount(_d.declaredValue!));
  late final _instructions = TextEditingController(text: _d.instructions);

  DeliveryDraft get _d => widget.draft.delivery;

  @override
  void initState() {
    super.initState();
    _description.addListener(() {
      if (_description.text != _d.description) widget.draft.update((d) => d.description = _description.text);
    });
    _cod.addListener(() {
      final amount = AmountInputFormatter.valueOf(_cod.text) ?? 0;
      if (amount != _d.codAmount) widget.draft.update((d) => d.codAmount = amount);
    });
    _value.addListener(() {
      final amount = AmountInputFormatter.valueOf(_value.text);
      if (amount != _d.declaredValue) widget.draft.update((d) => d.declaredValue = amount);
    });
    _instructions.addListener(() {
      if (_instructions.text != _d.instructions) widget.draft.update((d) => d.instructions = _instructions.text);
    });
  }

  @override
  void dispose() {
    _description.dispose();
    _cod.dispose();
    _value.dispose();
    _instructions.dispose();
    super.dispose();
  }

  /// Nature choisie : documents → petit colis ; vaisselle, électronique → fragile.
  void _chooseContents(String code) => widget.draft.update((d) {
    d.contents = code;
    if (!d.sizeChosen && code == 'DOCUMENTS') d.size = 'S';
    if (!d.fragileChosen) d.fragile = code == 'HOUSEHOLD' || code == 'ELECTRONICS';
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final d = _d;
    final errors = widget.showErrors;
    final other = d.contents == 'OTHER';
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TaraText.label.copyWith(color: c.textSecondary)),
    );
    Widget help(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: TaraText.small.copyWith(color: c.textTertiary)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.packageTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: 8),
        Text(l.packageBody, style: TaraText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 18),
        label(l.contentsLabel),
        ChoiceChips<String>(
          options: [for (final code in packageContentsCodes) ChoiceOption(code, contentsText(l, code))],
          selected: d.contents,
          onSelected: _chooseContents,
        ),
        if (errors && d.contents == null) ...[const SizedBox(height: 6), ErrorLine(l.contentsRequired)],
        const SizedBox(height: 14),
        TaraTextField(
          label: other ? l.descriptionLabelRequired : l.descriptionLabel,
          hint: _descriptionHint(l, d.contents),
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
        ),
        if (errors && other && d.description.trim().length < 2) ...[
          const SizedBox(height: 6),
          ErrorLine(l.descriptionRequired),
        ],
        const SizedBox(height: 18),
        label(l.sizeLabel),
        _SizeTiles(
          selected: d.size,
          onSelected: (size) => widget.draft.update(
            (d) => d
              ..size = size
              ..sizeChosen = true,
          ),
        ),
        help(switch (d.size) {
          'M' => l.sizeHelpM,
          'L' => l.sizeHelpL,
          'XL' => l.sizeHelpXL,
          _ => l.sizeHelpS,
        }),
        const SizedBox(height: 14),
        _FragileRow(
          value: d.fragile,
          onChanged: (value) => widget.draft.update(
            (d) => d
              ..fragile = value
              ..fragileChosen = true,
          ),
        ),
        if (widget.merchant) ...[
          const SizedBox(height: 18),
          TaraTextField(
            label: l.codLabel,
            hint: l.codHint,
            controller: _cod,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountInputFormatter(maxDigits: 7)],
          ),
          if (d.codAmount > DeliveryDraft.maxCod) ...[const SizedBox(height: 6), ErrorLine(l.codTooHigh)],
          help(l.codHelp),
        ],
        const SizedBox(height: 18),
        TaraTextField(
          label: l.valueLabel,
          hint: l.valueHint,
          controller: _value,
          keyboardType: TextInputType.number,
          inputFormatters: [AmountInputFormatter(maxDigits: 8)],
        ),
        if ((d.declaredValue ?? 0) > DeliveryDraft.maxDeclaredValue) ...[
          const SizedBox(height: 6),
          ErrorLine(l.valueTooHigh),
        ],
        help(l.valueHelp),
        const SizedBox(height: 18),
        TaraTextField(
          label: l.instructionsLabel,
          hint: l.instructionsHint,
          controller: _instructions,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
        ),
        const SizedBox(height: 22),
        const ProhibitedItemsNote(),
      ],
    );
  }
}

/// Les quatre tailles côte à côte : lettre et poids maximal.
class _SizeTiles extends StatelessWidget {
  const _SizeTiles({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Row(
      children: [
        for (final (i, (size, kg)) in packageSizes.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              inMutuallyExclusiveGroup: true,
              checked: size == selected,
              button: true,
              label: '$size, ${l.sizeMax(kg)}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(size);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: size == selected ? c.chipSelected : null,
                    color: size == selected ? null : c.glass,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: size == selected ? c.chipSelectedBorder : c.glassBorder,
                      width: size == selected ? c.chipSelectedBorderWidth : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        size,
                        style: TaraText.titlePanel.copyWith(color: size == selected ? c.accentText : c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(l.sizeMax(kg), maxLines: 1, style: TaraText.small.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// « Fragile » : toute la ligne bascule l'interrupteur.
class _FragileRow extends StatelessWidget {
  const _FragileRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: GlassCard(
          radius: 20,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.fragileTitle,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(l.fragileBody, style: TaraText.small.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GlassSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
