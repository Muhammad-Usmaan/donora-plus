import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/otp_input_widget.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_form_provider.dart';

/// "Verify Reset Code" screen — Step 2 of the OTP recovery flow.
///
/// Displays a 6-digit OTP input. On successful verification, Supabase
/// creates a temporary session and the user is navigated to the
/// Reset Password screen.
///
/// Includes a "Resend code" button with a 30-second cooldown.
class VerifyResetCodeScreen extends ConsumerStatefulWidget {
  const VerifyResetCodeScreen({super.key, required this.email});

  /// The email address the OTP was sent to (received via query param).
  final String email;

  @override
  ConsumerState<VerifyResetCodeScreen> createState() =>
      _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends ConsumerState<VerifyResetCodeScreen> {
  String _code = '';
  bool _navigated = false;
  /// Guard that prevents build() from acting on stale notifier state
  /// before the deferred reset() has actually executed.
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // Defer reset to after mount completes — calling reset() synchronously
    // in initState can fire state-change notifications during the mount
    // phase, which destabilises GoRouter's navigation transition and
    // causes a mount-loop StackOverflowError on second+ flow entries.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(verifyResetCodeNotifierProvider.notifier).reset();
        // Start cooldown timer since a code was just sent.
        ref.read(verifyResetCodeNotifierProvider.notifier).startCooldown();
        // Only now is it safe for build() to evaluate vState.verified.
        setState(() => _isReady = true);
      }
    });
  }

  void _verify() {
    if (_code.length != 6) return;
    ref
        .read(verifyResetCodeNotifierProvider.notifier)
        .verify(widget.email, _code);
  }

  void _resend() {
    ref
        .read(verifyResetCodeNotifierProvider.notifier)
        .resend(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vState = ref.watch(verifyResetCodeNotifierProvider);

    // One-time navigation after successful OTP verification.
    // `_isReady` ensures we never act on stale `verified: true` left over
    // from a previous flow before reset() has actually run (post-frame).
    // `_navigated` guard prevents re-entry if build() runs again after
    // navigation is scheduled.
    if (_isReady && vState.verified && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.goNamed(
            RouteNames.resetPassword,
            queryParameters: {'email': widget.email},
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.goNamed(RouteNames.forgotPassword),
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
                'Enter verification code',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n${widget.email}',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.textMedium,
                ),
              ),
              const SizedBox(height: 32),

              // ── Error ────────────────────────────────────────────
              if (vState.error != null) ...[
                _ErrorBanner(message: vState.error!),
                const SizedBox(height: 16),
              ],

              // ── Resend success message ───────────────────────────
              if (vState.resendMessage != null) ...[
                _SuccessBanner(message: vState.resendMessage!),
                const SizedBox(height: 16),
              ],

              // ── OTP Input ────────────────────────────────────────
              OtpInputWidget(
                length: 6,
                onChanged: (code) {
                  setState(() => _code = code);
                  if (vState.error != null) {
                    ref.read(verifyResetCodeNotifierProvider.notifier).clearError();
                  }
                },
                onCompleted: _verify,
              ),
              const SizedBox(height: 24),

              // ── Verify button ────────────────────────────────────
              PrimaryButton(
                label: 'Verify Code',
                isLoading: vState.isLoading,
                onPressed: _code.length == 6 ? _verify : null,
              ),
              const SizedBox(height: 16),

              // ── Resend ───────────────────────────────────────────
              Center(
                child: vState.cooldownSeconds > 0
                    ? Text(
                        'Resend code in ${vState.cooldownSeconds}s',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colors.textMedium,
                        ),
                      )
                    : TextButton(
                        onPressed: vState.isLoading ? null : _resend,
                        child: Text(
                          'Resend code',
                          style: context.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // ── Back ─────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => context.goNamed(RouteNames.forgotPassword),
                  child: Text(
                    'Change email',
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

// ── Inline feedback banners ──────────────────────────────────────────────────

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
