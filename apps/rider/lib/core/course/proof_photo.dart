import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Photo de preuve (colis, remise, lieu d'échec) : appareil photo arrière, image réduite
/// (cahier des charges : moins de 150 Ko avant envoi), rangée dans le dossier privé de
/// l'app. Le cache peut être vidé par Android : la photo d'une action encore en file doit
/// survivre jusqu'à son envoi ; la file la supprime ensuite.
typedef TakeProofPhoto = Future<String?> Function();

Future<String?> takeProofPhoto() async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 960,
    maxHeight: 960,
    imageQuality: 55,
  );
  if (shot == null) return null;
  final folder = Directory('${(await getApplicationSupportDirectory()).path}/proofs');
  await folder.create(recursive: true);
  final name = '${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.jpg';
  final kept = await File(shot.path).copy('${folder.path}/$name');
  try {
    await File(shot.path).delete();
  } catch (_) {
    // Fichier temporaire déjà retiré : rien à faire.
  }
  return kept.path;
}

/// Prise de photo (remplacée dans les tests).
final takeProofPhotoProvider = Provider<TakeProofPhoto>((ref) => takeProofPhoto);
