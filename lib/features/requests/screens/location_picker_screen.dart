import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

/// Full-screen map where the user drags to position a fixed centre pin.
///
/// Returns a record `(LatLng position, String? address)` via [Navigator.pop],
/// or null if the user cancels.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  final double? initialLat;
  final double? initialLng;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _mapController = MapController();
  Timer? _debounce;

  LatLng _currentCenter = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  String? _resolvedAddress;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
    }
    // Kick off initial reverse geocode after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveAddress(_currentCenter);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng position) async {
    setState(() => _isResolving = true);
    try {
      final location = ref.read(locationServiceProvider);
      final address =
          await location.resolveAddress(position.latitude, position.longitude);
      if (mounted) setState(() => _resolvedAddress = address);
    } catch (_) {
      // Silently ignore — the user can still confirm.
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _resolveAddress(camera.center);
    });
  }

  void _confirmLocation() {
    Navigator.of(context).pop((_currentCenter, _resolvedAddress));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: colors.card,
        foregroundColor: colors.textHigh,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 14.0,
              minZoom: 4,
              maxZoom: 18,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.donora.plus',
                maxZoom: 19,
              ),
            ],
          ),

          // ── Fixed centre pin ───────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  color: colors.primary,
                  size: 40,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── Drag hint ──────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Drag the map to position the pin',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom panel (address + confirm) ───────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address text
                  if (_isResolving && _resolvedAddress == null)
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Resolving address...',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: colors.textMedium,
                          ),
                        ),
                      ],
                    )
                  else if (_resolvedAddress != null)
                    Text(
                      _resolvedAddress!,
                      style: context.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '${_currentCenter.latitude.toStringAsFixed(5)}, '
                      '${_currentCenter.longitude.toStringAsFixed(5)}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.textMedium,
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Confirm button
                  PrimaryButton(
                    label: 'Confirm Location',
                    onPressed: _confirmLocation,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
