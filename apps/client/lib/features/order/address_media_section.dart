import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../core/media/address_media.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.mediaSection, style: TaraText.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        GlassCard(
          radius: 18,
          shadow: false,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (photo != null)
                Semantics(
                  image: true,
                  label: l.facadePhotoLabel,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: c.track,
                      child: Image.file(File(photo), width: 56, height: 56, fit: BoxFit.cover),
                    ),
                  ),
                )
              else
                const IconTile(icon: TaraIcons.camera, size: 56, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.facadePhoto, style: TaraText.text.copyWith(color: c.textPrimary)),
                    Text(l.facadePhotoHint, style: TaraText.small.copyWith(color: c.textTertiary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      children: [
                        TaraLink(
                          label: photo == null ? l.takePhoto : l.retake,
                          onPressed: () => unawaited(_takePhoto()),
                        ),
                        if (photo != null) TaraLink(label: l.removeMedia, onPressed: () => widget.media.photo = null),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 18,
          shadow: false,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconTile(
                icon: _recording ? TaraIcons.stop : (voice == null ? TaraIcons.mic : TaraIcons.play),
                size: 56,
                radius: 12,
                tone: _recording ? TintTone.danger : TintTone.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.voiceNote, style: TaraText.text.copyWith(color: c.textPrimary)),
                    Semantics(
                      liveRegion: _recording,
                      child: Text(
                        _recording ? l.recordingNote(_clock(_elapsed)) : l.voiceNoteHint,
                        style: TaraText.small.copyWith(
                          color: _recording ? c.dangerText : c.textTertiary,
                          fontWeight: _recording ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      children: [
                        if (_recording)
                          TaraLink(label: l.stopRecording, onPressed: () => unawaited(_stopRecording()))
                        else if (voice == null)
                          TaraLink(label: l.recordNote, onPressed: () => unawaited(_record()))
                        else ...[
                          TaraLink(
                            label: _playing ? l.stopListening : l.listenNote(_clock(widget.media.voiceLength)),
                            onPressed: () => unawaited(_togglePlay()),
                          ),
                          TaraLink(label: l.redoNote, onPressed: () => unawaited(_record())),
                          TaraLink(label: l.removeMedia, onPressed: () => widget.media.setVoice(null, Duration.zero)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 8), ErrorLine(_error!)],
      ],
    );
  }
}
