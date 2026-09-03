import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/location/location_service.dart';
import '../../../services/providers.dart';
import '../providers/auth_form_provider.dart';

/// Authentication screen with Log In / Sign Up segmented toggle.
///
/// Log In: email-or-phone + password + forgot-password link.
/// Sign Up: name + email + phone + password + confirm + blood type + location + role + donor classification.
///
/// Inline validation errors appear below each field in Urgent accent.
/// Wired to Supabase Auth via [loginNotifierProvider] / [signupNotifierProvider].
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, signup }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthMode _mode = AuthMode.login;

  // ── Login controllers ───────────────────────────────────────────────
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // ── Signup controllers ──────────────────────────────────────────────
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupConfirmCtrl = TextEditingController();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Logo ─────────────────────────────────────────────
              Center(
                child: Image.asset(
                  'assets/images/logo/Donora+ Transparent.png',
                  height: 48,
                ),
              ),
              const SizedBox(height: 32),

              // ── Segmented toggle ─────────────────────────────────
              _SegmentedControl(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 24),

              // ── Form ──────────────────────────────────────────────
              if (_mode == AuthMode.login)
                _LoginForm(
                  emailCtrl: _loginEmailCtrl,
                  passwordCtrl: _loginPasswordCtrl,
                )
              else
                _SignupForm(
                  nameCtrl: _signupNameCtrl,
                  emailCtrl: _signupEmailCtrl,
                  phoneCtrl: _signupPhoneCtrl,
                  passwordCtrl: _signupPasswordCtrl,
                  confirmCtrl: _signupConfirmCtrl,
                ),

              const SizedBox(height: 24),

              // ── Terms ─────────────────────────────────────────────
              Center(
                child: Text(
                  'By continuing you agree to our Terms and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Segmented control
// ═══════════════════════════════════════════════════════════════════════════════

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          _buildSegment(context, 'Log In', AuthMode.login),
          _buildSegment(context, 'Sign Up', AuthMode.signup),
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, String label, AuthMode value) {
    final isActive = mode == value;
    final colors = context.colors;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: isActive ? colors.primary : colors.textMedium,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Login form
// ═══════════════════════════════════════════════════════════════════════════════

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({required this.emailCtrl, required this.passwordCtrl});

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _serverError;

  void _clearServer() {
    if (_serverError != null) setState(() => _serverError = null);
  }

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _serverError = null;
      _isSubmitting = true;
    });
    await ref
        .read(loginNotifierProvider.notifier)
        .submit(widget.emailCtrl.text, widget.passwordCtrl.text);
    if (!mounted) return;
    final state = ref.read(loginNotifierProvider);
    setState(() {
      _serverError = state.serverError;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLoading = ref.watch(loginNotifierProvider).isLoading;
    final stateError = ref.watch(loginNotifierProvider).serverError;
    final displayError = _serverError ?? stateError;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (displayError != null) ...[
            _ErrorBanner(message: displayError),
            const SizedBox(height: 16),
          ],

          // ── Email or phone ──────────────────────────────────────
          TextFormField(
            controller: widget.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearServer(),
            decoration: const InputDecoration(
              labelText: 'Email or phone',
              prefixIcon: PhosphorIcon(PhosphorIconsRegular.at),
            ),
            validator: (v) {
              final req = Validators.required(v, 'Email or phone');
              return req;
            },
          ),
          const SizedBox(height: 16),

          // ── Password ────────────────────────────────────────────
          TextFormField(
            controller: widget.passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearServer(),
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const PhosphorIcon(PhosphorIconsRegular.lockSimple),
              suffixIcon: IconButton(
                icon: PhosphorIcon(
                  _obscurePassword
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeClosed,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => Validators.required(v, 'Password'),
          ),
          const SizedBox(height: 24),

          // ── Submit ──────────────────────────────────────────────
          PrimaryButton(
            label: 'Log In',
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),

          // ── Forgot password ─────────────────────────────────────
          Center(
            child: TextButton(
              onPressed: () => context.goNamed(RouteNames.forgotPassword),
              child: Text(
                'Forgot password?',
                style: context.textTheme.labelLarge?.copyWith(
                  color: colors.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Signup form
// ═══════════════════════════════════════════════════════════════════════════════

class _SignupForm extends ConsumerStatefulWidget {
  const _SignupForm({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;

  @override
  ConsumerState<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<_SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneFocusNode = FocusNode();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  DateTime? _selectedBirthdate;
  final _birthdateCtrl = TextEditingController();

  // ── Location & Blood group ──────────────────────────────────────────
  final _cityCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  String? _selectedBloodGroup;

  // ── Role & Donor Classification ─────────────────────────────────────
  String? _selectedRole; // 'seeker' | 'donor'
  String? _donorClassification; // 'volunteer' | 'compensated'

  String? _serverError;
  String? _phoneError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    _birthdateCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _onPhoneFocusChange() {
    if (!_phoneFocusNode.hasFocus) {
      _checkPhoneUniqueness();
    }
  }

  /// Normalises raw phone input to Pakistan +92 format.
  String _getNormalisedPhone(String raw) {
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+92${digits.substring(1)}';
    } else if (digits.length == 12 && digits.startsWith('92')) {
      return '+$digits';
    } else if (digits.length == 13 && digits.startsWith('0092')) {
      return '+${digits.substring(2)}';
    } else if (digits.length == 10) {
      return '+92$digits';
    }
    return raw.trim();
  }

  Future<void> _checkPhoneUniqueness() async {
    final raw = widget.phoneCtrl.text.trim();
    if (raw.isEmpty) return;
    final valErr = Validators.phone(raw);
    if (valErr != null) return;

    final norm = _getNormalisedPhone(raw);
    try {
      final isTaken = await ref
          .read(authServiceProvider)
          .isPhoneRegistered(norm);
      if (!mounted) return;
      if (isTaken) {
        setState(() {
          _phoneError =
              'This phone number is already registered with another account.';
        });
      } else if (_phoneError != null) {
        setState(() => _phoneError = null);
      }
    } catch (_) {
      // Best-effort check on blur; strict check happens on submit
    }
  }

  /// Whether all required fields are non-empty, location & blood type set, and valid role selected.
  bool get _formReady {
    final hasBasic =
        widget.nameCtrl.text.trim().isNotEmpty &&
        widget.emailCtrl.text.trim().isNotEmpty &&
        widget.phoneCtrl.text.trim().isNotEmpty &&
        _phoneError == null &&
        _selectedBirthdate != null &&
        _selectedBloodGroup != null &&
        _cityCtrl.text.trim().isNotEmpty &&
        widget.passwordCtrl.text.isNotEmpty &&
        widget.confirmCtrl.text.isNotEmpty &&
        _selectedRole != null;

    if (!hasBasic) return false;
    if (_selectedRole == 'donor' && _donorClassification == null) return false;
    return true;
  }

  void _clearServer() {
    if (_serverError != null) setState(() => _serverError = null);
  }

  /// Builds the inline email-already-registered error widget with a
  /// tappable "Log in" link that switches to the login tab and pre-fills
  /// the email field.
  Widget _buildEmailErrorInline() {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'This email is already registered. ',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.urgent,
              ),
            ),
            TextSpan(
              text: 'Log in',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Switch to login tab and pre-fill the email.
                  final authScreenState =
                      context.findAncestorStateOfType<_AuthScreenState>();
                  if (authScreenState != null) {
                    authScreenState.setState(() {
                      authScreenState._mode = AuthMode.login;
                      authScreenState._loginEmailCtrl.text =
                          widget.emailCtrl.text.trim();
                    });
                  }
                },
            ),
            TextSpan(
              text: ' instead, or reset your password if you forgot it.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.urgent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthdate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initialDate =
        _selectedBirthdate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        _selectedBirthdate = picked;
        _birthdateCtrl.text = Formatters.dateShort(picked);
        _clearServer();
      });
    }
  }

  // ── Location flows ──────────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLocating = true;
      _clearServer();
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final pos = await locationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not access location. Please check permissions.',
              ),
            ),
          );
        }
        return;
      }

      if (!LocationService.isInPakistan(pos.latitude, pos.longitude)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location is outside Pakistan. Please select your city manually.',
              ),
            ),
          );
        }
        return;
      }

      final resolvedCity = await locationService.resolveCity(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        if (resolvedCity != null && resolvedCity.isNotEmpty) {
          _cityCtrl.text = resolvedCity;
        } else {
          _cityCtrl.text =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickFromMap() async {
    FocusScope.of(context).unfocus();
    _clearServer();
    final result = await context.pushNamed<(LatLng, String?)>(
      RouteNames.locationPicker,
    );
    if (result != null && mounted) {
      final (position, address) = result;
      final city =
          address?.split(',').first.trim() ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _cityCtrl.text = city;
      });
    }
  }

  // ── Donor Classification Modal Dialog ───────────────────────────────

  void _showClassificationInfo(BuildContext context, String type) {
    if (type == 'volunteer') {
      showAppDialog(
        context: context,
        title: 'Volunteer Donor',
        icon: PhosphorIconsRegular.heart,
        iconColor: context.colors.primary,
        message:
            'Purely voluntary, non-remunerated donation.\n\nYou donate solely out of altruism to save lives without receiving any financial payment or reimbursement. Aligned with World Health Organization (WHO) standards for safe and ethical blood donation.',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    } else {
      showAppDialog(
        context: context,
        title: 'Compensated (Travel & Time)',
        icon: PhosphorIconsRegular.currencyCircleDollar,
        iconColor: context.colors.secondary,
        message:
            'Reimbursement for travel, transport, and time expenses.\n\nThis option provides reimbursement strictly for direct, verified travel and time expenses incurred during the donation process. In accordance with WHO guidelines, this is NOT payment for the blood itself.',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    }
  }

  // ── Form Submission ─────────────────────────────────────────────────

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null ||
        _selectedBirthdate == null ||
        _selectedBloodGroup == null ||
        _cityCtrl.text.trim().isEmpty) {
      return;
    }
    if (_selectedRole == 'donor' && _donorClassification == null) {
      setState(() => _serverError = 'Please select a donor classification.');
      return;
    }
    // Age gate: donors must be 18 or older.
    if (_selectedRole == 'donor' && _selectedBirthdate != null) {
      final age = _computeAge(_selectedBirthdate!);
      if (age < 18) {
        setState(() => _serverError = 'You must be 18 or older to register as a donor.');
        return;
      }
    }

    setState(() {
      _serverError = null;
      _phoneError = null;
      _isSubmitting = true;
    });

    final normalisedPhone = _getNormalisedPhone(widget.phoneCtrl.text);

    // Pre-check phone uniqueness to show clear inline error
    final isRegistered = await ref
        .read(authServiceProvider)
        .isPhoneRegistered(normalisedPhone);
    if (isRegistered) {
      if (!mounted) return;
      setState(() {
        _phoneError =
            'This phone number is already registered with another account.';
        _isSubmitting = false;
      });
      return;
    }

    // Default coordinates from city lookup if GPS was not used
    var lat = _latitude;
    var lng = _longitude;
    if (lat == null || lng == null) {
      final cityKey = _cityCtrl.text.trim().toLowerCase();
      final coords = AppConstants.cityCoords[cityKey];
      if (coords != null) {
        lat = coords.lat;
        lng = coords.lng;
      }
    }

    await ref
        .read(signupNotifierProvider.notifier)
        .submit(
          email: widget.emailCtrl.text,
          password: widget.passwordCtrl.text,
          fullName: widget.nameCtrl.text,
          phone: widget.phoneCtrl.text,
          birthdate: _selectedBirthdate!,
          role: _selectedRole!,
          bloodGroup: _selectedBloodGroup!,
          city: _cityCtrl.text.trim(),
          latitude: lat,
          longitude: lng,
          donorClassification: _selectedRole == 'donor'
              ? _donorClassification
              : null,
        );
    if (!mounted) return;
    final state = ref.read(signupNotifierProvider);
    setState(() {
      _emailError = null;
      _phoneError = null;
      _serverError = state.serverError;

      // Route field-specific errors to inline error text.
      if (state.serverError != null) {
        if (state.serverError!.contains('email is already registered')) {
          _emailError = state.serverError;
        } else if (state.serverError!.contains('phone number is already registered')) {
          _phoneError = state.serverError;
        }
      }
      _isSubmitting = false;
    });
  }

  /// Returns the age in whole years for a given [date].
  int _computeAge(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLoading =
        ref.watch(signupNotifierProvider).isLoading || _isSubmitting;
    final stateError = ref.watch(signupNotifierProvider).serverError;
    final signupSuccess = ref.watch(signupNotifierProvider).success;
    final rawError = _serverError ?? stateError;
    // Suppress the top banner for field-specific errors (shown inline).
    final isFieldError = rawError != null &&
        (rawError.contains('email is already registered') ||
            rawError.contains('phone number is already registered'));
    final displayError = isFieldError ? null : rawError;

    // Show confirmation message after successful signup
    if (signupSuccess) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SuccessBanner(
            message:
                'Account created! Check your email to confirm your account, then log in.',
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () {
                final authScreenState = context
                    .findAncestorStateOfType<_AuthScreenState>();
                if (authScreenState != null) {
                  authScreenState.setState(
                    () => authScreenState._mode = AuthMode.login,
                  );
                }
              },
              child: Text(
                'Go to Log In',
                style: context.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (displayError != null) ...[
            _ErrorBanner(message: displayError),
            const SizedBox(height: 16),
          ],

          // ── Full name ───────────────────────────────────────────
          TextFormField(
            controller: widget.nameCtrl,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              _clearServer();
              if (mounted) setState(() {}); // refresh _formReady
            },
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: PhosphorIcon(PhosphorIconsRegular.user),
            ),
            validator: (v) => Validators.required(v, 'Full name'),
          ),
          const SizedBox(height: 16),

          // ── Email ───────────────────────────────────────────────
          TextFormField(
            controller: widget.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              _clearServer();
              if (_emailError != null) setState(() => _emailError = null);
              if (mounted) setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const PhosphorIcon(PhosphorIconsRegular.envelopeSimple),
              // Red border when email-already-registered error is active.
              enabledBorder: _emailError != null
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: colors.urgent),
                    )
                  : null,
            ),
            validator: Validators.email,
          ),
          if (_emailError != null) ...[
            const SizedBox(height: 4),
            _buildEmailErrorInline(),
          ],
          const SizedBox(height: 16),

          // ── Phone ───────────────────────────────────────────────
          TextFormField(
            controller: widget.phoneCtrl,
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              _clearServer();
              if (_phoneError != null) setState(() => _phoneError = null);
              if (mounted) setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Phone number (e.g. 03001234567)',
              prefixIcon: const PhosphorIcon(PhosphorIconsRegular.phone),
              errorText: _phoneError,
            ),
            validator: (v) {
              final err = Validators.phone(v);
              if (err != null) return err;
              if (_phoneError != null) return _phoneError;
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Birthdate ───────────────────────────────────────────
          TextFormField(
            controller: _birthdateCtrl,
            readOnly: true,
            onTap: _pickBirthdate,
            decoration: InputDecoration(
              labelText: 'Date of birth',
              prefixIcon: const PhosphorIcon(
                PhosphorIconsRegular.calendarBlank,
              ),
              suffixIcon: IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.calendarBlank,
                  size: 20,
                ),
                onPressed: _pickBirthdate,
              ),
            ),
            validator: (v) {
              if (_selectedBirthdate == null) {
                return 'Please select your date of birth';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Blood Type Dropdown ──────────────────────────────────
          DropdownButtonFormField<String>(
            value: _selectedBloodGroup,
            decoration: const InputDecoration(
              labelText: 'Blood type',
              prefixIcon: PhosphorIcon(PhosphorIconsRegular.drop),
            ),
            items: AppConstants.bloodTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedBloodGroup = val;
                _clearServer();
              });
            },
            validator: (v) => Validators.bloodType(v),
          ),
          const SizedBox(height: 16),

          // ── Location & City ─────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _cityCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  _clearServer();
                  // Reset pinned coordinates if user edits text manually
                  _latitude = null;
                  _longitude = null;
                  if (mounted) setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'City / Location',
                  prefixIcon: const PhosphorIcon(PhosphorIconsRegular.mapPin),
                  suffixIcon: _isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                validator: (v) => Validators.required(v, 'Location'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLocating ? null : _useCurrentLocation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.navigationArrow,
                        size: 16,
                      ),
                      label: const Text(
                        'Use GPS',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromMap,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.mapPin,
                        size: 16,
                      ),
                      label: const Text(
                        'Pick on Map',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Password ────────────────────────────────────────────
          TextFormField(
            controller: widget.passwordCtrl,
            obscureText: _obscurePw,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              _clearServer();
              if (mounted) setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const PhosphorIcon(PhosphorIconsRegular.lockSimple),
              suffixIcon: IconButton(
                icon: PhosphorIcon(
                  _obscurePw
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeClosed,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
              ),
            ),
            validator: (v) => Validators.minLength(v, 6, 'Password'),
          ),
          const SizedBox(height: 16),

          // ── Confirm password ────────────────────────────────────
          TextFormField(
            controller: widget.confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              _clearServer();
              if (mounted) setState(() {});
            },
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const PhosphorIcon(PhosphorIconsRegular.lockSimple),
              suffixIcon: IconButton(
                icon: PhosphorIcon(
                  _obscureConfirm
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeClosed,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != widget.passwordCtrl.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── Role selector ───────────────────────────────────────
          Text('I am joining as\u2026', style: context.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  icon: PhosphorIconsRegular.magnifyingGlass,
                  title: 'I need blood',
                  subtitle: 'Seeker',
                  isSelected: _selectedRole == 'seeker',
                  color: colors.urgent,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _selectedRole = 'seeker');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  icon: PhosphorIconsRegular.heart,
                  title: 'I want to donate',
                  subtitle: 'Donor',
                  isSelected: _selectedRole == 'donor',
                  color: colors.secondary,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _selectedRole = 'donor');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'You can switch roles anytime after signup.',
              style: context.textTheme.bodySmall,
            ),
          ),

          // ── Donor Classification step (Visible ONLY when role == 'donor') ──
          if (_selectedRole == 'donor') ...[
            const SizedBox(height: 24),
            Text('Donor Classification', style: context.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Select your donation preference (WHO-aligned):',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textMedium,
              ),
            ),
            const SizedBox(height: 12),
            _ClassificationCard(
              title: 'Volunteer',
              description: 'No reimbursement, purely voluntary donation',
              icon: PhosphorIconsRegular.heartStraight,
              isSelected: _donorClassification == 'volunteer',
              color: colors.primary,
              onTap: () {
                setState(() => _donorClassification = 'volunteer');
              },
              onInfoTap: () => _showClassificationInfo(context, 'volunteer'),
            ),
            const SizedBox(height: 10),
            _ClassificationCard(
              title: 'Compensated',
              description:
                  'Reimbursed for travel/time (not payment for blood itself)',
              icon: PhosphorIconsRegular.currencyCircleDollar,
              isSelected: _donorClassification == 'compensated',
              color: colors.secondary,
              onTap: () {
                setState(() => _donorClassification = 'compensated');
              },
              onInfoTap: () => _showClassificationInfo(context, 'compensated'),
            ),
          ],

          const SizedBox(height: 28),

          // ── Submit ──────────────────────────────────────────────
          _formReady
              ? PrimaryButton(
                  label: 'Create Account',
                  isLoading: isLoading,
                  onPressed: _submit,
                )
              : const PrimaryButton(
                  label: 'Create Account',
                  onPressed: null, // disabled / greyed
                ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Role card
// ═══════════════════════════════════════════════════════════════════════════════

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: isSelected ? color : null,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 30,
            color: isSelected ? color : context.colors.textMedium,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.labelLarge?.copyWith(
              color: isSelected ? color : context.colors.textMedium,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? color.withValues(alpha: 0.8)
                    : context.colors.textMedium,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Classification card (Volunteer / Compensated)
// ═══════════════════════════════════════════════════════════════════════════════

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    required this.onInfoTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      borderColor: isSelected ? color : null,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSelected ? color : colors.textMedium).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? color : colors.textMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: isSelected ? color : colors.textHigh,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.info,
                        size: 18,
                        color: colors.textMedium,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Learn more',
                      onPressed: onInfoTap,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textMedium,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Error banner
// ═══════════════════════════════════════════════════════════════════════════════

/// Inline error banner for server-side auth failures.
/// Uses Urgent accent color — consistent with the design system.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.urgent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.urgent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.warning,
            size: 20,
            color: colors.urgent,
          ),
          const SizedBox(width: 12),
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

/// Success banner for signup confirmation.
/// Uses primary color to indicate positive outcome.
class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.checkCircle,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
