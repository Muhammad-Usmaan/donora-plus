import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Handles device geolocation and reverse-geocoding to city names.
class LocationService {
  LocationService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Checks if [lat]/[lng] is within Pakistan's geographical bounding box.
  /// Used to ignore Android emulator default coordinates (Mountain View, CA).
  static bool isInPakistan(double lat, double lng) {
    return lat >= 23.0 && lat <= 37.5 && lng >= 60.0 && lng <= 78.0;
  }

  /// Checks and requests location permissions.
  /// Returns true if permission is granted.
  Future<bool> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    if (permission == LocationPermission.denied) {
      final granted = await Geolocator.requestPermission();
      return granted == LocationPermission.always ||
          granted == LocationPermission.whileInUse;
    }

    return false;
  }

  /// Returns the device's current position, or null if unavailable.
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  /// Reverse-geocodes [lat]/[lng] to a city name using Nominatim.
  /// Scoped to Pakistan for better results.
  Future<String?> resolveCity(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&accept-language=en'
        '&countrycodes=pk',
      );
      final response = await _http.get(
        uri,
        headers: {'User-Agent': 'DonoraPlus/1.0'},
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      return address?['city'] as String? ??
          address?['town'] as String? ??
          address?['municipality'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocodes [lat]/[lng] to a full human-readable address string.
  /// Used by the location picker screen to show the selected address.
  Future<String?> resolveAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&accept-language=en'
        '&countrycodes=pk&zoom=18',
      );
      final response = await _http.get(
        uri,
        headers: {'User-Agent': 'DonoraPlus/1.0'},
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Calculates the distance in meters between two coordinates.
  double distanceInMeters(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
