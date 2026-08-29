import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the initialized Supabase client via Riverpod.
///
/// Usage in any ConsumerWidget:
///   final supabase = ref.watch(supabaseClientProvider);
///
/// The client is initialized in main.dart before the app starts.
/// NEVER instantiate SupabaseClient directly inside widgets —
/// always consume it through this provider.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
