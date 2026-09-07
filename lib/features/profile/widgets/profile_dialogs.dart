/// Form dialogs for the Profile screen.
///
/// Each dialog:
/// - uses the shared [AppDialog] shell (icon header, consistent typography),
/// - validates inline before saving,
/// - shows a busy state on the confirm button while the request runs,
/// - reports success/failure through snackbars via [BuildContextX.showSnackBar].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../services/location/location_service.dart';
import '../../../services/providers.dart';
import '../../home/providers/home_providers.dart' show normalizePhone;
import '../providers/profile_providers.dart';

// ── Edit name ────────────────────────────────────────────────────────────────

Future<void> showEditNameDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String currentName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EditNameDialog(currentName: currentName, ref: ref),
  );
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.currentName, required this.ref});

  final String currentName;
  final WidgetRef ref;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.ref.read(updateProfileFieldProvider)({'name': name});
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnackBar('Name updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar('Update failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Edit Name',
      message: 'This is how other Donora+ members will see you.',
      icon: Icons.person_outline,
      iconColor: context.colors.primary,
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        enabled: !_saving,
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: 'Full Name',
          hintText: 'Enter your name',
          counterText: '',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        DialogActionButton(
          label: 'Save',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Change password ──────────────────────────────────────────────────────────

Future<void> showChangePasswordDialog(
  BuildContext context, {
  required WidgetRef ref,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChangePasswordDialog(ref: ref),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPw = _newPwCtrl.text;
    final confirmPw = _confirmPwCtrl.text;

    if (newPw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.ref
          .read(changePasswordActionProvider)(newPw, confirmPw);
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnackBar('Password updated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar('$e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Change Password',
      icon: Icons.lock_outline,
      iconColor: context.colors.secondary,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newPwCtrl,
            obscureText: _obscureNew,
            enabled: !_saving,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'New Password',
              hintText: 'Minimum 6 characters',
              errorText: _error != null && _newPwCtrl.text.length < 6
                  ? _error
                  : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPwCtrl,
            obscureText: _obscureConfirm,
            enabled: !_saving,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              errorText: _error != null &&
                      _newPwCtrl.text.length >= 6 &&
                      _newPwCtrl.text != _confirmPwCtrl.text
                  ? _error
                  : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        DialogActionButton(
          label: 'Update',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── City ─────────────────────────────────────────────────────────────────────

Future<void> showCityDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String currentCity,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CityDialog(ref: ref, currentCity: currentCity),
  );
}

class _CityDialog extends StatefulWidget {
  const _CityDialog({required this.ref, required this.currentCity});

  final WidgetRef ref;
  final String currentCity;

  @override
  State<_CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<_CityDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentCity);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      final locationService = widget.ref.read(locationServiceProvider);
      final pos = await locationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          setState(() => _error = 'Could not access location. Please check permissions.');
        }
        return;
      }

      if (!LocationService.isInPakistan(pos.latitude, pos.longitude)) {
        if (mounted) {
          setState(() => _error = 'Location is outside Pakistan.');
        }
        return;
      }

      final city = await locationService.resolveCity(pos.latitude, pos.longitude);
      if (mounted) {
        if (city != null && city.isNotEmpty) {
          _controller.text = city;
        } else {
          final addr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _controller.text = addr;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Location error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _pickFromMap() async {
    final result = await context.pushNamed<(LatLng, String?)>(
      RouteNames.locationPicker,
    );
    if (result != null && mounted) {
      final (position, address) = result;
      final city = address?.split(',').first.trim() ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      _controller.text = city;
    }
  }

  Future<void> _save() async {
    final city = _controller.text.trim();
    if (city.isNotEmpty && city.length < 2) {
      setState(() => _error = 'City name is too short.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.ref.read(updateProfileFieldProvider)({'city': city});
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnackBar('City updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar('Update failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialog(
      title: 'City / Location',
      message: 'Shown on your profile and used to find nearby matches.',
      icon: Icons.location_city,
      iconColor: colors.secondary,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            enabled: !_saving && !_locating,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'City',
              hintText: 'Enter your city',
              counterText: '',
              errorText: _error,
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_saving || _locating) ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(
                    _locating ? 'Locating...' : 'Current Location',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_saving || _locating) ? null : _pickFromMap,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text(
                    'Pick on Map',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: (_saving || _locating) ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        DialogActionButton(
          label: 'Save',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Contact support ──────────────────────────────────────────────────────────

Future<void> showContactSupportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ContactSupportDialog(),
  );
}

class _ContactSupportDialog extends StatelessWidget {
  const _ContactSupportDialog();

  static const _supportEmail = 'donoraplus@gmail.com';

  Future<void> _openMailApp(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('Donora+ Support')}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          context.showSnackBar(
            'No mail app found. You can copy the email address above.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          'Could not open mail app: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialog(
      title: 'Contact Support',
      message: 'We usually reply within 24 hours.',
      icon: Icons.support_agent,
      iconColor: colors.secondary,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline, size: 20, color: colors.secondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: SelectableText(
                    _supportEmail,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Copy button
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: _supportEmail),
                    );
                    context.showSnackBar('Email copied to clipboard');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 18, color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        DialogActionButton(
          label: 'Open Mail App',
          onPressed: () => _openMailApp(context),
        ),
      ],
    );
  }
}

// ── Edit phone ──────────────────────────────────────────────────────────────

Future<void> showEditPhoneDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String? currentPhone,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EditPhoneDialog(
      ref: ref,
      currentPhone: currentPhone ?? '',
    ),
  );
}

class _EditPhoneDialog extends StatefulWidget {
  const _EditPhoneDialog({required this.ref, required this.currentPhone});

  final WidgetRef ref;
  final String currentPhone;

  @override
  State<_EditPhoneDialog> createState() => _EditPhoneDialogState();
}

class _EditPhoneDialogState extends State<_EditPhoneDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPhone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    // Empty clears the number; otherwise normalise to +92XXXXXXXXXX.
    final phone = raw.isEmpty ? '' : normalizePhone(raw);
    if (raw.isNotEmpty && phone == null) {
      setState(
          () => _error = 'Invalid phone format. Use +92XXXXXXXXXX.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.ref.read(updateProfileFieldProvider)({'phone': phone});
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnackBar('Phone number updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar('Update failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Phone Number',
      message: 'Donors and seekers reach each other on this number '
          '— keep it current.',
      icon: Icons.phone_outlined,
      iconColor: context.colors.secondary,
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_saving,
        keyboardType: TextInputType.phone,
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: 'Phone Number',
          hintText: '03001234567',
          errorText: _error,
          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        DialogActionButton(
          label: 'Save',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Edit hemoglobin level ───────────────────────────────────────────────────

Future<void> showEditHemoglobinDialog(
  BuildContext context, {
  required WidgetRef ref,
  required double? currentValue,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _EditHemoglobinDialog(ref: ref, currentValue: currentValue),
  );
}

class _EditHemoglobinDialog extends StatefulWidget {
  const _EditHemoglobinDialog({
    required this.ref,
    required this.currentValue,
  });

  final WidgetRef ref;
  final double? currentValue;

  @override
  State<_EditHemoglobinDialog> createState() => _EditHemoglobinDialogState();
}

class _EditHemoglobinDialogState extends State<_EditHemoglobinDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentValue?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    double? value;
    if (text.isNotEmpty) {
      value = double.tryParse(text);
      if (value == null) {
        setState(() => _error = 'Please enter a valid number.');
        return;
      }
      if (value < 5.0 || value > 20.0) {
        setState(
          () => _error = 'Value must be between 5.0 and 20.0 g/dL.',
        );
        return;
      }
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.ref.read(updateProfileFieldProvider)({
        'hemoglobin_level': value,
      });
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnackBar('Hemoglobin level updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar('Update failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Hemoglobin Level',
      message: 'Self-reported hemoglobin level in g/dL. '
          'This is visible to seekers on your donor profile.',
      icon: Icons.bloodtype,
      iconColor: context.colors.primary,
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: 'Hemoglobin (g/dL)',
          hintText: 'e.g. 14.0',
          errorText: _error,
          prefixIcon: const Icon(Icons.bloodtype, size: 20),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        DialogActionButton(
          label: 'Save',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ── Edit donation goal (bottom sheet) ────────────────────────────────────────

/// Shows the donation goal edit bottom sheet.
///
/// Reused by both the Donation Overview screen and the post-achievement
/// goal nudge. Pre-fills with [currentGoal] if set; leave blank to clear.
///
/// [headerText] overrides the subtitle for contextual framing (e.g. the
/// achievement nudge shows "Ready for your next goal?" instead of the
/// default "How many donations would you like to reach?").
Future<void> showGoalEditSheet(
  BuildContext context, {
  required WidgetRef ref,
  required int? currentGoal,
  String? headerText,
}) {
  final colors = context.colors;
  final controller = TextEditingController(
    text: currentGoal?.toString() ?? '',
  );

  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Set Donation Goal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headerText ??
                        'How many donations would you like to reach?',
                    style:
                        TextStyle(fontSize: 13, color: colors.textMedium),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: 'e.g. 15'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) {
                          Navigator.of(ctx).pop();
                          return;
                        }
                        final goal = int.tryParse(text);
                        if (goal == null || goal <= 0) {
                          context.showSnackBar(
                            'Enter a positive number',
                            isError: true,
                          );
                          return;
                        }
                        Navigator.of(ctx).pop();
                        try {
                          await ref.read(updateProfileFieldProvider)({
                            'donation_goal': goal,
                          });
                          if (context.mounted) {
                            context.showSnackBar(
                              'Donation goal updated to $goal',
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            context.showSnackBar(
                              'Update failed: $e',
                              isError: true,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Goal'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
