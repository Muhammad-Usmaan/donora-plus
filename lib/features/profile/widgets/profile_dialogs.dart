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
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_dialog.dart';
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
    return AppDialog(
      title: 'City / Location',
      message: 'Shown on your profile and used to find nearby matches.',
      icon: Icons.location_city,
      iconColor: context.colors.secondary,
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        enabled: !_saving,
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: 'City',
          hintText: 'Enter your city',
          counterText: '',
          errorText: _error,
          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
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

// ── Contact support ──────────────────────────────────────────────────────────

Future<void> showContactSupportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ContactSupportDialog(),
  );
}

class _ContactSupportDialog extends StatelessWidget {
  const _ContactSupportDialog();

  static const _supportEmail = 'support@donora.app';

  Future<void> _openMailApp() async {
    final uri = Uri.parse('mailto:$_supportEmail?subject=Donora%2B%20Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
          onPressed: _openMailApp,
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
