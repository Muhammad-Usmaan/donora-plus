import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase/storage_service.dart';
import 'supabase_client_provider.dart';

/// Provides the SupabaseStorageService for file uploads/downloads.
final storageServiceProvider = Provider<SupabaseStorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseStorageService(client);
});
