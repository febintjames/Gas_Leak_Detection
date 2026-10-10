import 'package:firebase_database/firebase_database.dart';

/// Live status the ESP32 writes to /devices/{id}/state
class DeviceState {
  const DeviceState({
    required this.gas,
    required this.value,
    required this.threshold,
    this.updatedAt,
  });

  final bool gas;
  final int value;
  final int threshold;
  final DateTime? updatedAt;

  /// The ESP32 writes its status every 60 s, so 2.5 min without an update means offline.
  static const offlineAfter = Duration(seconds: 150);

  bool isOnline(DateTime now) =>
      updatedAt != null && now.difference(updatedAt!) < offlineAfter;

  factory DeviceState.fromSnapshot(DataSnapshot snapshot) {
    final Map m = snapshot.value is Map ? snapshot.value as Map : const {};
    return DeviceState(
      gas: m['gas'] == true,
      value: _toInt(m['value']) ?? 0,
      threshold: _toInt(m['threshold']) ?? 400,
      updatedAt: _toTime(m['updatedAt']),
    );
  }
}

/// One entry of /devices/{id}/events: a leak or an all-clear
class GasEvent {
  const GasEvent({required this.isLeak, required this.value, required this.at});

  final bool isLeak;
  final int value;
  final DateTime at;

  static GasEvent? fromSnapshot(DataSnapshot snapshot) {
    final m = snapshot.value;
    if (m is! Map) return null;
    final at = _toTime(m['at']);
    if (at == null) return null;
    return GasEvent(
      isLeak: m['type'] == 'leak',
      value: _toInt(m['value']) ?? 0,
      at: at,
    );
  }
}

int? _toInt(Object? v) => v is num ? v.toInt() : null;

DateTime? _toTime(Object? v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
