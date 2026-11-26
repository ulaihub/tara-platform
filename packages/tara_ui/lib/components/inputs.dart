import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/effects.dart';
import '../motion/liquid_wave.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'glass.dart';

/// Champ de saisie : fond `inputBg`, bordure `chipBorder`, bordure orange et halo quand il
/// est actif. Libellé au-dessus.
class TaraTextField extends StatefulWidget {
  const TaraTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.leading,
    this.trailing,
    this.height = 46,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? leading;

  /// Action dans le champ, à droite (envoi d'un message) : centrée, puis en bas du champ
  /// quand le texte s'étend sur plusieurs lignes.
  final Widget? trailing;
  final double height;
  final TextCapitalization textCapitalization;

  /// Plusieurs lignes (message, compte rendu) : le champ grandit jusqu'à [maxLines].
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  State<TaraTextField> createState() => _TaraTextFieldState();
}

class _TaraTextFieldState extends State<TaraTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final focused = _focus.hasFocus;
    final field = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: widget.height),
      padding: EdgeInsets.only(left: 18, right: widget.trailing == null ? 18 : 6),
      decoration: BoxDecoration(
        color: c.inputBg,
        // Finesse : pilule pour une ligne, filet d'un pixel, halo discret au focus.
        borderRadius: BorderRadius.circular(widget.maxLines > 1 ? 18 : widget.height / 2),
        border: Border.all(color: focused ? TaraBrand.focusBorder : c.chipBorder, width: focused ? 1.2 : 1),
        boxShadow: focused ? const [BoxShadow(color: TaraBrand.focusHalo, spreadRadius: 3)] : null,
      ),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
          Expanded(
            child: TextField(
              focusNode: _focus,
              controller: widget.controller,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textCapitalization: widget.textCapitalization,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              // La limite suffit : pas de compteur de caractères sous le champ.
              buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
              cursorColor: TaraBrand.orange,
              style: TaraText.bodyStrong.copyWith(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TaraText.body.copyWith(color: c.placeholder, fontSize: 15),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            // En bas d'un texte sur plusieurs lignes : même marge qu'en haut d'une ligne seule.
            Padding(
              padding: EdgeInsets.only(bottom: widget.maxLines > 1 ? 8 : 0),
              child: widget.trailing,
            ),
          ],
        ],
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label!, style: TaraText.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Indicatif pays (« +237 » et chevron) devant le numéro de téléphone.
class PhonePrefixButton extends StatelessWidget {
  const PhonePrefixButton({super.key, required this.prefix, required this.semanticLabel, this.onPressed});

  final String prefix;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.isDark ? const Color.fromRGBO(255, 255, 255, 0.08) : c.inputBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prefix,
                style: TaraText.bodyStrong.copyWith(color: c.textPrimary, fontSize: 16, fontFeatures: TaraText.tabular),
              ),
              const SizedBox(width: 6),
              TaraIcon(TaraIcons.chevronDown, size: 16, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cases de code (6 pour le SMS, 4 pour les codes de course). La case active a une bordure
/// orange, un halo, une vague liquide basse (A2) et un curseur qui clignote (A11). Un champ
/// invisible reçoit la saisie (remplissage automatique des codes SMS compris).
class CodeCells extends StatefulWidget {
  const CodeCells({
    super.key,
    required this.length,
    required this.digitLabel,
    this.onChanged,
    this.onCompleted,
    this.cellHeight = 56,
    this.autofocus = true,
    this.controller,
    this.oneTimeCode = false,
  });

  final int length;

  /// Libellé lecteur d'écran de chaque case (« Chiffre N »).
  final String Function(int index) digitLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final double cellHeight;
  final bool autofocus;
  final TextEditingController? controller;

  /// Code SMS : remplissage automatique proposé par le système.
  final bool oneTimeCode;

  @override
  State<CodeCells> createState() => _CodeCellsState();
}

class _CodeCellsState extends State<CodeCells> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _focus.addListener(() => setState(() {}));
  }

  void _changed() {
    setState(() {});
    widget.onChanged?.call(_controller.text);
    if (_controller.text.length == widget.length) widget.onCompleted?.call(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final value = _controller.text;
    final active = _focus.hasFocus ? value.length.clamp(0, widget.length - 1) : -1;
    final digitStyle = TaraText.titleCourse.copyWith(
      fontSize: widget.cellHeight >= 64 ? 26 : 24,
      color: c.textPrimary,
      fontFeatures: TaraText.tabular,
    );

    Widget cell(int index) {
      final filled = index < value.length;
      final isActive = index == active && value.length < widget.length;
      final waveFront = c.isDark
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(255, 138, 0, 0.5), Color.fromRGBO(255, 61, 0, 0.3)],
            )
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(255, 176, 0, 0.55), Color.fromRGBO(255, 106, 0, 0.4)],
            );
      final emptyBg = c.isDark ? const Color.fromRGBO(255, 255, 255, 0.04) : const Color.fromRGBO(255, 255, 255, 0.45);
      final filledBg = c.isDark ? const Color.fromRGBO(255, 255, 255, 0.08) : const Color.fromRGBO(255, 255, 255, 0.72);
      final emptyBorder = c.isDark ? const Color.fromRGBO(255, 255, 255, 0.12) : const Color.fromRGBO(22, 18, 14, 0.08);
      final filledBorder = c.isDark
          ? const Color.fromRGBO(255, 255, 255, 0.16)
          : const Color.fromRGBO(22, 18, 14, 0.10);
      return Expanded(
        child: Semantics(
          label: widget.digitLabel(index + 1),
          value: filled ? value[index] : '',
          child: Container(
            height: widget.cellHeight,
            decoration: BoxDecoration(
              color: filled ? filledBg : emptyBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? TaraBrand.focusBorder : (filled ? filledBorder : emptyBorder),
                width: isActive ? 1.2 : 1,
              ),
              boxShadow: isActive ? const [BoxShadow(color: TaraBrand.focusHalo, spreadRadius: 3)] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isActive)
                    Positioned.fill(
                      child: LiquidFill(
                        level: .35,
                        front: waveFront,
                        back: waveFront.colors.last.withValues(alpha: .25),
                        frontPeriod: const Duration(seconds: 5),
                        backPeriod: const Duration(seconds: 8),
                        amplitude: 4,
                      ),
                    ),
                  if (filled) Text(value[index], style: digitStyle),
                  if (isActive)
                    Blink(
                      child: Container(
                        width: 2,
                        height: widget.cellHeight >= 64 ? 24 : 22,
                        decoration: BoxDecoration(color: c.textPrimary, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[if (i > 0) const SizedBox(width: 10), cell(i)],
            ],
          ),
          // Champ invisible qui reçoit la saisie et le code SMS proposé par le système.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: widget.oneTimeCode ? const [AutofillHints.oneTimeCode] : null,
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une option d'un groupe de choix.
@immutable
class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.icon, this.leading});
  final T value;
  final String label;
  final TaraIconData? icon;

  /// Image posée avant le libellé à la place de l'icône (logo d'opérateur).
  final Widget? leading;
}

