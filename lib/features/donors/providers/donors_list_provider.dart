import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/location/location_service.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../map/providers/map_providers.dart';

/// A donor card entry in the Donors list.
class DonorListItem {
  const DonorListItem({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.city,
    required this.isVerified,
    required this.isTopDonor,
    required this.donorClassification,
    this.profilePhotoUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String city;
  final bool isVerified;
  final bool isTopDonor;
  final String donorClassification;
  final String? profilePhotoUrl;
  final double? latitude;
  final double? longitude;

  factory DonorListItem.fromMap(Map<String, dynamic> map) => DonorListItem(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Donor',
        bloodGroup: map['blood_group'] as String? ?? '',
        city: map['city'] as String? ?? '',
        isVerified: map['is_verified'] as bool? ?? false,
        isTopDonor: map['is_top_donor'] as bool? ?? false,
        donorClassification:
            map['donor_classification'] as String? ?? 'volunteer',
        profilePhotoUrl: map['profile_photo_url'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );
}

/// Immutable filter state for the Donors screen.
class DonorListFilter {
  const DonorListFilter({
    this.query = '',
    this.selectedBloodTypes = const <String>{},
    this.verifiedOnly = false,
    this.compatibleWithMe = false,
  });

  /// Free-text search on name and city.
  final String query;

  /// Empty set means "all blood types".
  final Set<String> selectedBloodTypes;

  final bool verifiedOnly;

  /// When true, only donors whose blood group is compatible with the
  /// current seeker's blood group are shown (uses [AppConstants.compatibleDonors]).
  final bool compatibleWithMe;

  bool get isFilteringBlood => selectedBloodTypes.isNotEmpty;

  DonorListFilter copyWith({
    String? query,
    Set<String>? selectedBloodTypes,
    bool? verifiedOnly,
    bool? compatibleWithMe,
  }) {
    return DonorListFilter(
      query: query ?? this.query,
      selectedBloodTypes: selectedBloodTypes ?? this.selectedBloodTypes,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      compatibleWithMe: compatibleWithMe ?? this.compatibleWithMe,
    );
  }
}

class DonorListFilterNotifier extends StateNotifier<DonorListFilter> {
  DonorListFilterNotifier() : super(const DonorListFilter());

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleBloodType(String type) {
    final types = Set<String>.from(state.selectedBloodTypes);
    types.contains(type) ? types.remove(type) : types.add(type);
    state = state.copyWith(selectedBloodTypes: types);
  }

  void setVerifiedOnly(bool value) =>
      state = state.copyWith(verifiedOnly: value);

  void setCompatibleWithMe(bool value) =>
      state = state.copyWith(compatibleWithMe: value);

  void clearFilters() => state = const DonorListFilter();
}

final donorListFilterProvider =
    StateNotifierProvider<DonorListFilterNotifier, DonorListFilter>((ref) {
  return DonorListFilterNotifier();
});

/// Calculates the distance in kilometers between two coordinates using the Haversine formula.
double _distanceKm(LatLng a, LatLng b) {
  const R = 6371.0; // Earth's radius in kilometers
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

/// All donor profiles, newest members first. The UI applies client-side
/// filtering (search text, blood type chips, verified toggle) on top —
/// the donor universe is small enough that server-side filtering isn't
/// needed yet.
///
/// Intentionally does NOT watch [donorListFilterProvider]: the fetch is
/// filter-independent, so typing in the search box must not refetch.
final donorsListProvider = FutureProvider<List<DonorListItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final client = ref.watch(supabaseClientProvider);

  var query = client
      .from('profiles_public')
      .select(
          'id, name, blood_group, city, latitude, longitude, is_verified, is_top_donor, '
          'donor_classification, profile_photo_url')
      .eq('active_role', 'donor');

  if (user != null) {
    query = query.neq('id', user.id);
  }

  final data = await query
      .order('created_at', ascending: false)
      .limit(200);

  return (data as List)
      .map((row) => DonorListItem.fromMap(row as Map<String, dynamic>))
      .toList();
});

/// Donors filtered by the current [DonorListFilter], sorted by distance from the user.
final filteredDonorsProvider = Provider<List<DonorListItem>>((ref) {
  final donors = ref.watch(donorsListProvider).valueOrNull ?? [];
  final filter = ref.watch(donorListFilterProvider);
  final profileAsync = ref.watch(userProfileProvider);
  final profile = profileAsync.valueOrNull;
  final userPositionAsync = ref.watch(positionStreamProvider);
  final userPosition = userPositionAsync.valueOrNull;

  // Resolve compatible donor types for the current seeker.
  final compatibleTypes = (filter.compatibleWithMe &&
          profile != null &&
          profile.bloodGroup.isNotEmpty)
      ? AppConstants.compatibleDonors[profile.bloodGroup] ?? const <String>[]
      : null;

  final query = filter.query.trim().toLowerCase();

  // Filter donors based on all active criteria.
  final filtered = donors.where((d) {
    if (filter.verifiedOnly && !d.isVerified) return false;
    if (filter.isFilteringBlood &&
        !filter.selectedBloodTypes.contains(d.bloodGroup)) {
      return false;
    }
    if (compatibleTypes != null &&
        !compatibleTypes.contains(d.bloodGroup)) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchesName = d.name.toLowerCase().contains(query);
      final matchesCity = d.city.toLowerCase().contains(query);
      if (!matchesName && !matchesCity) return false;
    }
    return true;
  }).toList();

  // Sort by distance from user's current position (nearest first).
  // Donors without valid coordinates are placed at the end.
  if (userPosition != null) {
    filtered.sort((a, b) {
      final aLat = a.latitude;
      final aLng = a.longitude;
      final bLat = b.latitude;
      final bLng = b.longitude;

      // Check if both donors have valid coordinates in Pakistan.
      final aValid = aLat != null &&
          aLng != null &&
          LocationService.isInPakistan(aLat, aLng);
      final bValid = bLat != null &&
          bLng != null &&
          LocationService.isInPakistan(bLat, bLng);

      // Donors without valid coordinates go to the end.
      if (!aValid && !bValid) return 0;
      if (!aValid) return 1;
      if (!bValid) return -1;

      // Both have valid coordinates: sort by distance.
      final aPos = LatLng(aLat, aLng);
      final bPos = LatLng(bLat, bLng);
      final distA = _distanceKm(userPosition, aPos);
      final distB = _distanceKm(userPosition, bPos);
      return distA.compareTo(distB);
    });
  } else {
    // No user position available: fall back to city-based sorting.
    // Use the default center (Islamabad) as reference.
    final defaultCenter = const LatLng(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );

    filtered.sort((a, b) {
      // Try to use donor's coordinates if available.
      final aLat = a.latitude;
      final aLng = a.longitude;
      final bLat = b.latitude;
      final bLng = b.longitude;

      final aValid = aLat != null &&
          aLng != null &&
          LocationService.isInPakistan(aLat, aLng);
      final bValid = bLat != null &&
          bLng != null &&
          LocationService.isInPakistan(bLat, bLng);

      if (!aValid && !bValid) {
        // Both missing coordinates: sort by city name.
        return a.city.compareTo(b.city);
      }
      if (!aValid) return 1;
      if (!bValid) return -1;

      // Both have valid coordinates: sort by distance from default center.
      final aPos = LatLng(aLat, aLng);
      final bPos = LatLng(bLat, bLng);
      final distA = _distanceKm(defaultCenter, aPos);
      final distB = _distanceKm(defaultCenter, bPos);
      return distA.compareTo(distB);
    });
  }

  return filtered;
});
