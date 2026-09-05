import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_form_provider.dart';

/// "Forgot Password" screen — Step 1 of the OTP recovery flow.
///
/// User enters their email → taps "Send Code" → calls
/// `supabase.auth.resetPasswordForEmail(email)` → on success navigates
/// to the Verify Reset Code screen, passing the email as a query param.
///
/// Layout mirrors the auth screen (logo, centered column, same padding).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Defer reset to after mount completes — calling reset() synchronously
    // in initState can fire state-change notifications during the mount
    // phase, which destabilises GoRouter's navigation transition and
    // causes a mount-loop StackOverflowError on second+ flow entries.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(forgotPasswordNotifierProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(forgotPasswordNotifierProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(forgotPasswordNotifierProvider.notifier)
        .submit(_emailCtrl.text);

    if (!mounted) return;
    final state = ref.read(forgotPasswordNotifierProvider);
    if (state.success) {
      context.goNamed(
        RouteNames.verifyResetCode,
        queryParameters: {'email': _emailCtrl.text.trim()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fpState = ref.watch(forgotPasswordNotifierProvider);

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
                'Forgot password?',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your email address and we\'ll send you a code to reset your password.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.textMedium,
                ),
              ),
              const SizedBox(height: 32),

              // ── Error ────────────────────────────────────────────
              if (fpState.error != null) ...[
                _ErrorBanner(message: fpState.error!),
                const SizedBox(height: 16),
              ],

              // ── Form ─────────────────────────────────────────────
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    ref.read(forgotPasswordNotifierProvider.notifier).clearError();
                  },
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: PhosphorIcon(
                      PhosphorIconsRegular.envelopeSimple,
                    ),
                  ),
                  validator: Validators.email,
                ),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: 'Send Code',
                isLoading: fpState.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => context.goNamed(RouteNames.auth),
                  child: Text(
                    'Back to Log In',
                    style: context.textTheme.labelLarge?.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                ),
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
