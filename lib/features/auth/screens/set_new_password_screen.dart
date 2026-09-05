import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_form_provider.dart';
import 'auth_screen.dart';

/// "Set New Password" screen — Step 3 of the OTP recovery flow.
///
/// Reached after the user successfully verifies the recovery OTP.
/// The recovery session is already established by `verifyOTP`.
/// The user enters a new password + confirmation, and on success
/// the password is updated and the user is signed out for clean re-login.
///
/// Shows a success snackbar on the Login screen after redirect.
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key, required this.email});

  /// The email being reset (received via query param).
  final String email;

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

  @override
  void initState() {
    super.initState();
    // Defer reset to after mount completes — calling reset() synchronously
    // in initState can fire state-change notifications during the mount
    // phase, which destabilises GoRouter's navigation transition and
    // causes a mount-loop StackOverflowError on second+ flow entries.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(resetPasswordNotifierProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(resetPasswordNotifierProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(resetPasswordNotifierProvider.notifier)
        .submit(_passwordCtrl.text);

    if (!mounted) return;
    final state = ref.read(resetPasswordNotifierProvider);
    if (state.done) {
      // Set the flag so AuthScreen shows a success snackbar.
      AuthScreen.showResetSuccess = true;
      context.goNamed(RouteNames.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rpState = ref.watch(resetPasswordNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.goNamed(RouteNames.auth),
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

              // ── Error ────────────────────────────────────────────
              if (rpState.error != null) ...[
                _ErrorBanner(message: rpState.error!),
                const SizedBox(height: 16),
              ],

              // ── Form ─────────────────────────────────────────────
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
                        ref.read(resetPasswordNotifierProvider.notifier).clearError();
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
                        ref.read(resetPasswordNotifierProvider.notifier).clearError();
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
                isLoading: rpState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inline feedback banner (same pattern as auth_screen.dart) ─────────────

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
