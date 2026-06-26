import 'package:geolocator/geolocator.dart';

/// Captures the device location (with the user's permission) for the
/// weather / environmental-disaster alerts feature.
///
/// Works on web (browser geolocation prompt), mobile and desktop. The last
/// known position is cached so the dashboard can reuse it without re-prompting.
class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  Position? _last;
  Position? get last => _last;

  /// Requests permission if needed and returns the current position.
  ///
  /// Returns null (instead of throwing) when location services are off or the
  /// user denies permission, so callers can simply show a "location unavailable"
  /// state rather than crash.
  Future<Position?> getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _last;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _last;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // a few km is plenty for weather
      );
      _last = pos;
      return pos;
    } catch (_) {
      // Permission plugin unavailable / timed out — degrade gracefully.
      return _last;
    }
  }
}
