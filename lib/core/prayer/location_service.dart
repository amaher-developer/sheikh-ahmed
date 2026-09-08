import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  const LocationResult(this.latitude, this.longitude);
}

/// Thrown when the OS-level location service (GPS) is turned off.
class LocationServiceDisabledException implements Exception {}

/// Thrown when the user denies (or has permanently denied) the location
/// permission request.
class LocationPermissionDeniedException implements Exception {}

/// Thin wrapper around `geolocator` so the rest of the app depends on a
/// small interface instead of the plugin directly. A device GPS fix needs
/// no network access — this stays offline-first like the rest of the app.
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw LocationServiceDisabledException();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedException();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return LocationResult(position.latitude, position.longitude);
  }
}
