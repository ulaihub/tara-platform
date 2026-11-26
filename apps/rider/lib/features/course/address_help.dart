import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';

/// Photo ou note d'une adresse de la course, téléchargée une fois et gardée en mémoire
/// tant que l'app est ouverte : (commande, pickup|dropoff, photo|voice).
final addressMediaProvider = FutureProvider.family<Uint8List, (String, String, String)>(
  (ref, key) => ref.read(riderApiProvider).addressMedia(key.$1, key.$2, key.$3),
);

/// Lecture d'une note vocale (remplacée dans les tests).
abstract class VoiceNotePlayer {
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Stream<void> get completed;
}

class DeviceVoiceNotePlayer implements VoiceNotePlayer {
  AudioPlayer? _player;
  final _completed = StreamController<void>.broadcast();

  AudioPlayer get _ready {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    player.onPlayerComplete.listen(_completed.add);
    return _player = player;
  }

  /// Fichier temporaire : la lecture depuis la mémoire n'existe pas partout.
  @override
  Future<void> play(Uint8List bytes) async {
    final file = File('${(await getTemporaryDirectory()).path}/tara-note-adresse.m4a');
    await file.writeAsBytes(bytes, flush: true);
    await _ready.play(DeviceFileSource(file.path));
  }

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Stream<void> get completed => _completed.stream;

  Future<void> dispose() async {
    await _player?.dispose();
    await _completed.close();
  }
}

final voiceNotePlayerProvider = Provider<VoiceNotePlayer>((ref) {
  final player = DeviceVoiceNotePlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

/// Aide laissée par l'expéditeur pour trouver l'adresse (B2) : « Voir la façade » (photo
/// en grand) et « Écouter la note » (30 s au plus). Rien s'il n'a rien laissé.
class AddressHelp extends ConsumerStatefulWidget {
  const AddressHelp({
    super.key,
    required this.orderId,
    required this.stop,
    required this.address,
    required this.name,
    this.tiles = false,
  });

  /// En route (maquette) : vignette de la façade et note vocale en onde, au lieu de boutons.
  final bool tiles;

  final String orderId;

  /// `pickup` ou `dropoff`.
  final String stop;
  final OrderAddress address;

  /// Vendeur ou client, pour le titre de la photo.
  final String name;

  @override
  ConsumerState<AddressHelp> createState() => _AddressHelpState();
}

class _AddressHelpState extends ConsumerState<AddressHelp> {
  late final VoiceNotePlayer _player;
  StreamSubscription<void>? _completed;
  bool _playing = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = ref.read(voiceNotePlayerProvider);
    _completed = _player.completed.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Uint8List? _thumb;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Vignette chargée d'office en route : le livreur reconnaît la porte d'un coup d'œil.
    if (widget.tiles && widget.address.hasPhoto && _thumb == null && !_loadingThumb) {
      _loadingThumb = true;
      ref
          .read(addressMediaProvider((widget.orderId, widget.stop, 'photo')).future)
          .then((bytes) {
            if (mounted) setState(() => _thumb = bytes);
          })
          .catchError((Object _) {});
    }
  }

  bool _loadingThumb = false;

  @override
  void dispose() {
    unawaited(_completed?.cancel());
    if (_playing) unawaited(_player.stop());
    super.dispose();
  }

  Future<Uint8List?> _fetch(String kind) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      return await ref.read(addressMediaProvider((widget.orderId, widget.stop, kind)).future);
    } catch (_) {
      // Échec oublié : on réessaiera au prochain toucher.
      ref.invalidate(addressMediaProvider((widget.orderId, widget.stop, kind)));
      if (mounted) setState(() => _error = l.addressMediaFailed);
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPhoto() async {
    final l = AppLocalizations.of(context);
    final bytes = await _fetch('photo');
    if (bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xE6000000),
      builder: (context) => SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Semantics(
                    image: true,
                    label: l.addressPhotoTitle(widget.name),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GlassIconButton(
                icon: TaraIcons.close,
                label: l.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final bytes = await _fetch('voice');
    if (bytes == null || !mounted) return;
    setState(() => _playing = true);
    await _player.play(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final address = widget.address;
    if (!address.hasPhoto && !address.hasVoiceNote) return const SizedBox.shrink();
    if (widget.tiles) return _tilesView(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (address.hasPhoto)
                Expanded(
                  child: GlassButton(
                    label: l.addressPhoto,
                    icon: TaraIcons.camera,
                    height: 44,
                    color: c.accentText,
                    onPressed: _loading ? null : () => unawaited(_showPhoto()),
                  ),
                ),
              if (address.hasPhoto && address.hasVoiceNote) const SizedBox(width: 10),
              if (address.hasVoiceNote)
                Expanded(
                  child: GlassButton(
                    label: _playing ? l.addressVoiceStop : l.addressVoice,
                    icon: _playing ? TaraIcons.stop : TaraIcons.play,
                    height: 44,
                    color: c.accentText,
                    onPressed: _loading ? null : () => unawaited(_toggleVoice()),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: TaraText.small.copyWith(color: c.dangerText)),
          ],
        ],
      ),
    );
  }

  /// Maquette En route : façade en vignette (96 × 64), note vocale avec son onde.
  Widget _tilesView(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final address = widget.address;
    final thumb = _thumb;
    final photo = Semantics(
      button: true,
      label: l.addressPhoto,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _loading ? null : () => unawaited(_showPhoto()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 96,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-.35, -1),
                      end: Alignment(.35, 1),
                      colors: [Color(0xFF3A4A5C), Color(0xFF1E2732)],
                      stops: [0, .6],
                    ),
                  ),
                ),
                if (thumb != null) Image.memory(thumb, fit: BoxFit.cover, gaplessPlayback: true),
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, .55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.addressFacade,
                      style: TaraText.small.copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final voice = Semantics(
      button: true,
      label: _playing ? l.addressVoiceStop : l.addressVoice,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _loading ? null : () => unawaited(_toggleVoice()),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: c.textPrimary.withValues(alpha: .06),
            border: Border.all(color: c.textPrimary.withValues(alpha: .12)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(255, 177, 92, .18)),
                alignment: Alignment.center,
                child: TaraIcon(_playing ? TaraIcons.stop : TaraIcons.play, size: 16, color: c.accentText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Wave(playing: _playing, color: c.accentText),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (address.hasPhoto) photo,
              if (address.hasPhoto && address.hasVoiceNote) const SizedBox(width: 8),
              if (address.hasVoiceNote) Expanded(child: voice),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: TaraText.small.copyWith(color: c.dangerText)),
          ],
        ],
      ),
    );
  }
}

/// Onde de la note vocale : barres fixes, qui dansent pendant l'écoute.
class _Wave extends StatefulWidget {
  const _Wave({required this.playing, required this.color});
  final bool playing;
  final Color color;

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  static const _heights = [.45, .8, .6, 1.0, .5, .75, .9, .4, .7, .55, .85, .5];
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(_Wave old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    } else if (!widget.playing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      children: [
        for (var i = 0; i < _heights.length; i++) ...[
          Container(
            width: 3,
            height:
                24 *
                (widget.playing
                    ? (.35 + .65 * ((_heights[i] + _controller.value * (i.isEven ? 1 : -1)) % 1))
                    : _heights[i]),
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 3),
        ],
      ],
    ),
  );
}
