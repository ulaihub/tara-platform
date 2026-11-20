import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Choix du livreur pour les effets visuels (profil).
enum EffectsPreference { automatic, full, reduced }

/// Transparence des barres en verre (barre d'onglets, bouton du bas), choisie dans les
/// réglages : le flou et le reflet restent, seul le remplissage change.
enum GlassLevel {
  /// Le plus transparent : on devine mieux ce qui passe dessous.
  clear(.38),

  /// Réglage par défaut.
  balanced(.62),

  /// Presque plein, pour ceux qui préfèrent une barre bien lisible.
  opaque(.90);

  const GlassLevel(this.fill);

  /// Opacité du remplissage de la barre.
  final double fill;
}

/// Mode effets réduits (§5.4) : pas de flou, formes de fond figées. Activé automatiquement
/// sur les téléphones modestes, ou à la demande dans le profil.
class EffectsController extends ChangeNotifier {
  EffectsPreference _preference = EffectsPreference.automatic;
  GlassLevel _glassLevel = GlassLevel.balanced;
  bool _lowEndDevice = false;

  EffectsPreference get preference => _preference;

  GlassLevel get glassLevel => _glassLevel;
  set glassLevel(GlassLevel value) {
    if (value == _glassLevel) return;
    _glassLevel = value;
    notifyListeners();
  }

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
  const TaraEffectsData({required this.reduced, required this.reduceMotion, this.glassLevel = GlassLevel.balanced});

  /// Mode effets réduits : surfaces opaques sans flou, fond figé.
  final bool reduced;

  /// Réglage « réduire les animations » du téléphone (§5.3).
  final bool reduceMotion;

  /// Transparence des barres en verre choisie dans les réglages.
  final GlassLevel glassLevel;

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
    final controller = scope?.notifier;
    return TaraEffectsData(
      reduced: controller?.reduced ?? false,
      reduceMotion: reduceMotion,
      glassLevel: controller?.glassLevel ?? GlassLevel.balanced,
    );
  }
}
