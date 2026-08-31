import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/location/location_service.dart';
import '../../../services/providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Map filter state ──────────────────────────────────────────────────────────

/// Immutable filter state for the map screen.
class MapFilter {
  const MapFilter({
    this.selectedBloodTypes = const <String>{},
    this.radiusKm = 25.0,
  });

  /// Empty set means "all blood types" (no filter).
  final Set<String> selectedBloodTypes;
  final double radiusKm;

  bool get isFilteringBlood => selectedBloodTypes.isNotEmpty;

  MapFilter copyWith({
    Set<String>? selectedBloodTypes,
    double? radiusKm,
  }) {
    return MapFilter(
      selectedBloodTypes: selectedBloodTypes ?? this.selectedBloodTypes,
      radiusKm: radiusKm ?? this.radiusKm,
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

  void clearFilters() => state = const MapFilter();
}

final mapFilterProvider =
    StateNotifierProvider<MapFilterNotifier, MapFilter>((ref) {
  return MapFilterNotifier();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Deterministic pseudo-random offset so each donor gets a stable position
/// around the city centre based on their UUID.
LatLng _scatterFromId(String id, LatLng center) {
  final hash = id.hashCode;
  final rng = Random(hash);
  final dLat = (rng.nextDouble() - 0.5) * 0.06; // ≈ ±3 km
  final dLng = (rng.nextDouble() - 0.5) * 0.06;
  return LatLng(center.latitude + dLat, center.longitude + dLng);
}

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

/// All donor profiles (verified + unverified) with scatter positions.
final mapDonorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final client = ref.watch(supabaseClientProvider);
  final centerAsync = ref.watch(mapCenterProvider);

  return centerAsync.when(
    loading: () => <Map<String, dynamic>>[],
    error: (_, _) => <Map<String, dynamic>>[],
    data: (center) async {
      var query = client
          .from('profiles')
          .select(
              'id, name, blood_group, city, is_verified, donor_classification, profile_photo_url')
          .eq('active_role', 'donor');

      if (user != null) {
        query = query.neq('id', user.id);
      }

      final donors = await query.limit(50);

      return (donors as List).map((d) {
        final row = Map<String, dynamic>.from(d as Map);
        final pos = _scatterFromId(row['id'] as String, center);
        row['lat'] = pos.latitude;
        row['lng'] = pos.longitude;
        return row;
      }).toList();
    },
  );
});

// ── Urgent requests for map ──────────────────────────────────────────────────

/// Active + urgent blood requests with scatter positions (donor view only).
final mapUrgentRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final centerAsync = ref.watch(mapCenterProvider);

  return centerAsync.when(
    loading: () => <Map<String, dynamic>>[],
    error: (_, _) => <Map<String, dynamic>>[],
    data: (center) async {
      final requests = await client
          .from('blood_requests')
          .select(
              'id, blood_group, hospital_name, city, notes, units_needed, is_urgent, requester_id')
          .eq('status', 'active')
          .eq('is_urgent', true)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(30);

      return (requests as List).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        final pos = _scatterFromId(row['id'] as String, center);
        row['lat'] = pos.latitude;
        row['lng'] = pos.longitude;
        return row;
      }).toList();
    },
  );
});

// ── Filtered providers (react to filter changes) ─────────────────────────────

/// Donors filtered by selected blood types and distance radius.
final filteredMapDonorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final donors = await ref.watch(mapDonorsProvider.future);
  final filter = ref.watch(mapFilterProvider);
  final centerAsync = ref.watch(mapCenterProvider);

  return centerAsync.when(
    loading: () => donors,
    error: (_, _) => donors,
    data: (center) {
      return donors.where((d) {
        // Blood type filter
        if (filter.isFilteringBlood) {
          final bg = d['blood_group'] as String? ?? '';
          if (!filter.selectedBloodTypes.contains(bg)) return false;
        }
        // Distance filter
        final pos = LatLng(
          (d['lat'] as num).toDouble(),
          (d['lng'] as num).toDouble(),
        );
        return _distanceKm(center, pos) <= filter.radiusKm;
      }).toList();
    },
  );
});

/// Urgent requests filtered by blood types and distance radius.
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
        final pos = LatLng(
          (r['lat'] as num).toDouble(),
          (r['lng'] as num).toDouble(),
        );
        return _distanceKm(center, pos) <= filter.radiusKm;
      }).toList();
    },
  );
});
