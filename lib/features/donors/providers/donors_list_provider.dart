import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

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
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String city;
  final bool isVerified;
  final bool isTopDonor;
  final String donorClassification;
  final String? profilePhotoUrl;

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
      );
}

/// Immutable filter state for the Donors screen.
class DonorListFilter {
  const DonorListFilter({
    this.query = '',
    this.selectedBloodTypes = const <String>{},
    this.verifiedOnly = false,
  });

  /// Free-text search on name and city.
  final String query;

  /// Empty set means "all blood types".
  final Set<String> selectedBloodTypes;

  final bool verifiedOnly;

  bool get isFilteringBlood => selectedBloodTypes.isNotEmpty;

  DonorListFilter copyWith({
    String? query,
    Set<String>? selectedBloodTypes,
    bool? verifiedOnly,
  }) {
    return DonorListFilter(
      query: query ?? this.query,
      selectedBloodTypes: selectedBloodTypes ?? this.selectedBloodTypes,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
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

  void clearFilters() => state = const DonorListFilter();
}

final donorListFilterProvider =
    StateNotifierProvider<DonorListFilterNotifier, DonorListFilter>((ref) {
  return DonorListFilterNotifier();
});

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
      .from('profiles')
      .select(
          'id, name, blood_group, city, is_verified, is_top_donor, '
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

/// Donors filtered by the current [DonorListFilter].
final filteredDonorsProvider = Provider<List<DonorListItem>>((ref) {
  final donors = ref.watch(donorsListProvider).valueOrNull ?? [];
  final filter = ref.watch(donorListFilterProvider);

  final query = filter.query.trim().toLowerCase();

  return donors.where((d) {
    if (filter.verifiedOnly && !d.isVerified) return false;
    if (filter.isFilteringBlood &&
        !filter.selectedBloodTypes.contains(d.bloodGroup)) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchesName = d.name.toLowerCase().contains(query);
      final matchesCity = d.city.toLowerCase().contains(query);
      if (!matchesName && !matchesCity) return false;
    }
    return true;
  }).toList();
});