/// Puces radio (véhicule, motif d'échec, montant reçu, opérateur) : un seul choix, état
/// annoncé par le lecteur d'écran.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.columns = 2,
    this.height = 42,
  });

  final List<ChoiceOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int columns;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    Widget chip(ChoiceOption<T> option) {
      final isSelected = option.value == selected;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        button: true,
        label: option.label,
        excludeSemantics: true,
        child: Squish(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(option.value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: BoxConstraints(minHeight: height),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? null : c.chipBg,
                gradient: isSelected ? c.chipSelected : null,
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                  color: isSelected ? c.chipSelectedBorder : c.chipBorder,
                  width: isSelected ? c.chipSelectedBorderWidth : 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.leading != null) ...[
                      option.leading!,
                      const SizedBox(width: 8),
                    ] else if (option.icon != null) ...[
                      TaraIcon(option.icon!, size: 18, color: isSelected ? c.accentText : c.textSecondary),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        option.label,
                        textAlign: TextAlign.center,
                        style: TaraText.text.copyWith(
                          color: isSelected ? c.textPrimary : c.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontFeatures: TaraText.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += columns) {
      final slice = options.skip(i).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                Expanded(child: j < slice.length ? chip(slice[j]) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), rows[i]],
      ],
    );
  }
}

/// Note d'information (icône + texte 13 sur verre léger).
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = TaraIcons.shieldCheck});

  final String text;
  final TaraIconData icon;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 18,
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaraIcon(icon, size: 18, color: c.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TaraText.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interrupteur de la marque : rail en verre, pastille blanche qui glisse avec un léger
/// rebond, dégradé orange une fois activé. Lu « activé / désactivé » par les lecteurs
/// d'écran ; toute la ligne qui l'entoure peut le basculer.
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const _width = 52.0;
  static const _height = 32.0;
  static const _knob = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: _width,
            height: _height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: value ? TaraBrand.gradient : null,
              color: value ? null : c.track,
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(color: value ? const Color(0x00000000) : c.chipBorder),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: const Cubic(0.5, -0.3, 0.3, 1.4),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: _knob - 2,
                height: _knob - 2,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, .18), blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saisie d'un montant en FCFA : chiffres seulement, [maxDigits] au plus, milliers séparés
