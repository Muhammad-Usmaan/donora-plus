import 'dart:math' show sin, cos, sqrt, atan2;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donor_status_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../services/providers.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/map_providers.dart';

// ── Haversine distance (local copy for list distance display) ────────────────

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

/// Full-screen map scoped to the user's current city using flutter_map +
/// OpenStreetMap tiles (no Google Maps or API-billed providers).
///
/// Donor markers: circular avatar pin with BloodTypeChip badge, coloured
/// border = Success green if verified, Neutral-300 if unverified.
/// Urgent request markers (donor view only): pulsing Urgent accent pin.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  bool _mapReady = false;
  String? _selectedDonorId;
  final ScrollController _sheetScrollController = ScrollController();

  @override
  void dispose() {
    _sheetScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRole = ref.watch(activeRoleProvider);
    final isDonor = activeRole == 'donor';
    final centerAsync = ref.watch(mapCenterProvider);
    final donorsAsync = ref.watch(filteredMapDonorsProvider);
    final requestsAsync = isDonor
        ? ref.watch(filteredMapRequestsProvider)
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────
          centerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Map error: $e')),
            data: (center) => _buildMap(
              center,
              donorsAsync,
              requestsAsync,
              isDonor,
            ),
          ),

          // ── Filter bar (top overlay) ───────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _FilterBar(onTap: _showFilterSheet),
          ),

          // ── Recenter button (bottom-right) ─────────────────────────
          Positioned(
            right: 16,
            bottom: 100,
            child: _RecenterButton(
              onPressed: () => _recenterToUser(),
            ),
          ),

          // ── Empty state (centered, only when no markers at all) ────
          _EmptyStateOverlay(
            donorsAsync: donorsAsync,
            requestsAsync: requestsAsync,
            isDonor: isDonor,
          ),
        ],
      ),
    );
  }

  // ── Map builder ─────────────────────────────────────────────────────────────

  Widget _buildMap(
    LatLng center,
    AsyncValue<List<Map<String, dynamic>>> donorsAsync,
    AsyncValue<List<Map<String, dynamic>>> requestsAsync,
    bool isDonor,
  ) {
    final colors = context.colors;
    final donors = donorsAsync.valueOrNull ?? [];
    final requests = requestsAsync.valueOrNull ?? [];

    // Use real-time GPS stream for the current location dot.
    final gpsAsync = ref.watch(positionStreamProvider);
    final currentLocation = gpsAsync.valueOrNull;

    // Auto-recenter map when GPS position updates.
    ref.listen<AsyncValue<LatLng?>>(positionStreamProvider, (_, next) {
      next.whenData((pos) {
        if (pos != null && _mapReady) {
          _mapController.move(pos, _mapController.camera.zoom);
        }
      });
    });

    // Build donor markers.
    final donorMarkers = donors.map((d) => _buildDonorMarker(d, colors)).toList();

    // Build urgent request markers (donor view only).
    final requestMarkers = isDonor
        ? requests.map((r) => _buildRequestMarker(r, colors)).toList()
        : <Marker>[];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: AppConstants.defaultZoom,
        minZoom: 5,
        maxZoom: 18,
        onMapReady: () => setState(() => _mapReady = true),
      ),
      children: [
        // OSM tile layer — free, no API key.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.donora.plus',
          maxZoom: 19,
        ),

        // Donor markers
        MarkerLayer(markers: donorMarkers),

        // Urgent request markers (donor view only)
        if (isDonor) MarkerLayer(markers: requestMarkers),

        // Current location indicator (subtle teal dot).
        if (currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation,
                width: 20,
                height: 20,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Donor marker ────────────────────────────────────────────────────────────

  Marker _buildDonorMarker(Map<String, dynamic> donor, dynamic colors) {
    final name = donor['name'] as String? ?? 'D';
    final bloodGroup = donor['blood_group'] as String? ?? '';
    final isVerified = donor['is_verified'] as bool? ?? false;
    final isSelected = donor['id'] == _selectedDonorId;
    final borderColor =
        isSelected ? colors.primary : (isVerified ? colors.success : colors.border);
    final borderWidth = isSelected ? 3.5 : 2.5;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return Marker(
      point: LatLng(
        (donor['lat'] as num).toDouble(),
        (donor['lng'] as num).toDouble(),
      ),
      width: isSelected ? 64 : 56,
      height: isSelected ? 64 : 56,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _showDonorSheet(donor),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main circle (with selection glow)
            Container(
              width: isSelected ? 48 : 40,
              height: isSelected ? 48 : 40,
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.12),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isVerified ? colors.success : colors.textMedium,
                  ),
                ),
              ),
            ),
            // Blood type badge (bottom-right)
            if (bloodGroup.isNotEmpty)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.card, width: 1.5),
                  ),
                  child: Text(
                    bloodGroup,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Urgent request marker ──────────────────────────────────────────────────

  Marker _buildRequestMarker(Map<String, dynamic> request, dynamic colors) {
    return Marker(
      point: LatLng(
        (request['lat'] as num).toDouble(),
        (request['lng'] as num).toDouble(),
      ),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _showRequestSheet(request),
        child: _PulsingPinMarker(
          color: colors.urgent,
          child: const Icon(
            Icons.bloodtype,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showDonorSheet(Map<String, dynamic> donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DonorDetailSheet(donor: donor),
    );
  }

  void _showRequestSheet(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailSheet(request: request),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedDonorId: _selectedDonorId,
        onDonorTap: _focusOnDonor,
      ),
    );
  }

  void _recenterToUser() async {
    if (!_mapReady) return;

    final locService = ref.read(locationServiceProvider);
    
    // Try to get fresh GPS coordinates
    final pos = await locService.getCurrentPosition();
    if (pos != null) {
      final lat = pos.latitude;
      final lng = pos.longitude;
      
      // Attempt to resolve city and update Supabase
      try {
        final city = await locService.resolveCity(lat, lng) ?? '';
        final fields = <String, dynamic>{
          'latitude': lat,
          'longitude': lng,
        };
        if (city.isNotEmpty) {
          fields['city'] = city;
        }
        await ref.read(updateProfileFieldProvider)(fields);
      } catch (_) {
        // Silently fail DB updates if something goes wrong
      }

      // Move camera
      _mapController.move(LatLng(lat, lng), AppConstants.defaultZoom);
      
      // Invalidate providers so the blue dot and map center refresh
      ref.invalidate(currentPositionProvider);
      ref.invalidate(positionStreamProvider);
    } else {
      // Fall back to city-based center if GPS fails
      final centerAsync = ref.read(mapCenterProvider);
      centerAsync.whenData((center) {
        _mapController.move(center, AppConstants.defaultZoom);
      });
    }
  }

  void _focusOnDonor(Map<String, dynamic> donor) {
    final lat = (donor['lat'] as num?)?.toDouble();
    final lng = (donor['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _mapController.move(
      LatLng(lat, lng),
      15.0,
    );
    setState(() => _selectedDonorId = donor['id'] as String?);
    Navigator.of(context).pop();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pulsing pin marker (for urgent requests)
// ═══════════════════════════════════════════════════════════════════════════════

class _PulsingPinMarker extends StatefulWidget {
  const _PulsingPinMarker({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_PulsingPinMarker> createState() => _PulsingPinMarkerState();
}

class _PulsingPinMarkerState extends State<_PulsingPinMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final scale = 1.0 + (_controller.value * 0.15);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.2 + _controller.value * 0.15),
                shape: BoxShape.circle,
              ),
            ),
            // Pin
            Transform.scale(
              scale: scale,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(child: widget.child),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Floating filter bar
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(mapFilterProvider);
    final colors = context.colors;
    final activeCount = filter.selectedBloodTypes.length;
    final hasFilters =
        activeCount > 0 || filter.compatibleWithMe || filter.radiusKm != 100.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.tune, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                !hasFilters
                    ? 'Filter by blood type & distance'
                    : [
                        if (activeCount > 0)
                          '$activeCount blood type${activeCount > 1 ? 's' : ''}',
                        if (filter.compatibleWithMe) 'Compatible',
                        '${filter.radiusKm.round()} km',
                      ].join(' · '),
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFilters)
              GestureDetector(
                onTap: () {
                  ref.read(mapFilterProvider.notifier).clearFilters();
                },
                child: Icon(Icons.close, size: 18, color: colors.textMedium),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: colors.textMedium),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Filter bottom sheet (with matching donors list)
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({
    this.selectedDonorId,
    this.onDonorTap,
  });

  final String? selectedDonorId;
  final void Function(Map<String, dynamic> donor)? onDonorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(mapFilterProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final colors = context.colors;
    final donorsAsync = ref.watch(filteredMapDonorsProvider);
    final centerAsync = ref.watch(mapCenterProvider);
    final center = centerAsync.valueOrNull;

    final showCompatToggle =
        activeRole == 'seeker' && (profile?.bloodGroup.isNotEmpty ?? false);

    final hasFilters = filter.isFilteringBlood ||
        filter.radiusKm != 100.0 ||
        filter.compatibleWithMe;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    hasFilters ? 8 : 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Filter Map',
                        style: context.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),

                      // Blood type chips
                      Text(
                        'Blood Type',
                        style: context.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.bloodTypes.map((type) {
                          final isSelected =
                              filter.selectedBloodTypes.contains(type);
                          return BloodTypeChip(
                            bloodType: type,
                            selected: isSelected,
                            onTap: () => ref
                                .read(mapFilterProvider.notifier)
                                .toggleBloodType(type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Compatible-with-me toggle
                      if (showCompatToggle)
                        _MapFilterToggleRow(
                          icon: Icons.bloodtype,
                          label: 'Compatible with me',
                          selected: filter.compatibleWithMe,
                          activeColor: colors.primary,
                          inactiveColor: colors.primaryContainer,
                          onTap: () => ref
                              .read(mapFilterProvider.notifier)
                              .setCompatibleWithMe(
                                  !filter.compatibleWithMe),
                        ),
                      const SizedBox(height: 24),

                      // Distance radius slider
                      Text(
                        'Distance Radius',
                        style: context.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: colors.primary,
                                inactiveTrackColor: colors.border,
                                thumbColor: colors.primary,
                                overlayColor: colors.primary
                                    .withValues(alpha: 0.12),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: filter.radiusKm,
                                min: 5,
                                max: 100,
                                divisions: 19,
                                onChanged: (v) => ref
                                    .read(mapFilterProvider.notifier)
                                    .setRadius(v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${filter.radiusKm.round()} km',
                              style:
                                  context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Clear button
                      if (hasFilters)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => ref
                                .read(mapFilterProvider.notifier)
                                .clearFilters(),
                            child: Text(
                              'Clear all filters',
                              style:
                                  TextStyle(color: colors.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Matching Donors list (only when filters are active) ──
              if (hasFilters) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.mapPin,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Matching Donors',
                          style: context.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        donorsAsync.when(
                          data: (donors) => Text(
                            '${donors.length}',
                            style: context.textTheme.bodySmall
                                ?.copyWith(color: colors.textMedium),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                donorsAsync.when(
                  data: (donors) {
                    if (donors.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _MapFilterEmptyState(),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final donor = donors[index];
                          final donorId =
                              donor['id'] as String? ?? '';
                          final dLat =
                              (donor['lat'] as num?)?.toDouble();
                          final dLng =
                              (donor['lng'] as num?)?.toDouble();
                          final distKm = (center != null &&
                                  dLat != null &&
                                  dLng != null)
                              ? _distanceKm(
                                  center,
                                  LatLng(dLat, dLng),
                                )
                              : null;
                          return _MapFilterDonorCard(
                            donor: donor,
                            distanceKm: distKm,
                            isSelected:
                                donorId == selectedDonorId,
                            onTap: () =>
                                onDonorTap?.call(donor),
                          );
                        },
                        childCount: donors.length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Could not load donors',
                          style: context.textTheme.bodySmall
                              ?.copyWith(color: colors.textMedium),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom + 20,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Matching donor card (inside filter bottom sheet)
// ═══════════════════════════════════════════════════════════════════════════════

class _MapFilterDonorCard extends StatelessWidget {
  const _MapFilterDonorCard({
    required this.donor,
    required this.distanceKm,
    required this.isSelected,
    required this.onTap,
  });

  final Map<String, dynamic> donor;
  final double? distanceKm;
  final bool isSelected;
  final VoidCallback onTap;

  String get _initials {
    final name = donor['name'] as String? ?? '';
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    if (words.isEmpty) return '?';
    return words.map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = donor['name'] as String? ?? 'Donor';
    final bloodGroup = donor['blood_group'] as String? ?? '';
    final isVerified = donor['is_verified'] == true;
    final photoUrl = donor['profile_photo_url'] as String?;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final classification =
        donor['donor_classification'] as String? ?? 'volunteer';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AppCard(
        borderColor: isSelected ? colors.primary : null,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.primaryContainer,
              backgroundImage:
                  hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      _initials,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Name, distance, classification
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style:
                              context.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const VerifiedBadge(compact: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.mapPin,
                        size: 14,
                        color: colors.textMedium,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceKm != null
                            ? '${distanceKm!.toStringAsFixed(1)} km away'
                            : 'Distance unknown',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.textMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DonorStatusChip(classification: classification),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Blood type
            if (bloodGroup.isNotEmpty)
              BloodTypeChip(bloodType: bloodGroup, compact: true),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Empty state for matching donors list
// ═══════════════════════════════════════════════════════════════════════════════

class _MapFilterEmptyState extends StatelessWidget {
  const _MapFilterEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.mapPin,
            size: 36,
            color: colors.textMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching donors found',
            style: context.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Try expanding your radius or changing filters.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reusable filter toggle row (used in the map filter bottom sheet)
// ═══════════════════════════════════════════════════════════════════════════════

class _MapFilterToggleRow extends StatelessWidget {
  const _MapFilterToggleRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : activeColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : activeColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Recenter button
// ═══════════════════════════════════════════════════════════════════════════════

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.card,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Icon(
            Icons.my_location,
            color: colors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Empty state overlay
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyStateOverlay extends ConsumerWidget {
  const _EmptyStateOverlay({
    required this.donorsAsync,
    required this.requestsAsync,
    required this.isDonor,
  });

  final AsyncValue<List<Map<String, dynamic>>> donorsAsync;
  final AsyncValue<List<Map<String, dynamic>>> requestsAsync;
  final bool isDonor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donors = donorsAsync.valueOrNull;
    final requests = requestsAsync.valueOrNull;

    // Only show if data has loaded and both lists are empty.
    if (donors == null || (isDonor && requests == null)) {
      return const SizedBox.shrink(); // still loading
    }
    if (donors.isNotEmpty) return const SizedBox.shrink();
    if (isDonor && (requests?.isNotEmpty ?? false)) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;

    return Positioned(
      left: 32,
      right: 32,
      bottom: 180,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 36,
              color: colors.textMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'No donors found nearby',
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Try expanding your radius or clearing filters.',
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Donor detail bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _DonorDetailSheet extends StatelessWidget {
  const _DonorDetailSheet({required this.donor});

  final Map<String, dynamic> donor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = donor['name'] as String? ?? 'Unknown Donor';
    final bloodGroup = donor['blood_group'] as String? ?? '';
    final city = donor['city'] as String? ?? '';
    final isVerified = donor['is_verified'] as bool? ?? false;
    final classification =
        donor['donor_classification'] as String? ?? 'volunteer';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Profile row
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isVerified
                      ? colors.secondaryContainer
                      : colors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isVerified ? colors.success : colors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isVerified ? colors.secondary : colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: context.textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (bloodGroup.isNotEmpty) ...[
                          BloodTypeChip(bloodType: bloodGroup),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: classification == 'volunteer'
                                ? colors.volunteer.withValues(alpha: 0.12)
                                : colors.compensated.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            classification == 'volunteer'
                                ? 'Volunteer'
                                : 'Compensated',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: classification == 'volunteer'
                                  ? colors.volunteer
                                  : colors.compensated,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: colors.textMedium),
                          const SizedBox(width: 4),
                          Text(city, style: context.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'View Full Profile',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.pushNamed(
                      RouteNames.donorDetail,
                      pathParameters: {'id': donor['id'] as String? ?? ''},
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 48,
                child: Material(
                  color: colors.secondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      final lat = (donor['lat'] as num?)?.toDouble();
                      final lng = (donor['lng'] as num?)?.toDouble();
                      if (lat != null && lng != null) {
                        MapUtils.openNavigation(lat, lng,
                            label: name);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.navigation,
                      color: colors.secondary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Request detail bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _RequestDetailSheet extends StatelessWidget {
  const _RequestDetailSheet({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bloodGroup = request['blood_group'] as String? ?? '';
    final hospital = request['hospital_name'] as String? ?? '';
    final city = request['city'] as String? ?? '';
    final notes = request['notes'] as String? ?? '';
    final unitsNeeded = request['units_needed'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Urgent badge + blood type
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.urgent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bloodtype, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'URGENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (bloodGroup.isNotEmpty) BloodTypeChip(bloodType: bloodGroup),
              if (unitsNeeded > 0) ...[
                const Spacer(),
                Text(
                  '$unitsNeeded unit${unitsNeeded > 1 ? 's' : ''}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Hospital
          if (hospital.isNotEmpty)
            Row(
              children: [
                Icon(Icons.local_hospital_outlined,
                    size: 16, color: colors.textMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hospital,
                    style: context.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          // City
          if (city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: colors.textMedium),
                const SizedBox(width: 4),
                Text(city, style: context.textTheme.bodySmall),
              ],
            ),
          ],

          // Notes
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: context.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Respond',
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: Navigate to respond flow.
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.pushNamed(RouteNames.chat);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textHigh,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 48,
                child: Material(
                  color: colors.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Navigate to hospital — use city coords as fallback.
                      final cityKey = city.toLowerCase();
                      final coords =
                          AppConstants.cityCoords[cityKey];
                      if (coords != null) {
                        MapUtils.openNavigation(
                          coords.lat,
                          coords.lng,
                          label: hospital.isNotEmpty
                              ? hospital
                              : city,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.navigation,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
