import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_form_provider.dart';

/// Authentication screen with Log In / Sign Up segmented toggle.
///
/// Log In: email-or-phone + password + forgot-password link.
/// Sign Up: name + email + phone + password + confirm + role selector.
///
/// Inline validation errors appear below each field in Urgent accent.
/// Wired to Supabase Auth via [loginNotifierProvider] /
/// [signupNotifierProvider]. Phone OTP can be added later without
/// restructuring this widget.
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
              // ── Wordmark ──────────────────────────────────────────
              Center(
                child: Text(
                  'Donora+',
                  style: context.textTheme.displayLarge?.copyWith(
                    color: colors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _serverError = null);
    await ref.read(loginNotifierProvider.notifier).submit(
          widget.emailCtrl.text,
          widget.passwordCtrl.text,
        );
    if (!mounted) return;
    final state = ref.read(loginNotifierProvider);
    if (state.serverError != null) {
      setState(() => _serverError = state.serverError);
    }
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
              prefixIcon: Icon(Icons.alternate_email_outlined),
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
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
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
              onPressed: () {
                // TODO: Navigate to password-reset screen.
              },
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
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  String? _selectedRole; // 'seeker' | 'donor'
  String? _serverError;

  /// Whether all required fields are non-empty and a role is selected.
  bool get _formReady {
    return widget.nameCtrl.text.trim().isNotEmpty &&
        widget.emailCtrl.text.trim().isNotEmpty &&
        widget.phoneCtrl.text.trim().isNotEmpty &&
        widget.passwordCtrl.text.isNotEmpty &&
        widget.confirmCtrl.text.isNotEmpty &&
        _selectedRole != null;
  }

  void _clearServer() {
    if (_serverError != null) setState(() => _serverError = null);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) return;
    setState(() => _serverError = null);

    await ref.read(signupNotifierProvider.notifier).submit(
          email: widget.emailCtrl.text,
          password: widget.passwordCtrl.text,
          fullName: widget.nameCtrl.text,
          phone: widget.phoneCtrl.text,
          role: _selectedRole!,
        );
    if (!mounted) return;
    final state = ref.read(signupNotifierProvider);
    if (state.serverError != null) {
      setState(() => _serverError = state.serverError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLoading = ref.watch(signupNotifierProvider).isLoading;
    final stateError = ref.watch(signupNotifierProvider).serverError;
    final signupSuccess = ref.watch(signupNotifierProvider).success;
    final displayError = _serverError ?? stateError;

    // Show confirmation message after successful signup
    if (signupSuccess) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SuccessBanner(
            message: 'Account created! Check your email to confirm your account, then log in.',
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () {
                // Switch parent to login tab
                final authScreenState = context.findAncestorStateOfType<_AuthScreenState>();
                if (authScreenState != null) {
                  authScreenState.setState(() => authScreenState._mode = AuthMode.login);
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
              prefixIcon: Icon(Icons.person_outline),
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
              if (mounted) setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email_outlined),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),

          // ── Phone ───────────────────────────────────────────────
          TextFormField(
            controller: widget.phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              _clearServer();
              if (mounted) setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: Validators.phone,
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
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePw
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePw = !_obscurePw),
              ),
            ),
            validator: (v) =>
                Validators.minLength(v, 6, 'Password'),
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
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != widget.passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── Role selector ───────────────────────────────────────
          Text(
            'I am a\u2026',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  icon: Icons.search,
                  title: 'I need blood',
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
                  icon: Icons.favorite_border,
                  title: 'I want to donate',
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
          const SizedBox(height: 24),

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
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: isSelected ? color : null,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: isSelected ? color : context.colors.textMedium),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.labelLarge?.copyWith(
              color: isSelected ? color : context.colors.textMedium,
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
          Icon(Icons.error_outline, size: 20, color: colors.urgent),
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
          Icon(Icons.check_circle_outline, size: 20, color: colors.primary),
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
