import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Siren that plays in the app when a gas leak starts.
/// Stops by itself after [duration], or when the user taps "Stop alarm".
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final instance = AlarmService._();

  static const duration = Duration(seconds: 5);

  final _player = AudioPlayer();
  Timer? _autoStop;
  bool isPlaying = false;

  Future<void> start() async {
    if (isPlaying) return;
    isPlaying = true;
    notifyListeners();
    _autoStop = Timer(duration, stop);
    await _player.setReleaseMode(ReleaseMode.loop); // 1 s siren, repeated
    await _player.play(AssetSource('sounds/gas_alarm.wav'), volume: 1.0);
  }

  Future<void> stop() async {
    _autoStop?.cancel();
    if (!isPlaying) return;
    isPlaying = false;
    notifyListeners();
    await _player.stop();
  }
}
