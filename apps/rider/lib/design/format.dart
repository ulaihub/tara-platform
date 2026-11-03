/// Montant en FCFA, sans décimales, milliers séparés par une espace insécable : 12 500.
/// U+00A0 plutôt que l'espace fine U+202F, absente de Sora et de Plus Jakarta Sans : le
/// téléphone irait chercher une police de secours aux métriques différentes.
String formatAmount(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('\u00A0');
    out.write(digits[i]);
  }
  return '${negative ? '−' : ''}$out';
}

/// Durée en minutes:secondes (0:42).
String formatCountdown(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 5999);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Distance lisible, nombre et unité insécables : « 850 m », « 2,4 km ».
String formatDistance(int meters, {String decimalSeparator = ','}) {
  if (meters < 1000) return '${(meters / 10).round() * 10}\u00A0m';
  final km = meters / 1000;
  final text = km >= 10 ? km.round().toString() : km.toStringAsFixed(1).replaceAll('.', decimalSeparator);
  return '$text\u00A0km';
}

/// Durée en minutes, nombre et unité insécables : « 12 min ».
String formatMinutes(Duration duration) => '${duration.inMinutes.clamp(1, 999)}\u00A0min';

/// Temps en ligne : « 45 min », « 2 h 05 ».
String formatOnline(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes\u00A0min';
  return '${minutes ~/ 60}\u00A0h\u00A0${(minutes % 60).toString().padLeft(2, '0')}';
}
