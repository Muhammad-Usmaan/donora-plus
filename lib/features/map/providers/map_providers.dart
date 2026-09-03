import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/location/location_service.dart';
import '../../../services/providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import '../../home/providers/home_providers.dart';

// ── Map filter state ──────────────────────────────────────────────────────────

/// Immutable filter state for the map screen.
class MapFilter {
  const MapFilter({
    this.selectedBloodTypes = const <String>{},
    this.radiusKm = 100.0,
    this.compatibleWithMe = false,
  });

  /// Empty set means "all blood types" (no filter).
  final Set<String> selectedBloodTypes;
  final double radiusKm;

  /// When true, only donors whose blood group is compatible with the
  /// current seeker's blood group are shown (uses [AppConstants.compatibleDonors]).
  final bool compatibleWithMe;

  bool get isFilteringBlood => selectedBloodTypes.isNotEmpty;

  MapFilter copyWith({
    Set<String>? selectedBloodTypes,
    double? radiusKm,
    bool? compatibleWithMe,
  }) {
    return MapFilter(
      selectedBloodTypes: selectedBloodTypes ?? this.selectedBloodTypes,
      radiusKm: radiusKm ?? this.radiusKm,
      compatibleWithMe: compatibleWithMe ?? this.compatibleWithMe,
    );
  }
}

class MapFilterNotifier extends StateNotifier<MapFilter> {
  MapFilterNotifier() : super(const MapFilter());

  void toggleBloodType(String type) {
    final types = Set<String>.from(state.selectedBloodTypes);
    types.contains(type) ? types.remove(type) : types.add(type);
    state = state.copyWith(selectedBloodTypes: types);
  }

  void setRadius(double km) => state = state.copyWith(radiusKm: km);

  void setCompatibleWithMe(bool value) =>
      state = state.copyWith(compatibleWithMe: value);

  void clearFilters() => state = const MapFilter();
}

final mapFilterProvider =
    StateNotifierProvider<MapFilterNotifier, MapFilter>((ref) {
  return MapFilterNotifier();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

double _distanceKm(LatLng a, LatLng b) {
  const R = 6371.0;
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLng = (b.longitude - a.longitude) * pi / 180;
  final sinDLat = sin(dLat / 2);
  final sinDLng = sin(dLng / 2);
  final h = sinDLat * sinDLat +
      cos(a.latitude * pi / 180) *
          cos(b.latitude * pi / 180) *
          sinDLng * sinDLng;
  return R * 2 * atan2(sqrt(h), sqrt(1 - h));
}

// ── GPS current position ─────────────────────────────────────────────────────

/// The user's real-time GPS position, or null if unavailable or outside Pakistan.
final currentPositionProvider = FutureProvider<LatLng?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  try {
    final position = await locationService.getCurrentPosition();
    if (position != null &&
        LocationService.isInPakistan(position.latitude, position.longitude)) {
      return LatLng(position.latitude, position.longitude);
    }
  } catch (_) {
    // GPS unavailable — fall through to null.
  }
  return null;
});

/// Real-time GPS position stream — emits updates as the device moves.
final positionStreamProvider = StreamProvider<LatLng?>((ref) async* {
  final locationService = ref.watch(locationServiceProvider);
  final stream = locationService.getPositionStream();
  if (stream == null) {
    yield null;
    return;
  }
  await for (final position in stream) {
    if (LocationService.isInPakistan(position.latitude, position.longitude)) {
      yield LatLng(position.latitude, position.longitude);
    }
  }
});

// ── Map center ────────────────────────────────────────────────────────────────

/// The map's initial centre — user's city from profile first, then GPS position if
/// valid in Pakistan, or Islamabad default as last resort.
final mapCenterProvider = FutureProvider<LatLng>((ref) async {
  // 1. Try city from profile first.
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    try {
      final client = ref.watch(supabaseClientProvider);
      final profile = await client
          .from('profiles')
          .select('city')
          .eq('id', user.id)
          .maybeSingle();

      final city = (profile?['city'] as String?)?.toLowerCase();
      if (city != null && AppConstants.cityCoords.containsKey(city)) {
        final coords = AppConstants.cityCoords[city]!;
        return LatLng(coords.lat, coords.lng);
      }
    } catch (_) {}
  }

  // 2. Try GPS position if available and inside Pakistan.
  final gpsAsync = ref.watch(currentPositionProvider);
  final gpsPos = gpsAsync.valueOrNull;
  if (gpsPos != null) return gpsPos;

  // 3. Fallback to Islamabad capital default.
  return const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
});

// ── Donors for map ────────────────────────────────────────────────────────────

