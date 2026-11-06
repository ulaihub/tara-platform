import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Choix du livreur pour les effets visuels (profil).
enum EffectsPreference { automatic, full, reduced }

/// Mode effets réduits (§5.4) : pas de flou, formes de fond figées. Activé automatiquement
/// sur les téléphones modestes, ou à la demande dans le profil.
class EffectsController extends ChangeNotifier {
  EffectsPreference _preference = EffectsPreference.automatic;
  bool _lowEndDevice = false;

  EffectsPreference get preference => _preference;
  bool get lowEndDevice => _lowEndDevice;

  bool get reduced => switch (_preference) {
    EffectsPreference.reduced => true,
    EffectsPreference.full => false,
    EffectsPreference.automatic => _lowEndDevice,
  };

  /// Force la détection (tests, captures d'écran).
  @visibleForTesting
  set lowEndDevice(bool value) {
    _lowEndDevice = value;
    notifyListeners();
  }

  set preference(EffectsPreference value) {
    if (value == _preference) return;
    _preference = value;
    notifyListeners();
  }

  /// Téléphone d'entrée de gamme : Android « faible mémoire » ou 3 Go de RAM au plus.
  Future<void> detectDevice() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final lowEnd = info.isLowRamDevice || (info.physicalRamSize > 0 && info.physicalRamSize <= 3072);
      if (lowEnd != _lowEndDevice) {
        _lowEndDevice = lowEnd;
        notifyListeners();
      }
    } catch (_) {
      // Information indisponible : on garde les effets complets.
    }
  }
}

/// État des effets lu par les composants.
@immutable
class TaraEffectsData {
  const TaraEffectsData({required this.reduced, required this.reduceMotion});

  /// Mode effets réduits : surfaces opaques sans flou, fond figé.
  final bool reduced;

  /// Réglage « réduire les animations » du téléphone (§5.3).
  final bool reduceMotion;

  /// Flou d'arrière-plan des surfaces en verre.
  bool get blur => !reduced;

  /// Formes liquides du fond qui bougent (A1).
  bool get ambientMotion => !reduced && !reduceMotion;

  /// Animations décoratives (vagues, reflets, pulsations, tirets…). L'information
  /// (niveau du compte à rebours, maintien du SOS) change même quand elles sont arrêtées.
  bool get decorativeMotion => !reduceMotion;
}

/// Met l'état des effets à disposition des composants.
class TaraEffects extends InheritedNotifier<EffectsController> {
  const TaraEffects({super.key, required EffectsController controller, required super.child})
    : super(notifier: controller);

  static TaraEffectsData of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TaraEffects>();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TaraEffectsData(reduced: scope?.notifier?.reduced ?? false, reduceMotion: reduceMotion);
  }
}
