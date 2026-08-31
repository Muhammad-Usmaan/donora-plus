import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/request_reasons.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/urgent_button.dart';
import '../../../services/location/location_service.dart';
import '../../../services/providers.dart';
import '../../home/providers/home_providers.dart';
import '../providers/request_create_provider.dart';
import '../providers/request_detail_provider.dart';

/// "Request Blood" full-screen form (Create & Edit).
///
/// Reached via the UrgentButton on the seeker home screen or the Edit button
/// on the Request Detail screen.
/// Fields: blood type, urgency, reason, city, hospital, units, notes,
/// contact pref.
/// On submit: shows success state with "View Request" button.
class RequestCreateScreen extends ConsumerStatefulWidget {
  const RequestCreateScreen({
    super.key,
    this.initialRequest,
    this.editRequestId,
  });

  final RequestDetail? initialRequest;
  final String? editRequestId;

  @override
  ConsumerState<RequestCreateScreen> createState() =>
      _RequestCreateScreenState();
}

class _RequestCreateScreenState extends ConsumerState<RequestCreateScreen> {
  final _patientNameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _notesController = TextEditingController();
  final _reasonNoteController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialRequest != null) {
        ref
            .read(requestCreateProvider.notifier)
            .initializeForEdit(widget.initialRequest!);
        _patientNameController.text = widget.initialRequest!.patientName;
        _hospitalController.text = widget.initialRequest!.hospitalName;
        _notesController.text = widget.initialRequest!.notes ?? '';
        _reasonNoteController.text = widget.initialRequest!.reasonNote ?? '';
      } else if (widget.editRequestId != null) {
        ref
            .read(requestDetailProvider(widget.editRequestId!).future)
            .then((req) {
          if (mounted) {
            ref
                .read(requestCreateProvider.notifier)
                .initializeForEdit(req);
            _patientNameController.text = req.patientName;
            _hospitalController.text = req.hospitalName;
            _notesController.text = req.notes ?? '';
            _reasonNoteController.text = req.reasonNote ?? '';
          }
        }).catchError((_) {});
      } else {
        ref.read(requestCreateProvider.notifier).resetForCreate();
        // Pre-fill city from user profile.
        ref
            .read(userProfileProvider.future)
            .then((profile) {
              if (mounted) {
                ref
                    .read(requestCreateProvider.notifier)
                    .prefillCity(profile.city);
              }
            })
            .catchError((_) {
              // Profile unavailable (not signed in, network error, etc.).
              // The user can still select a city manually.
            });
      }
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    _reasonNoteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(requestCreateProvider);
    final colors = context.colors;

    // If successfully submitted, show the success state.
    if (formState.isSubmitted) {
      return _SuccessView(
        requestId: formState.createdRequestId!,
        isEditing: formState.isEditing,
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(formState.isEditing ? 'Edit Request' : 'Request Blood'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Scrollable form ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Server error banner ──────────────────────────
                  if (formState.serverError != null)
                    _ErrorBanner(message: formState.serverError!),
                  if (formState.serverError != null)
                    const SizedBox(height: 16),

                  // ── Blood type (required) ────────────────────────
                  const _SectionLabel(label: 'Blood Type Needed', required: true),
                  const SizedBox(height: 12),
                  _BloodTypeGrid(
                    selected: formState.bloodGroup,
                    onTap: (type) => ref
                        .read(requestCreateProvider.notifier)
                        .setBloodGroup(type),
                  ),
                  const SizedBox(height: 24),

                  // ── Urgency level ────────────────────────────────
                  const _SectionLabel(label: 'Urgency Level', required: true),
                  const SizedBox(height: 12),
                  _UrgencySegmentedControl(
                    isUrgent: formState.isUrgent,
                    onChanged: (v) => ref
                        .read(requestCreateProvider.notifier)
                        .setUrgent(v),
                  ),
                  const SizedBox(height: 16),

                  // ── Planned date (non-urgent only) ────────────────
                  if (!formState.isUrgent)
                    _PlannedDatePicker(
                      selectedDate: formState.plannedDate,
                      onDateSelected: (date) => ref
                          .read(requestCreateProvider.notifier)
                          .setPlannedDate(date),
                    ),
                  if (!formState.isUrgent) const SizedBox(height: 24),

                  // ── Reason for request (required) ──
                  const _SectionLabel(
                      label: 'Reason for Request', required: true),
                  const SizedBox(height: 12),
                  _ReasonChipSelect(
                    selected: formState.reason,
                    onChanged: (reason) => ref
                        .read(requestCreateProvider.notifier)
                        .setReason(reason),
                  ),
                  if (formState.reason == RequestReason.other) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonNoteController,
                      onChanged: (v) => ref
                          .read(requestCreateProvider.notifier)
                          .setReasonNote(v),
                      maxLength: 60,
                      decoration: InputDecoration(
                        hintText: 'Briefly tell donors why (optional)',
                        filled: true,
                        fillColor: colors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: colors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Patient Name (required) ──────────────────────
                  const _SectionLabel(
                      label: 'Patient Full Name', required: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _patientNameController,
                    onChanged: (v) => ref
                        .read(requestCreateProvider.notifier)
                        .setPatientName(v),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ali Ahmed',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: colors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── City / location ──────────────────────────────
                  const _SectionLabel(label: 'City / Location', required: true),
                  const SizedBox(height: 12),
                  _LocationSelector(
                    selected: formState.city,
                    onCitySelected: (city) => ref
                        .read(requestCreateProvider.notifier)
                        .setCity(city),
                    onLocationPicked: (lat, lng, city) => ref
                        .read(requestCreateProvider.notifier)
                        .setLocation(lat, lng, city),
                  ),
                  const SizedBox(height: 24),

                  // ── Hospital name ────────────────────────────────
                  const _SectionLabel(label: 'Hospital / Location Name', required: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hospitalController,
                    onChanged: (v) => ref
                        .read(requestCreateProvider.notifier)
                        .setHospitalName(v),
                    decoration: InputDecoration(
                      hintText: 'e.g. Shaukat Khanum Hospital',
                      prefixIcon: const Icon(Icons.local_hospital_outlined),
                      filled: true,
                      fillColor: colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Units needed ─────────────────────────────────
                  const _SectionLabel(label: 'Units Needed', required: true),
                  const SizedBox(height: 12),
                  _UnitsStepper(
                    value: formState.unitsNeeded,
                    onIncrement: () => ref
                        .read(requestCreateProvider.notifier)
                        .incrementUnits(),
                    onDecrement: () => ref
                        .read(requestCreateProvider.notifier)
                        .decrementUnits(),
                  ),
                  const SizedBox(height: 24),

                  // ── Additional notes ─────────────────────────────
                  const _SectionLabel(label: 'Additional Notes'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    onChanged: (v) => ref
                        .read(requestCreateProvider.notifier)
                        .setNotes(v),
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Any additional information for donors...',
                      filled: true,
                      fillColor: colors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Contact preference ───────────────────────────
                  const _SectionLabel(label: 'Contact Preference'),
                  const SizedBox(height: 12),
                  _ContactPreferenceToggle(
                    allowPhoneCall: formState.allowPhoneCall,
                    onChanged: (v) => ref
                        .read(requestCreateProvider.notifier)
                        .setAllowPhoneCall(v),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Sticky submit button ──────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.border, width: 1)),
            ),
            child: UrgentButton(
              label: formState.isEditing ? 'Save Changes' : 'Post Request',
              isLoading: formState.isSubmitting,
              onPressed: formState.isValid
                  ? () => ref.read(requestCreateProvider.notifier).submit()
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section label
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              color: context.colors.urgent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Error banner
// ═══════════════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.urgentContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.urgent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.urgent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.urgent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Blood type grid
// ═══════════════════════════════════════════════════════════════════════════════

class _BloodTypeGrid extends StatelessWidget {
  const _BloodTypeGrid({required this.selected, required this.onTap});

  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: AppConstants.bloodTypes.map((type) {
        final isSelected = selected == type;
        return BloodTypeChip(
          bloodType: type,
          selected: isSelected,
          onTap: () => onTap(type),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Reason chip select (wrap of selectable reason pills)
// ═══════════════════════════════════════════════════════════════════════════

class _ReasonChipSelect extends StatelessWidget {
  const _ReasonChipSelect({
    required this.selected,
    required this.onChanged,
  });

  final RequestReason? selected;
  final ValueChanged<RequestReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final reason in RequestReason.values)
          _ReasonChip(
            reason: reason,
            isSelected: reason == selected,
            onTap: () => onChanged(reason),
          ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  final RequestReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = reason.accent(colors);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.5)
                : colors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              reason.icon,
              size: 14,
              color: isSelected ? accent : colors.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              reason.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? accent : colors.textMedium,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Urgency segmented control
// ═══════════════════════════════════════════════════════════════════════════════

class _UrgencySegmentedControl extends StatelessWidget {
  const _UrgencySegmentedControl({
    required this.isUrgent,
    required this.onChanged,
  });

  final bool isUrgent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _UrgencyOption(
              label: 'Urgent',
              subtitle: 'Within hours',
              isActive: isUrgent,
              isUrgentType: true,
              activeColor: colors.urgent,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _UrgencyOption(
              label: 'Planned',
              subtitle: 'Within days',
              isActive: !isUrgent,
              isUrgentType: false,
              activeColor: colors.primary,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyOption extends StatelessWidget {
  const _UrgencyOption({
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.isUrgentType,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isActive;
  final bool isUrgentType;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isActive)
                  Icon(
                    isUrgentType
                        ? Icons.warning_amber_rounded
                        : Icons.schedule,
                    size: 16,
                    color: Colors.white,
                  ),
                if (isActive) const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : context.colors.textMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isActive
                    ? Colors.white.withValues(alpha: 0.8)
                    : context.colors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Planned date picker (non-urgent requests)
// ═══════════════════════════════════════════════════════════════════════════════

class _PlannedDatePicker extends StatelessWidget {
  const _PlannedDatePicker({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'When do you need this?',
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'Needed By Date', required: true),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedDate != null
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.border,
                width: selectedDate != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: selectedDate != null
                      ? colors.primary
                      : colors.textMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? _formatDate(selectedDate!)
                        : 'Select the date donation is needed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selectedDate != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selectedDate != null
                          ? colors.textHigh
                          : colors.textMedium,
                    ),
                  ),
                ),
                if (selectedDate != null)
                  IconButton(
                    onPressed: () => _pickDate(context),
                    icon: Icon(
                      Icons.edit_calendar,
                      size: 18,
                      color: colors.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Location selector (searchable city + GPS + map picker)
// ═══════════════════════════════════════════════════════════════════════════════

class _LocationSelector extends ConsumerStatefulWidget {
  const _LocationSelector({
    required this.selected,
    required this.onCitySelected,
    required this.onLocationPicked,
  });

  final String? selected;
  final ValueChanged<String> onCitySelected;
  final void Function(double lat, double lng, String city) onLocationPicked;

  @override
  ConsumerState<_LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends ConsumerState<_LocationSelector> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showDropdown = false;
  String _searchQuery = '';
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _searchController.text = widget.selected!;
    }
    _focusNode.addListener(() {
      setState(() => _showDropdown = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _LocationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected &&
        widget.selected != _searchController.text) {
      _searchController.text = widget.selected ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> get _filteredCities {
    if (_searchQuery.isEmpty) return AppConstants.defaultCities;
    final q = _searchQuery.toLowerCase();
    return AppConstants.defaultCities
        .where((c) => c.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = ref.read(locationServiceProvider);
      final pos = await location.getCurrentPosition();
      if (pos == null || !mounted) {
        _showError('Could not get your location. Check permissions.');
        return;
      }
      if (!LocationService.isInPakistan(pos.latitude, pos.longitude)) {
        _showError('Location is outside Pakistan. Please select your city manually.');
        return;
      }
      final city = await location.resolveCity(
          pos.latitude, pos.longitude);
      if (!mounted) return;
      if (city != null) {
        widget.onLocationPicked(pos.latitude, pos.longitude, city);
        _searchController.text = city;
      } else {
        // Fall back to coordinates if city resolution fails.
        final addr = '${pos.latitude.toStringAsFixed(4)}, '
            '${pos.longitude.toStringAsFixed(4)}';
        widget.onLocationPicked(pos.latitude, pos.longitude, addr);
        _searchController.text = addr;
      }
      _focusNode.unfocus();
    } catch (e) {
      if (mounted) _showError('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _selectFromMap() async {
    _focusNode.unfocus();
    setState(() => _showDropdown = false);
    final result = await context.pushNamed<(LatLng, String?)>(
      RouteNames.locationPicker,
    );
    if (result != null && mounted) {
      final (position, address) = result;
      // Try to extract a short city name from the address.
      final city = address?.split(',').first.trim() ?? 'Custom location';
      widget.onLocationPicked(
          position.latitude, position.longitude, city);
      _searchController.text = city;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Searchable city field ─────────────────────────────
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _showDropdown = hasFocus);
          },
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search Pakistani city...',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Dropdown list ─────────────────────────────────────
        if (_showDropdown && _filteredCities.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _filteredCities.length,
              itemBuilder: (_, i) {
                final city = _filteredCities[i];
                return ListTile(
                  dense: true,
                  title: Text(city),
                  onTap: () {
                    widget.onCitySelected(city);
                    _searchController.text = city;
                    _focusNode.unfocus();
                    setState(() => _showDropdown = false);
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 12),

        // ── Quick action buttons ──────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLocating ? null : _useCurrentLocation,
                icon: _isLocating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_isLocating ? 'Locating...' : 'Current Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectFromMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Select on Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Units stepper
// ═══════════════════════════════════════════════════════════════════════════════

class _UnitsStepper extends StatelessWidget {
  const _UnitsStepper({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            onPressed: value > 1 ? onDecrement : null,
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                '$value',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'unit${value > 1 ? 's' : ''}',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          _StepperButton(
            icon: Icons.add,
            onPressed: value < 10 ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = onPressed != null;

    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: isEnabled ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Icon(
            icon,
            size: 22,
            color: isEnabled ? colors.primary : colors.border,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Contact preference toggle
// ═══════════════════════════════════════════════════════════════════════════════

class _ContactPreferenceToggle extends StatelessWidget {
  const _ContactPreferenceToggle({
    required this.allowPhoneCall,
    required this.onChanged,
  });

  final bool allowPhoneCall;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ContactOption(
          icon: Icons.chat_bubble_outline,
          label: 'In-app chat only',
          subtitle: 'Safest — donors message you within the app',
          isSelected: !allowPhoneCall,
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: 10),
        _ContactOption(
          icon: Icons.phone_outlined,
          label: 'Allow phone call',
          subtitle: 'Verified donors can call your registered number',
          isSelected: allowPhoneCall,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _ContactOption extends StatelessWidget {
  const _ContactOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primaryContainer
                    : colors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? colors.primary : colors.textMedium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.border,
                  width: 2,
                ),
                color: isSelected ? colors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Success view
// ═══════════════════════════════════════════════════════════════════════════════

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.requestId,
    this.isEditing = false,
  });

  final String requestId;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated checkmark circle
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 56,
                  color: colors.success,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                isEditing
                    ? 'Request updated successfully.'
                    : 'Your request is live.',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                isEditing
                    ? 'Your blood request changes have been saved.'
                    : 'Verified donors nearby have been notified.\nYou\'ll receive responses in your chat.',
                style: context.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'View Request',
                onPressed: () {
                  context.goNamed(
                    RouteNames.requestDetail,
                    pathParameters: {'id': requestId},
                  );
                },
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.goNamed(RouteNames.home),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
