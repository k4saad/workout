import 'package:geolocator/geolocator.dart';

import '../domain/run/run.dart';
import 'run_tracker.dart';

/// The phone's GPS, through geolocator.
///
/// Listening starts geolocator's foreground service: a visible, ongoing
/// "Run in progress" notification, started from a tap in the app, which is
/// what lets a run record with the screen off. When the last listener goes,
/// the service stops. There is no background location: the manifest does not
/// ask for it, and nothing here needs it.
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
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationAccess.denied,
    };
  }

  @override
  Stream<RunFix> watch() =>
      Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Run in progress',
            notificationText: 'Recording your route. It stays on this phone.',
            notificationChannelName: 'Run tracking',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      ).map(
        (p) => RunFix(
          tMs: p.timestamp.millisecondsSinceEpoch,
          lat: p.latitude,
          lng: p.longitude,
          accuracyM: p.accuracy,
          altitudeM: p.altitudeAccuracy > 0 ? p.altitude : null,
          speedMps: p.speed >= 0 ? p.speed : null,
        ),
      );

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
