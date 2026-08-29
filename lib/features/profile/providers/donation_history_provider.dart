import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

/// A completed donation — a blood request fulfilled by the current donor.
class DonationRecord {
  const DonationRecord({
    required this.requestId,
    required this.bloodGroup,
    required this.hospitalName,
    required this.city,
    required this.status,
    this.fulfilledAt,
    this.unitsNeeded = 1,
  });

  final String requestId;
  final String bloodGroup;
  final String hospitalName;
  final String city;
  final String status;
  final DateTime? fulfilledAt;
  final int unitsNeeded;

  factory DonationRecord.fromMap(Map<String, dynamic> map) => DonationRecord(
        requestId: map['id'] as String? ?? '',
        bloodGroup: map['blood_group'] as String? ?? '',
        hospitalName: map['hospital_name'] as String? ?? '',
        city: map['city'] as String? ?? '',
        status: map['status'] as String? ?? '',
        fulfilledAt: map['fulfilled_at'] != null
            ? DateTime.tryParse(map['fulfilled_at'] as String)
            : null,
        unitsNeeded: map['units_needed'] as int? ?? 1,
      );
}

/// Blood requests the current user donated towards (fulfilled or closed with
/// a donor recorded). Newest first.
///
/// Requires the donor-visible RLS policy on `blood_requests` (see
/// supabase/migrations/20260829_donor_request_history_rls.sql). Older
/// deployments without it simply return an empty list.
final donationHistoryProvider =
    FutureProvider<List<DonationRecord>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);

  try {
    final data = await client
        .from('blood_requests')
        .select(
            'id, blood_group, hospital_name, city, status, fulfilled_at, units_needed')
        .eq('fulfilled_by_donor_id', user.id)
        .not('fulfilled_at', 'is', null)
        .order('fulfilled_at', ascending: false)
        .limit(50);

    return (data as List)
        .map((row) => DonationRecord.fromMap(row as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Missing policy / network issue — never crash the profile screen.
    return <DonationRecord>[];
  }
});