/// All donor profiles (verified + unverified) with their actual GPS positions.
final mapDonorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final client = ref.watch(supabaseClientProvider);

  var query = client
      .from('profiles_public')
      .select(
          'id, name, blood_group, city, latitude, longitude, is_verified, donor_classification, profile_photo_url')
      .eq('active_role', 'donor');

  if (user != null) {
    query = query.neq('id', user.id);
  }

  final donors = await query.limit(50);

  return (donors as List).map((d) {
    final row = Map<String, dynamic>.from(d as Map);
    
    // Use the donor's actual GPS coordinates from the database.
    // Fall back to city center if coordinates are missing.
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    
    if (lat != null && lng != null && LocationService.isInPakistan(lat, lng)) {
      row['lat'] = lat;
      row['lng'] = lng;
    } else {
      // Fallback: use city center coordinates if GPS is unavailable.
      final city = (row['city'] as String? ?? '').toLowerCase();
      final cityCoords = AppConstants.cityCoords[city];
      if (cityCoords != null) {
        row['lat'] = cityCoords.lat;
        row['lng'] = cityCoords.lng;
      } else {
        // Last resort: Islamabad default
        row['lat'] = AppConstants.defaultLatitude;
        row['lng'] = AppConstants.defaultLongitude;
      }
    }
    
    return row;
  }).toList();
});

// ── Urgent requests for map ──────────────────────────────────────────────────

/// Active + urgent blood requests with their actual GPS positions.
final mapUrgentRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  final requests = await client
      .from('blood_requests')
      .select(
          'id, blood_group, hospital_name, city, latitude, longitude, notes, units_needed, is_urgent, requester_id')
      .eq('status', 'active')
      .eq('is_urgent', true)
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: false)
      .limit(30);

  return (requests as List).map((r) {
    final row = Map<String, dynamic>.from(r as Map);
    
    // Use the request's actual GPS coordinates from the database.
    // Fall back to city center if coordinates are missing.
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    
    if (lat != null && lng != null && LocationService.isInPakistan(lat, lng)) {
      row['lat'] = lat;
      row['lng'] = lng;
    } else {
      // Fallback: use city center coordinates if GPS is unavailable.
      final city = (row['city'] as String? ?? '').toLowerCase();
      final cityCoords = AppConstants.cityCoords[city];
      if (cityCoords != null) {
        row['lat'] = cityCoords.lat;
        row['lng'] = cityCoords.lng;
      } else {
        // Last resort: Islamabad default
        row['lat'] = AppConstants.defaultLatitude;
        row['lng'] = AppConstants.defaultLongitude;
      }
    }
    
    return row;
  }).toList();
});

// ── Filtered providers (react to filter changes) ─────────────────────────────

/// Donors filtered by selected blood types and distance radius, sorted by distance.
final filteredMapDonorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final donors = await ref.watch(mapDonorsProvider.future);
  final filter = ref.watch(mapFilterProvider);
  final centerAsync = ref.watch(mapCenterProvider);
  final profileAsync = ref.watch(userProfileProvider);
  final profile = profileAsync.valueOrNull;

  // Resolve compatible donor types for the current seeker.
  final compatibleTypes = (filter.compatibleWithMe &&
          profile != null &&
          profile.bloodGroup.isNotEmpty)
      ? AppConstants.compatibleDonors[profile.bloodGroup] ?? const <String>[]
      : null;

  return centerAsync.when(
    loading: () => donors,
    error: (_, _) => donors,
    data: (center) {
      // Filter donors based on all active criteria.
      final filtered = donors.where((d) {
        // Blood type filter
        if (filter.isFilteringBlood) {
          final bg = d['blood_group'] as String? ?? '';
          if (!filter.selectedBloodTypes.contains(bg)) return false;
        }
        // Compatibility filter
        if (compatibleTypes != null) {
          final bg = d['blood_group'] as String? ?? '';
          if (!compatibleTypes.contains(bg)) return false;
        }
        // Distance filter (from viewer's center to donor's actual position)
        final pos = LatLng(
          (d['lat'] as num).toDouble(),
          (d['lng'] as num).toDouble(),
        );
        return _distanceKm(center, pos) <= filter.radiusKm;
      }).toList();

      // Sort by distance from the viewer's center (nearest first).
      filtered.sort((a, b) {
        final aPos = LatLng(
          (a['lat'] as num).toDouble(),
          (a['lng'] as num).toDouble(),
        );
        final bPos = LatLng(
          (b['lat'] as num).toDouble(),
          (b['lng'] as num).toDouble(),
        );
        final distA = _distanceKm(center, aPos);
        final distB = _distanceKm(center, bPos);
        return distA.compareTo(distB);
      });

      return filtered;
    },
  );
});

/// Urgent requests filtered by selected blood types and distance radius.
final filteredMapRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final requests = await ref.watch(mapUrgentRequestsProvider.future);
  final filter = ref.watch(mapFilterProvider);
  final centerAsync = ref.watch(mapCenterProvider);

  return centerAsync.when(
    loading: () => requests,
    error: (_, _) => requests,
    data: (center) {
      return requests.where((r) {
        if (filter.isFilteringBlood) {
          final bg = r['blood_group'] as String? ?? '';
          if (!filter.selectedBloodTypes.contains(bg)) return false;
        }
        // Distance filter (from viewer's center to request's actual position)
        final pos = LatLng(
          (r['lat'] as num).toDouble(),
          (r['lng'] as num).toDouble(),
        );
        return _distanceKm(center, pos) <= filter.radiusKm;
      }).toList();
    },
  );
});
