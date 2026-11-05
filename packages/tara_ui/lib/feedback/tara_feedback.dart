import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_settings.dart';

/// Sons de la marque (notes de balafon et de cloche, synthétisées par
/// `tool/make_sounds.py`), chacun lié à un moment de la course ou de la commande.
enum TaraSound {
  /// Nouvelle course proposée au livreur (répété jusqu'à la réponse).
  offer('offer'),

  /// Course acceptée.
  accepted('accepted'),

  /// Colis récupéré chez l'expéditeur.
  pickedUp('picked_up'),

  /// Colis livré : petite fanfare.
  delivered('delivered'),

  /// Argent encaissé.
  cash('cash'),

  /// Commande envoyée par l'expéditeur.
  sent('sent'),

  /// Bonne nouvelle reçue (adresse placée par le destinataire, livreur trouvé).
  received('received'),

  /// Action refusée.
  error('error');

  const TaraSound(this.file);
  final String file;

  String get asset => 'packages/tara_ui/assets/sounds/$file.wav';
}

/// Lecteur des sons, remplacé dans les tests.
abstract class TaraSoundPlayer {
  Future<void> play(TaraSound sound, {bool loop = false});
  Future<void> stop(TaraSound sound);
}

/// Lecture par audioplayers : un lecteur court par son, gardé en mémoire ; mode
/// silencieux du téléphone respecté, musique en cours seulement baissée un instant.
class AudioSoundPlayer implements TaraSoundPlayer {
  final _players = <TaraSound, AudioPlayer>{};
  static final _cache = AudioCache(prefix: '');
  static final _context = AudioContextConfig(respectSilence: true, focus: AudioContextConfigFocus.duckOthers).build();

  Future<AudioPlayer> _player(TaraSound sound) async {
    final existing = _players[sound];
    if (existing != null) return existing;
    final player = AudioPlayer()..audioCache = _cache;
    await player.setAudioContext(_context);
    await player.setPlayerMode(PlayerMode.lowLatency);
    return _players[sound] = player;
  }

  @override
  Future<void> play(TaraSound sound, {bool loop = false}) async {
    final player = await _player(sound);
    await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await player.stop();
    await player.play(AssetSource(sound.asset));
  }

  @override
  Future<void> stop(TaraSound sound) async => _players[sound]?.stop();
}

/// Sons enregistrés au lieu d'être joués (tests).
class RecordingSoundPlayer implements TaraSoundPlayer {
  final played = <TaraSound>[];
  final looping = <TaraSound>{};

  @override
  Future<void> play(TaraSound sound, {bool loop = false}) async {
    played.add(sound);
    if (loop) looping.add(sound);
  }

  @override
  Future<void> stop(TaraSound sound) async => looping.remove(sound);
}

/// Retours des moments clés : un son court de la marque (si l'utilisateur a laissé les
/// sons) et une vibration adaptée (toujours). Une erreur de lecture ne remonte jamais.
abstract final class TaraFeedback {
  /// Sous `flutter test`, les sons sont enregistrés plutôt que joués.
  static TaraSoundPlayer player = Platform.environment['FLUTTER_TEST'] == 'true'
      ? RecordingSoundPlayer()
      : AudioSoundPlayer();

  static void play(BuildContext context, TaraSound sound, {bool loop = false}) {
    unawaited(_vibrate(sound));
    final settings = context.getInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;
    if (settings != null && !settings.sounds) return;
    unawaited(player.play(sound, loop: loop).catchError((Object _) {}));
  }

  static void stop(TaraSound sound) => unawaited(player.stop(sound).catchError((Object _) {}));

  /// Une seule impulsion par moment (pas de minuterie qui survivrait à l'écran).
  static Future<void> _vibrate(TaraSound sound) async {
    try {
      await switch (sound) {
        // Nouvelle course : vibration longue, sensible même téléphone en poche.
        TaraSound.offer => HapticFeedback.vibrate(),
        TaraSound.delivered || TaraSound.cash || TaraSound.error => HapticFeedback.heavyImpact(),
        TaraSound.accepted || TaraSound.sent || TaraSound.pickedUp => HapticFeedback.mediumImpact(),
        TaraSound.received => HapticFeedback.lightImpact(),
      };
    } catch (_) {
      // Pas de moteur de vibration : rien à faire.
    }
  }
}
