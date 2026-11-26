import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'order_draft.dart';
import 'parcel_photo_card.dart';
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

/// Étape 3 · Colis : nature (tout type d'objet), précision, taille (ou « Gros objet », livré
/// en tricycle, avec aide au chargement à la demande), fragile, montant à encaisser
/// (marchands), valeur, instructions, rappel des objets interdits. La nature suggère taille
/// et fragilité tant que l'expéditeur ne les a pas choisies.
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

  /// Proposition tirée de la photo : elle remplit le formulaire, l'expéditeur vérifie. Une
  /// précision déjà écrite par l'expéditeur est gardée.
  void _applyAnalysis(ParcelAnalysis analysis) {
    widget.draft.update((d) {
      d.parcelAnalysis = analysis;
      if (!analysis.isParcel) return;
      d
        ..contents = analysis.contents
        ..size = analysis.size
        ..sizeChosen = true
        ..fragile = analysis.fragile
        ..fragileChosen = true;
    });
    final description = analysis.description;
    if (analysis.isParcel && description != null && _description.text.trim().isEmpty) {
      _description.text = description;
    }
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
    Widget section(String text) => Text(
      text,
      style: TaraText.label.copyWith(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
    );
    const gap = SizedBox(height: 10);
    final value = d.declaredValue ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.packageTitle, style: TaraText.titleForm.copyWith(color: c.textPrimary, fontSize: 22)),
        ),
        gap,
        ParcelPhotoCard(
          delivery: d,
          onAnalyzed: _applyAnalysis,
          onPhoto: (path, key) => widget.draft.update(
            (d) => d
              ..parcelPhotoPath = path
              ..parcelPhotoKey = key
              ..parcelAnalysis = null,
          ),
        ),
        gap,
        section(l.sizeLabel),
        gap,
        _SizeTiles(
          selected: d.size,
          onSelected: (size) => widget.draft.update(
            (d) => d
              ..size = size
              ..sizeChosen = true,
          ),
        ),
        gap,
        Text(switch (d.size) {
          'M' => l.sizeHelpM,
          'L' => l.sizeHelpL,
          'XL' => l.sizeHelpXL,
          'BULKY' => l.sizeHelpBulky,
          _ => l.sizeHelpS,
        }, style: TaraText.small.copyWith(color: c.textSecondary, fontSize: 12, height: 1.45)),
        if (d.bulky) ...[
          gap,
          _SwitchRow(
            title: l.loadingHelpTitle,
            body: l.loadingHelpBody,
            value: d.loadingHelp,
            onChanged: (value) => widget.draft.update((d) => d.loadingHelp = value),
          ),
        ],
        gap,
        section(l.contentsShortLabel),
        gap,
        ChoiceChips<String>(
          wrap: true,
          options: [for (final code in packageContentsCodes) ChoiceOption(code, contentsText(l, code))],
          selected: d.contents,
          onSelected: _chooseContents,
        ),
        if (errors && d.contents == null) ...[const SizedBox(height: 6), ErrorLine(l.contentsRequired)],
        gap,
        BoxedField(
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
        gap,
        _SwitchRow(
          title: l.fragileTitle,
          body: l.fragileBody,
          value: d.fragile,
          onChanged: (value) => widget.draft.update(
            (d) => d
              ..fragile = value
              ..fragileChosen = true,
          ),
        ),
        if (widget.merchant) ...[
          gap,
          BoxedField(
            label: l.codLabel,
            hint: l.codHint,
            helper: l.codHelp,
            controller: _cod,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountInputFormatter(maxDigits: 7)],
          ),
          if (d.codAmount > DeliveryDraft.maxCod) ...[const SizedBox(height: 6), ErrorLine(l.codTooHigh)],
        ],
        gap,
        BoxedField(
          label: l.valueLabel,
          hint: l.valueHint,
          helper: l.valueHelpShort,
          controller: _value,
          keyboardType: TextInputType.number,
          inputFormatters: [AmountInputFormatter(maxDigits: 8)],
        ),
        gap,
        if (value > DeliveryDraft.maxDeclaredValue)
          ErrorLine(l.valueTooHigh)
        else
          Text(
            d.valueFee > 0
                ? l.valueFeeHint('${formatAmount(d.valueFee)} F')
                : l.guaranteeFree('${formatAmount(DeliveryDraft.freeGuarantee)} F'),
            style: TaraText.small.copyWith(
              color: d.valueFee > 0 ? c.textPrimary : c.success,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        gap,
        BoxedField(
          label: l.instructionsLabel,
          hint: l.instructionsHint,
          controller: _instructions,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
        ),
        gap,
        const ProhibitedItemsNote(),
      ],
    );
  }
}

/// Les cinq tailles côte à côte (maquette) : un colis 3D qui grossit, la lettre, le poids ;
/// la dernière, « Gros », part en tricycle.
class _SizeTiles extends StatelessWidget {
  const _SizeTiles({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final tiles = [
      for (final (i, (size, kg)) in packageSizes.indexed)
        (size, size, l.sizeMax(kg), '$size, ${l.sizeMax(kg)}', 18.0 + 6 * i),
      ('BULKY', l.sizeBulkyShort, l.sizeBulkyVehicle, '${l.sizeBulky}, ${l.sizeBulkyBody}', 40.0),
    ];
    return Row(
      children: [
        for (final (i, (code, letter, sub, semantic, cube)) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              inMutuallyExclusiveGroup: true,
              checked: code == selected,
              button: true,
              label: semantic,
              excludeSemantics: true,
              child: Squish(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(code);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 104,
                    padding: EdgeInsets.only(bottom: code == selected ? 9 : 10),
                    decoration: BoxDecoration(
                      color: code == selected ? const Color.fromRGBO(255, 138, 0, .10) : boxedFieldFill(c),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: code == selected ? const Color(0xFFFF8A00) : boxedFieldBorder(c),
                        width: code == selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: SizedBox.square(
                              dimension: cube * 1.25,
                              child: FittedBox(
                                child: Parcel3D(size: cube, spin: false, floating: false, shadow: false),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            letter,
                            maxLines: 1,
                            style: TaraText.text.copyWith(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              sub,
                              maxLines: 1,
                              style: TaraText.small.copyWith(color: c.textTertiary, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Option à interrupteur (« Fragile », « Aide pour charger ») : toute la ligne le bascule.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.body, required this.value, required this.onChanged});

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
                      title,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: TaraText.small.copyWith(color: c.textSecondary)),
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
