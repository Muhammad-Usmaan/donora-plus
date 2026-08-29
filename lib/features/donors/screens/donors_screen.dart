import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Donor list screen — browse and filter available donors.
class DonorsScreen extends ConsumerWidget {
  const DonorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Donors — coming soon')),
    );
  }
}