/// par une espace insécable (« 12 500 »), curseur en fin de saisie.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.maxDigits = 7});

  final int maxDigits;

  /// Montant saisi, ou null si le champ est vide.
  static int? valueOf(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp('^0+(?=\\d)'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Fond des champs « libellé dans la case » des maquettes (`--card`).
Color boxedFieldFill(TaraColors c) =>
    c.isDark ? const Color.fromRGBO(255, 255, 255, .06) : const Color.fromRGBO(255, 255, 255, .84);

/// Champ des maquettes où le libellé est dans la case (« Numéro de téléphone », « Nom de
/// votre boutique ») : 56 de haut au moins, coins 16, libellé 11 en gras, valeur 16 en
/// gras. Sans [controller], la case affiche [value] et ne se modifie pas (« Pays »).
class BoxedField extends StatefulWidget {
  const BoxedField({
    super.key,
    required this.label,
    this.controller,
    this.value,
    this.valueLeading,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.trailing,
    this.helper,
    this.valueStyle,
  });

  final String label;
  final TextEditingController? controller;
  final String? value;

  /// Devant la valeur fixe (drapeau du pays).
  final Widget? valueLeading;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  /// À droite de la case (bouton contacts, logo de l'opérateur).
  final Widget? trailing;

  /// Ligne sous la valeur, dans la case (« Il reçoit vos ventes encaissées »).
  final String? helper;
  final TextStyle? valueStyle;

  @override
  State<BoxedField> createState() => _BoxedFieldState();
}

class _BoxedFieldState extends State<BoxedField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final focused = _focus.hasFocus;
    final valueStyle =
        widget.valueStyle ??
        TaraText.bodyStrong.copyWith(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3);
    final Widget value = widget.controller == null
        ? Row(
            children: [
              if (widget.valueLeading case final leading?) ...[leading, const SizedBox(width: 4)],
              Flexible(
                child: Text(widget.value ?? '', style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          )
        : TextField(
            focusNode: _focus,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            textCapitalization: widget.textCapitalization,
            cursorColor: TaraBrand.orange,
            style: valueStyle,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: valueStyle.copyWith(color: c.placeholder, fontWeight: FontWeight.w500),
            ),
          );
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: boxedFieldFill(c),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? TaraBrand.focusBorder : c.textPrimary.withValues(alpha: .12),
          width: focused ? 1.2 : 1,
        ),
        boxShadow: focused ? const [BoxShadow(color: TaraBrand.focusHalo, spreadRadius: 3)] : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TaraText.smallStrong.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    letterSpacing: .2,
                    color: c.textPrimary.withValues(alpha: .55),
                  ),
                ),
                value,
                if (widget.helper case final helper?)
                  Text(
                    helper,
                    style: TaraText.small.copyWith(
                      fontSize: 11,
                      height: 1.3,
                      color: c.textPrimary.withValues(alpha: .62),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.trailing case final trailing?) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
    if (widget.controller == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: _focus.requestFocus, child: box);
  }
}

/// Drapeau du Cameroun dessiné (vert, rouge à étoile jaune, jaune) : les émojis de
/// drapeaux ne s'affichent pas sur tous les téléphones.
class CameroonFlag extends StatelessWidget {
  const CameroonFlag({super.key, this.width = 20});
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cameroun',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: width,
        height: width * 2 / 3,
        child: const CustomPaint(painter: _FlagPainter()),
      ),
    ),
  );
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 3;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = const Color(0xFF007A5E))
      ..drawRect(Rect.fromLTWH(w, 0, w, size.height), Paint()..color = const Color(0xFFCE1126))
      ..drawRect(Rect.fromLTWH(2 * w, 0, w, size.height), Paint()..color = const Color(0xFFFCD116));
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.height * .22;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * .4;
      final a = -1.5707963 + i * 3.14159265 / 5;
      final p = center + Offset(radius * _cos(a), radius * _sin(a));
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFFCD116));
  }

  static double _cos(double a) => math.cos(a);
  static double _sin(double a) => math.sin(a);

  @override
  bool shouldRepaint(_FlagPainter old) => false;
}
