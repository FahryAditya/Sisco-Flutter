import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

enum VoiceState { idle, recording, playing }

class VoiceService {
  static final VoiceService instance = VoiceService._();
  VoiceService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  VoiceState _state = VoiceState.idle;
  String? _currentPath;

  VoiceState get state => _state;
  String? get currentPath => _currentPath;

  final ValueNotifier<VoiceState> stateNotifier = ValueNotifier(VoiceState.idle);

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _state = VoiceState.recording;
      _currentPath = path;
      stateNotifier.value = VoiceState.recording;
      return path;
    } catch (e) {
      debugPrint('Start recording error: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _state = VoiceState.idle;
      _currentPath = path;
      stateNotifier.value = VoiceState.idle;
      return path;
    } catch (e) {
      debugPrint('Stop recording error: $e');
      _state = VoiceState.idle;
      stateNotifier.value = VoiceState.idle;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
      if (_currentPath != null) {
        final f = File(_currentPath!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    _state = VoiceState.idle;
    _currentPath = null;
    stateNotifier.value = VoiceState.idle;
  }

  Future<void> play(String path) async {
    try {
      _state = VoiceState.playing;
      stateNotifier.value = VoiceState.playing;
      await _player.play(DeviceFileSource(path));
      _player.onPlayerComplete.listen((_) {
        _state = VoiceState.idle;
        stateNotifier.value = VoiceState.idle;
      });
    } catch (e) {
      debugPrint('Play error: $e');
      _state = VoiceState.idle;
      stateNotifier.value = VoiceState.idle;
    }
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _state = VoiceState.idle;
    stateNotifier.value = VoiceState.idle;
  }

  Future<Uint8List?> readBytes(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Duration? get playbackPosition => _player.getCurrentPosition() as Duration?;

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
