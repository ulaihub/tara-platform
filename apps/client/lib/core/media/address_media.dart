import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Durée maximale d'une note vocale d'adresse (B2).
const maxVoiceNote = Duration(seconds: 30);

Future<String> _privatePath(String extension) async {
  final folder = Directory('${(await getApplicationSupportDirectory()).path}/addresses');
  await folder.create(recursive: true);
  return '${folder.path}/${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.$extension';
}

/// Photo de la façade (B2) : appareil photo arrière, image réduite (moins de 150 Ko visés,
/// 1 Mo au plus accepté par le serveur), gardée dans le dossier privé de l'app.
typedef TakeFacadePhoto = Future<String?> Function();

Future<String?> takeFacadePhoto() async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 60,
  );
  if (shot == null) return null;
  final kept = await File(shot.path).copy(await _privatePath('jpg'));
  try {
    await File(shot.path).delete();
  } catch (_) {
    // Fichier temporaire déjà retiré : rien à faire.
  }
  return kept.path;
}

final takeFacadePhotoProvider = Provider<TakeFacadePhoto>((ref) => takeFacadePhoto);

/// Photo du colis à la commande : même prise de vue que la façade (appareil arrière, réduite).
final takeParcelPhotoProvider = Provider<TakeFacadePhoto>((ref) => takeFacadePhoto);

/// Note vocale (B2) : AAC mono, léger (environ 4 Ko par seconde), 30 s au plus.
abstract class VoiceRecorder {
  /// Demande le micro puis commence ; false si l'accès est refusé.
  Future<bool> start();

  /// Arrête et renvoie le fichier enregistré.
  Future<String?> stop();

  Future<void> cancel();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  /// Créé au premier enregistrement : le micro n'est pas réservé avant.
  AudioRecorder? _recorder;

  @override
  Future<bool> start() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) return false;
    await recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 16000, numChannels: 1),
      path: await _privatePath('m4a'),
    );
    return true;
  }

  @override
  Future<String?> stop() async => _recorder?.stop();

  @override
  Future<void> cancel() async => _recorder?.cancel();

  Future<void> dispose() async => _recorder?.dispose();
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = DeviceVoiceRecorder();
  ref.onDispose(() => unawaited(recorder.dispose()));
  return recorder;
});

/// Écoute de la note avant de l'envoyer.
abstract class NotePlayer {
  Future<void> play(String path);
  Future<void> stop();

  /// Lecture terminée.
  Stream<void> get completed;
}

class DeviceNotePlayer implements NotePlayer {
  /// Créé à la première écoute.
  AudioPlayer? _player;
  final _completed = StreamController<void>.broadcast();

  AudioPlayer get _ready {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    player.onPlayerComplete.listen(_completed.add);
    return _player = player;
  }

  @override
  Future<void> play(String path) => _ready.play(DeviceFileSource(path));

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Stream<void> get completed => _completed.stream;

  Future<void> dispose() async {
    await _player?.dispose();
    await _completed.close();
  }
}

final notePlayerProvider = Provider<NotePlayer>((ref) {
  final player = DeviceNotePlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});
