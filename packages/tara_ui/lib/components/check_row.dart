import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';

/// Case à cocher de la marque, avec son libellé : carré en verre, rempli du dégradé orange
/// et coché une fois choisie. Toute la ligne est touchable ; lue « case cochée » par les
/// lecteurs d'écran. Désactivée ([onChanged] null) : estompée.
class TaraCheckRow extends StatelessWidget {
  const TaraCheckRow({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final InlineSpan label;

  static const _box = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : .5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _box,
                  height: _box,
                  decoration: BoxDecoration(
                    gradient: value ? TaraBrand.gradient : null,
                    color: value ? null : c.inputBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: value ? const Color(0x00000000) : c.chipSelectedBorder, width: 1.5),
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: const Cubic(0.5, -0.3, 0.3, 1.6),
                    scale: value ? 1 : 0,
                    child: const Center(
                      child: TaraIcon(TaraIcons.check, size: 16, color: Color(0xFFFFFFFF), strokeWidth: 3),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(label, style: TaraText.label.copyWith(color: c.textPrimary, height: 1.45)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
