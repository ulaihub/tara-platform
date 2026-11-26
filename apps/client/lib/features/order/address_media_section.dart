import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/media/address_media.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import 'pickup_step.dart' show DashedRRectPainter;

/// Photo et note vocale choisies, envoyées avec l'adresse à l'enregistrement.
class AddressMedia extends ChangeNotifier {
  String? _photo;
  String? _voice;
  Duration _voiceLength = Duration.zero;

  String? get photo => _photo;
  String? get voice => _voice;
  Duration get voiceLength => _voiceLength;

  set photo(String? path) {
    _photo = path;
    notifyListeners();
  }

  void setVoice(String? path, Duration length) {
    _voice = path;
    _voiceLength = path == null ? Duration.zero : length;
    notifyListeners();
  }
}

String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// « Pour aider le livreur » (B2) : photo de la façade et note vocale de 30 s, facultatives.
class AddressMediaSection extends ConsumerStatefulWidget {
  const AddressMediaSection({super.key, required this.media});

  final AddressMedia media;

  @override
  ConsumerState<AddressMediaSection> createState() => _AddressMediaSectionState();
}

class _AddressMediaSectionState extends ConsumerState<AddressMediaSection> {
  bool _recording = false;
  bool _playing = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  StreamSubscription<void>? _completed;
  String? _error;

  // Gardés pour dispose(), où ref n'est plus utilisable.
  late final VoiceRecorder _recorder;
  late final NotePlayer _player;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(voiceRecorderProvider);
    _player = ref.read(notePlayerProvider);
    widget.media.addListener(_changed);
    _completed = _player.completed.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.media.removeListener(_changed);
    _ticker?.cancel();
    unawaited(_completed?.cancel());
    if (_recording) unawaited(_recorder.cancel());
    if (_playing) unawaited(_player.stop());
    super.dispose();
  }

  Future<void> _takePhoto() async {
    setState(() => _error = null);
    try {
      final path = await ref.read(takeFacadePhotoProvider)();
      if (path != null && mounted) widget.media.photo = path;
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    }
  }

  Future<void> _record() async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    if (_playing) await _stopPlaying();
    final started = await _recorder.start();
    if (!mounted) return;
    if (!started) {
      setState(() => _error = l.micDenied);
      return;
    }
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      // 30 secondes au plus : la note s'arrête d'elle-même.
      if (_elapsed >= maxVoiceNote) unawaited(_stopRecording());
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path != null && _elapsed >= const Duration(seconds: 1)) {
      widget.media.setVoice(path, _elapsed);
    }
  }

  Future<void> _togglePlay() async {
    final voice = widget.media.voice;
    if (voice == null) return;
    if (_playing) {
      await _stopPlaying();
      return;
    }
    setState(() => _playing = true);
    await _player.play(voice);
  }

  Future<void> _stopPlaying() async {
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final photo = widget.media.photo;
    final voice = widget.media.voice;
    final voiceLabel = _recording
        ? l.recordingNote(_clock(_elapsed))
        : voice == null
        ? l.voiceNoteRecord
        : l.voiceNoteLength(_clock(widget.media.voiceLength));
    // Barres en orange : ce qui est enregistré (ou s'enregistre) sur 30 secondes.
    final filled = _recording
        ? (_elapsed.inMilliseconds / maxVoiceNote.inMilliseconds * 18).ceil().clamp(1, 18)
        : voice == null
        ? 0
        : (widget.media.voiceLength.inMilliseconds / maxVoiceNote.inMilliseconds * 18).ceil().clamp(1, 18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Photo de la façade à gauche, note vocale à droite (maquette).
        Row(
          children: [
            SizedBox(
              width: 100,
              height: 70,
              child: Semantics(
                button: true,
                label: photo == null ? l.facadePhoto : '${l.facadePhotoLabel}, ${l.retake}',
                excludeSemantics: true,
                child: Squish(
                  child: GestureDetector(
                    key: facadePhotoKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_takePhoto()),
                    child: photo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ColoredBox(
                              color: c.track,
                              child: Image.file(File(photo), fit: BoxFit.cover, cacheWidth: 300),
                            ),
                          )
                        : CustomPaint(
                            painter: const DashedRRectPainter(color: Color.fromRGBO(255, 177, 92, .6), radius: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TaraIcon(TaraIcons.camera, size: 20, color: c.accentText),
                                const SizedBox(height: 4),
                                Text(
                                  l.facadePhoto,
                                  textAlign: TextAlign.center,
                                  style: TaraText.small.copyWith(
                                    color: c.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                liveRegion: _recording,
                label: voiceLabel,
                hint: _recording
                    ? l.stopRecording
                    : voice == null
                    ? l.recordNote
                    : (_playing ? l.stopListening : l.listenNote(_clock(widget.media.voiceLength))),
                excludeSemantics: true,
                child: Squish(
                  child: GestureDetector(
                    key: voiceNoteKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(
                      _recording
                          ? _stopRecording()
                          : voice == null
                          ? _record()
                          : _togglePlay(),
                    ),
                    child: Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: boxedFieldFill(c),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: boxedFieldBorder(c)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _recording ? null : TaraBrand.gradient,
                              color: _recording ? const Color(0xFFF01E2C) : null,
                            ),
                            alignment: Alignment.center,
                            child: TaraIcon(
                              _recording
                                  ? TaraIcons.stop
                                  : voice == null
                                  ? TaraIcons.mic
                                  : (_playing ? TaraIcons.stop : TaraIcons.play),
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  voiceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TaraText.small.copyWith(
                                    color: c.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _Waveform(filled: filled, moving: _recording || _playing),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Reprendre ou retirer ce qui a été joint.
        if (photo != null || (voice != null && !_recording))
          Wrap(
            spacing: 14,
            children: [
              if (photo != null) TaraLink(label: l.removePhoto, onPressed: () => widget.media.photo = null),
              if (voice != null && !_recording) ...[
                TaraLink(label: l.redoNote, onPressed: () => unawaited(_record())),
                TaraLink(label: l.removeNote, onPressed: () => widget.media.setVoice(null, Duration.zero)),
              ],
            ],
          ),
        if (_error != null) ...[const SizedBox(height: 8), ErrorLine(_error!)],
      ],
    );
  }
}

/// Clés de la photo de façade et de la note vocale (tests).
const facadePhotoKey = ValueKey('facade-photo');
const voiceNoteKey = ValueKey('voice-note');

/// Onde de la note vocale (maquette) : 18 barres, orange sur la part enregistrée, qui
/// ondulent pendant l'enregistrement ou l'écoute.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.filled, required this.moving});
  final int filled;
  final bool moving;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    const periods = [600, 750, 900, 1050];
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          for (var i = 0; i < 18; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            MotionBuilder(
              period: Duration(milliseconds: periods[i % 4]),
              delay: Duration(milliseconds: 60 * i),
              stillPhase: .5,
              builder: (context, t, child) => Transform.scale(
                scaleY: moving ? .35 + .65 * (1 - math.cos(t * 2 * math.pi)) / 2 : (i.isEven ? .7 : .45),
                child: child,
              ),
              child: Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: i < filled ? TaraBrand.orange : c.textPrimary.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
