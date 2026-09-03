import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/deep_link_handler.dart';

/// "Set New Password" screen — reached via deep link after the user taps
/// the password-reset link in their email.
///
/// The recovery session is already established by `supabase_flutter` when
/// this screen opens. The user enters a new password + confirmation,
/// and on success the password is updated via [SupabaseAuthService.updatePassword].
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .updatePassword(_passwordCtrl.text);

      // Password updated — sign out the recovery session so the user
      // returns to the login screen with their new credentials.
      await ref.read(authServiceProvider).signOut();
      DeepLinkHandler.clearRecoveryFlag();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _friendlyError(e);
      });
    }
  }

  /// Converts common auth exceptions into user-friendly messages.
  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('password') && s.contains('weak')) {
      return 'Password is too weak. Please choose a stronger password (at least 6 characters).';
    }
    if (s.contains('expired') || s.contains('invalid')) {
      return 'This reset link has expired or is invalid. Please request a new one.';
    }
    if (e.isNetworkError) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft),
          onPressed: () {
            DeepLinkHandler.clearRecoveryFlag();
            context.goNamed(RouteNames.auth);
          },
        ),
      ),
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
              const SizedBox(height: 24),

              // ── Heading ──────────────────────────────────────────
              Text(
                'Set new password',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your new password below.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.textMedium,
                ),
              ),
              const SizedBox(height: 32),

              // ── Success state ────────────────────────────────────
              if (_done) ...[
                const _SuccessBanner(
                  message: 'Password updated successfully!',
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue to Log In',
                  onPressed: () => context.goNamed(RouteNames.auth),
                ),
              ]

              // ── Form state ───────────────────────────────────────
              else ...[
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── New password ──────────────────────────────
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePw,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const PhosphorIcon(
                            PhosphorIconsRegular.lockSimple,
                          ),
                          suffixIcon: IconButton(
                            icon: PhosphorIcon(
                              _obscurePw
                                  ? PhosphorIconsRegular.eye
                                  : PhosphorIconsRegular.eyeClosed,
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

                      // ── Confirm password ──────────────────────────
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: const PhosphorIcon(
                            PhosphorIconsRegular.lockSimple,
                          ),
                          suffixIcon: IconButton(
                            icon: PhosphorIcon(
                              _obscureConfirm
                                  ? PhosphorIconsRegular.eye
                                  : PhosphorIconsRegular.eyeClosed,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) =>
                            Validators.confirmPassword(v, _passwordCtrl.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                PrimaryButton(
                  label: 'Update Password',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inline feedback banners (same pattern as auth_screen.dart) ─────────────

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
