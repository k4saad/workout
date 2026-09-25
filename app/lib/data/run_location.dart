import 'package:geolocator/geolocator.dart';

import '../domain/run/run.dart';
import 'run_tracker.dart';

/// The phone's GPS, through geolocator.
///
/// Only a RECORDING stream starts geolocator's foreground service: a visible,
/// ongoing "Recording your run" notification, started from a tap in the app,
/// which is what lets a run record with the screen off. Looking for a fix
/// before Start is an ordinary foreground stream with no notification, so the
/// phone never says a run is going when none is. There is no background
/// location: the manifest does not ask for it, and nothing here needs it.
///
/// Fixes stay on the phone. This file hands them to the tracker and nothing
/// else; the tracker writes them to the app-private database.
class GeolocatorSource implements LocationSource {
  const GeolocatorSource();

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final granted = switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => true,
      _ => false,
    };
    if (!granted) {
      return permission == LocationPermission.deniedForever
          ? LocationAccess.deniedForever
          : LocationAccess.denied;
    }
    // Android asks "precise or approximate" in the same dialog. Approximate
    // is a fix a kilometre wide: the run would sit on "waiting" forever.
    final accuracy = await Geolocator.getLocationAccuracy();
    return accuracy == LocationAccuracyStatus.reduced
        ? LocationAccess.approximate
        : LocationAccess.granted;
  }

  @override
  Future<RunFix?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : _fix(p);
    } on Object {
      return null;
    }
  }

  @override
  Stream<RunFix> watch({bool recording = false}) =>
      Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: recording
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'Recording your run',
                  notificationText: 'Your route stays on this phone.',
                  notificationChannelName: 'Run tracking',
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        ),
      ).map(_fix);

  static RunFix _fix(Position p) => RunFix(
    tMs: p.timestamp.millisecondsSinceEpoch,
    lat: p.latitude,
    lng: p.longitude,
    accuracyM: p.accuracy,
    altitudeM: p.altitudeAccuracy > 0 ? p.altitude : null,
    speedMps: p.speed >= 0 ? p.speed : null,
  );

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
