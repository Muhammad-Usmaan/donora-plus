import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestFilterBuilder, PostgrestList;

import '../../../core/constants/request_reasons.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

/// Which set of requests the Requests screen shows.
enum RequestsScope {
  /// Active, unexpired requests from the whole community (RLS-enforced).
  all,

  /// The current user's own requests in any status.
  mine,
}

/// A request card entry in the Requests list.
class RequestListItem {
  const RequestListItem({
    required this.id,
    required this.requesterId,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.hospitalName,
    required this.city,
    required this.isUrgent,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.notes,
    this.reason = RequestReason.other,
    this.reasonNote,
    this.plannedDate,
    this.donationType = 'blood',
  });

  final String id;
  final String requesterId;
  final String bloodGroup;
  final int unitsNeeded;
  final String hospitalName;
  final String city;
  final bool isUrgent;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? notes;

  /// Why blood is needed — shown as a pill on cards and detail.
  final RequestReason reason;

  /// Free-text note shown when [reason] is [RequestReason.other].
  final String? reasonNote;

  /// When the donation is actually needed (non-urgent / pre-planned only).
  final DateTime? plannedDate;

  /// Donation type — 'blood' or 'platelet'.
  final String donationType;

  bool get isActive => status == 'active' && !isExpired;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Human-friendly status label used on cards.
  String get statusLabel {
    switch (status) {
      case 'fulfilled':
        return 'Fulfilled';
      case 'closed':
        return 'Closed';
      case 'expired':
        return 'Expired';
      case 'active':
        return isExpired ? 'Expired' : 'Active';
      default:
        return status;
    }
  }

  factory RequestListItem.fromMap(Map<String, dynamic> map) => RequestListItem(
    id: map['id'] as String? ?? '',
    requesterId: map['requester_id'] as String? ?? '',
    bloodGroup: map['blood_group'] as String? ?? '',
    unitsNeeded: map['units_needed'] as int? ?? 1,
    hospitalName: map['hospital_name'] as String? ?? '',
    city: map['city'] as String? ?? '',
    isUrgent: map['is_urgent'] as bool? ?? false,
    status: map['status'] as String? ?? 'active',
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    expiresAt:
        DateTime.tryParse(map['expires_at'] as String? ?? '') ??
        DateTime.now().add(const Duration(hours: 72)),
    notes: map['notes'] as String?,
    reason: RequestReason.fromValue(map['reason'] as String?),
    reasonNote: map['reason_note'] as String?,
    plannedDate: map['planned_date'] != null
        ? DateTime.tryParse(map['planned_date'] as String)
        : null,
    donationType: map['donation_type'] as String? ?? 'blood',
  );
}

/// Immutable filter state for the Requests screen.
class RequestListFilter {
  const RequestListFilter({
    this.scope = RequestsScope.all,
    this.selectedBloodTypes = const <String>{},
    this.urgentOnly = false,
  });

  final RequestsScope scope;

  /// Empty set means "all blood types".
  final Set<String> selectedBloodTypes;

  /// When true, only urgent requests are shown.
  final bool urgentOnly;

  bool get isFilteringBlood => selectedBloodTypes.isNotEmpty;

  RequestListFilter copyWith({
    RequestsScope? scope,
    Set<String>? selectedBloodTypes,
    bool? urgentOnly,
  }) {
    return RequestListFilter(
      scope: scope ?? this.scope,
      selectedBloodTypes: selectedBloodTypes ?? this.selectedBloodTypes,
      urgentOnly: urgentOnly ?? this.urgentOnly,
    );
  }
}

class RequestListFilterNotifier extends StateNotifier<RequestListFilter> {
  RequestListFilterNotifier() : super(const RequestListFilter());

  void setScope(RequestsScope scope) => state = state.copyWith(scope: scope);

  void toggleBloodType(String type) {
    final types = Set<String>.from(state.selectedBloodTypes);
    types.contains(type) ? types.remove(type) : types.add(type);
    state = state.copyWith(selectedBloodTypes: types);
  }

  void setUrgentOnly(bool value) => state = state.copyWith(urgentOnly: value);

  void clearFilters() => state = RequestListFilter(scope: state.scope);
}

final requestListFilterProvider =
    StateNotifierProvider<RequestListFilterNotifier, RequestListFilter>((ref) {
      return RequestListFilterNotifier();
    });

/// Requests for the current scope:
/// - [RequestsScope.all] — active & unexpired community requests (matches the
///   `blood_requests_select` RLS policy),
/// - [RequestsScope.mine] — the user's own requests in any status.
///
/// Watches only the scope (the server-side part of the query); blood-type and
/// urgent filters are applied client-side by [filteredRequestsProvider] so
/// tapping a chip never triggers a refetch.
final requestsListProvider = FutureProvider<List<RequestListItem>>((ref) async {
  final scope = ref.watch(requestListFilterProvider.select((f) => f.scope));
  final client = ref.watch(supabaseClientProvider);

  const columns =
      'id, requester_id, blood_group, units_needed, hospital_name, city, '
      'is_urgent, status, created_at, expires_at, notes, reason, '
      'reason_note, planned_date, donation_type';

  // Filters first (filter builder), then the shared order/limit chain —
  // .order()/.limit() return a transform builder, so both are applied
  // after the branch to keep one static type.
  final PostgrestFilterBuilder<PostgrestList> query;
  if (scope == RequestsScope.mine) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return <RequestListItem>[];
    query = client
        .from('blood_requests')
        .select(columns)
        .eq('requester_id', user.id);
  } else {
    query = client
        .from('blood_requests')
        .select(columns)
        .eq('status', 'active')
        // UTC — Postgres parses naive timestamps as UTC, so a local-time
        // string would shift the cutoff by the device offset (e.g. +5h in
        // PKT) and hide requests close to expiry.
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());
  }

  final data = await query.order('created_at', ascending: false).limit(100);
  return (data as List)
      .map((row) => RequestListItem.fromMap(row as Map<String, dynamic>))
      .toList();
});

/// Requests filtered by the current [RequestListFilter].
final filteredRequestsProvider = Provider<List<RequestListItem>>((ref) {
  final requests = ref.watch(requestsListProvider).valueOrNull ?? [];
  final filter = ref.watch(requestListFilterProvider);

  return requests.where((r) {
    if (filter.urgentOnly && !r.isUrgent) return false;
    if (filter.isFilteringBlood &&
        !filter.selectedBloodTypes.contains(r.bloodGroup)) {
      return false;
    }
    return true;
  }).toList();
});
