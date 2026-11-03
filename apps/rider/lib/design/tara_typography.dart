import 'package:flutter/widgets.dart';

/// Typographie de la passation (§2.2) : Sora pour les titres et les chiffres, Plus Jakarta
/// Sans pour le texte. Interlettrage CSS en em converti en pixels (em × taille).
abstract final class TaraText {
  static const sora = 'Sora';
  static const jakarta = 'PlusJakartaSans';

  /// Chiffres de même largeur : montants, heures, compteurs ne « dansent » pas.
  static const tabular = [FontFeature.tabularFigures()];

  static TextStyle _sora(double size, FontWeight weight, double em, {double? height}) =>
      TextStyle(fontFamily: sora, fontSize: size, fontWeight: weight, letterSpacing: em * size, height: height);

  static TextStyle _jakarta(double size, FontWeight weight, {double em = 0, double? height}) =>
      TextStyle(fontFamily: jakarta, fontSize: size, fontWeight: weight, letterSpacing: em * size, height: height);

  /// Compte à rebours (72 / 800).
  static final giantNumber = _sora(72, FontWeight.w800, -0.04, height: 1).copyWith(fontFeatures: tabular);

  /// Gain proposé, montant à encaisser (40–42 / 800).
  static final amountXL = _sora(42, FontWeight.w800, -0.03, height: 1.05).copyWith(fontFeatures: tabular);

  /// Gains du jour ou de la période (34–36 / 800).
  static final amountL = _sora(36, FontWeight.w800, -0.02, height: 1.05).copyWith(fontFeatures: tabular);

  static final titleAccess = _sora(30, FontWeight.w700, -0.02, height: 1.15);
  static final titleForm = _sora(26, FontWeight.w700, -0.02, height: 1.15);
  static final titleCourse = _sora(22, FontWeight.w700, -0.02, height: 1.2);
  static final titlePanel = _sora(19, FontWeight.w700, -0.02, height: 1.2);
  static final sos = _sora(44, FontWeight.w800, 0.04, height: 1);
  static final cardTitle = _sora(17, FontWeight.w700, 0, height: 1.25);

  static final body = _jakarta(15, FontWeight.w400, height: 1.5);
  static final bodyStrong = _jakarta(15, FontWeight.w700, height: 1.4);
  static final text = _jakarta(14, FontWeight.w600, height: 1.4);
  static final label = _jakarta(13, FontWeight.w600, height: 1.35);
  static final small = _jakarta(12, FontWeight.w500, height: 1.45);
  static final smallStrong = _jakarta(12, FontWeight.w700, height: 1.35);

  /// Sur-titre en majuscules (11 / 700, +0,08 em).
  static final overline = _jakarta(11, FontWeight.w700, em: 0.08, height: 1.3);

  /// Sur-titre des écrans d'accès (13 / 700, +0,12 em).
  static final overlineLarge = _jakarta(13, FontWeight.w700, em: 0.12, height: 1.3);
  static final button = _jakarta(17, FontWeight.w700, height: 1.2);
  static final buttonStrong = _jakarta(17, FontWeight.w800, height: 1.2);
  static final buttonSecondary = _jakarta(16, FontWeight.w700, height: 1.2);

  /// Unité « FCFA » après un montant.
  static final unit = _jakarta(16, FontWeight.w600, height: 1.2);
}
