import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

/// Result of a donor-report submission attempt.
enum DonorReportResult {
  /// Report was inserted successfully.
  success,

  /// The caller already has a pending report against this donor
  /// (unique partial index rejected the insert).
  duplicatePending,

  /// Something else went wrong (network, RLS, etc.).
  error,
}

/// Inserts a row into `donor_reports`.
///
/// Returns [DonorReportResult.duplicatePending] when the backend unique
/// index `uq_donor_reports_pending` rejects the insert (i.e. the user
/// already has an unresolved report against this donor).
Future<DonorReportResult> submitDonorReport({
  required WidgetRef ref,
  required String reportedUserId,
  required String reason,
}) async {
  // Validate inputs before touching Supabase.
  if (reportedUserId.isEmpty) {
    debugPrint('[donor_report] reportedUserId is empty — aborting.');
    return DonorReportResult.error;
  }

  final String reporterId;
  final SupabaseClient client;
  try {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      debugPrint('[donor_report] currentUser is null — not authenticated.');
      return DonorReportResult.error;
    }
    if (user.id.isEmpty) {
      debugPrint('[donor_report] currentUser.id is empty — aborting.');
      return DonorReportResult.error;
    }
    reporterId = user.id;
    client = ref.read(supabaseClientProvider);
  } catch (e, st) {
    debugPrint('[donor_report] Failed to read providers: $e\n$st');
    return DonorReportResult.error;
  }

  // Prevent self-reports client-side (backend CHECK also guards this).
  if (reporterId == reportedUserId) {
    debugPrint('[donor_report] reporter_id == reported_user_id — aborting.');
    return DonorReportResult.error;
  }

  try {
    await client.from('donor_reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reason': reason.trim(),
    });
    return DonorReportResult.success;
  } on PostgrestException catch (e) {
    // PostgreSQL unique-violation → duplicate pending report.
    if (e.code == '23505') return DonorReportResult.duplicatePending;
    debugPrint(
      '[donor_report] PostgrestException: code=${e.code}, '
      'message=${e.message}, details=${e.details}',
    );
    return DonorReportResult.error;
  } catch (e, st) {
    debugPrint('[donor_report] Unexpected error: $e\n$st');
    return DonorReportResult.error;
  }
}
