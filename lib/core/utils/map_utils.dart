import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Helpers for opening external map applications.
class MapUtils {
  const MapUtils._();

  /// Opens Google Maps (or Apple Maps on iOS) with driving directions
  /// to the given coordinates.
  static Future<void> openNavigation(
    double lat,
    double lng, {
    String? label,
  }) async {
    // Try the native Google Maps URI first (works on Android with Google Maps installed).
    if (Platform.isAndroid) {
      final nativeUri = Uri.parse(
        'google.navigation:q=$lat,$lng&mode=d',
      );
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
        return;
      }
    }

    if (Platform.isIOS) {
      // Try Apple Maps first (always available on iOS).
      final appleUri = Uri.parse(
        'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
      );
      if (await canLaunchUrl(appleUri)) {
        await launchUrl(appleUri);
        return;
      }
    }

    // Fallback: open in browser (works on all platforms).
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Opens Google Maps search for a city/place name when coordinates are
  /// unavailable. Works cross-platform via the maps search web URL.
  static Future<void> openNavigationByName(String cityName) async {
    final query = Uri.encodeComponent(cityName);

    if (Platform.isIOS) {
      final appleUri = Uri.parse('https://maps.apple.com/?q=$query');
      if (await canLaunchUrl(appleUri)) {
        await launchUrl(appleUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Opens Google Maps (or Apple Maps) showing a specific location pin.
  static Future<void> openPlaceMarker(
    double lat,
    double lng, {
    String? label,
  }) async {
    final query = label != null && label.isNotEmpty
        ? Uri.encodeComponent('$label $lat,$lng')
        : '$lat,$lng';

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
