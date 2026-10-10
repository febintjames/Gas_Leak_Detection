import 'package:firebase_database/firebase_database.dart';

import '../models.dart';

/// The detector this app shows (same as DEVICE_PATH in the ESP32 sketch)
const deviceId = 'gas01';

/// Reads the detector data. The database rules allow anyone to read /devices
/// (nobody can write except the ESP32), so no Firebase sign-in is needed.
class DeviceService {
  static DatabaseReference get _device =>
      FirebaseDatabase.instance.ref('devices/$deviceId');

  static Stream<DeviceState> watchState() => _device
      .child('state')
      .onValue
      .map((e) => DeviceState.fromSnapshot(e.snapshot));

  /// Newest first. Push keys are time-ordered, so the last N keys are the latest events.
  static Stream<List<GasEvent>> watchEvents({int limit = 100}) =>
      _device.child('events').limitToLast(limit).onValue.map(
            (e) => e.snapshot.children
                .map(GasEvent.fromSnapshot)
                .whereType<GasEvent>()
                .toList()
                .reversed
                .toList(),
          );
}
