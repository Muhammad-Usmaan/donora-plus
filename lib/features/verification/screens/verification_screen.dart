import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../providers/verification_provider.dart';

/// Donor verification flow — 2-step process:
///
/// **Step 1 — CNIC Upload**: front + back image from camera or gallery.
/// **Step 2 — Live Selfie**: front-camera photo only (no gallery).
///
/// After submission, a confirmation screen informs the donor that their
/// documents are under review.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() =>
      _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _picker = ImagePicker();

  // ── Pickers ─────────────────────────────────────────────────────────

  Future<void> _pickCnic({required bool front}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file == null) return;
    if (front) {
      ref.read(verificationNotifierProvider.notifier).setCnicFront(file);
    } else {
      ref.read(verificationNotifierProvider.notifier).setCnicBack(file);
    }
  }

  Future<void> _pickSelfie() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    ref.read(verificationNotifierProvider.notifier).setSelfie(file);
  }

  Future<void> _retakeCnic({required bool front}) async {
    if (front) {
      ref.read(verificationNotifierProvider.notifier).setCnicFront(null);
    } else {
      ref.read(verificationNotifierProvider.notifier).setCnicBack(null);
    }
  }

  void _retakeSelfie() {
    ref.read(verificationNotifierProvider.notifier).setSelfie(null);
  }

  void _goBack() {
    final state = ref.read(verificationNotifierProvider);
    if (state.step == VerificationStep.selfie) {
      ref.read(verificationNotifierProvider.notifier).backToCnicStep();
    } else {
      context.pop();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vState = ref.watch(verificationNotifierProvider);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        leading: vState.step == VerificationStep.confirmed
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              ),
        title: vState.step == VerificationStep.confirmed
            ? null
            : const Text('Verification'),
      ),
      body: SafeArea(
        child: _buildBody(context, vState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VerificationState vState) {
    switch (vState.step) {
      case VerificationStep.cnicUpload:
        return _CnicUploadStep(
          state: vState,
          onPickFront: () => _pickCnic(front: true),
          onPickBack: () => _pickCnic(front: false),
          onRetakeFront: () => _retakeCnic(front: true),
          onRetakeBack: () => _retakeCnic(front: false),
          onContinue: () => ref
              .read(verificationNotifierProvider.notifier)
              .goToSelfieStep(),
        );
      case VerificationStep.selfie:
        return _SelfieStep(
          state: vState,
          onCapture: _pickSelfie,
          onRetake: _retakeSelfie,
          onSubmit: () =>
              ref.read(verificationNotifierProvider.notifier).submit(),
        );
      case VerificationStep.submitting:
        return const _SubmittingView();
      case VerificationStep.confirmed:
        return const _ConfirmationStep();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step $currentStep of $totalSteps',
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(totalSteps, (i) {
              final isDone = i < currentStep;
              final isCurrent = i == currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  height: 4,
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: (isDone || isCurrent)
                        ? colors.primary
                        : colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step 1 — CNIC Upload
// ═══════════════════════════════════════════════════════════════════════════════

class _CnicUploadStep extends StatelessWidget {
  const _CnicUploadStep({
    required this.state,
    required this.onPickFront,
    required this.onPickBack,
    required this.onRetakeFront,
    required this.onRetakeBack,
    required this.onContinue,
  });

  final VerificationState state;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onRetakeFront;
  final VoidCallback onRetakeBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final canContinue =
        state.cnicFront != null && state.cnicBack != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIndicator(currentStep: 1, totalSteps: 2),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify your identity',
                  style: context.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'To keep the donor network safe, we verify every donor '
                  'with a government-issued ID. Upload clear photos of both '
                  'sides of your CNIC.',
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── CNIC Front ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _UploadCard(
              label: 'CNIC Front',
              imageFile: state.cnicFront,
              onTapPlaceholder: onPickFront,
              onTapRetake: onRetakeFront,
            ),
          ),
          const SizedBox(height: 12),

          // ── CNIC Back ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _UploadCard(
              label: 'CNIC Back',
              imageFile: state.cnicBack,
              onTapPlaceholder: onPickBack,
              onTapRetake: onRetakeBack,
            ),
          ),
          const SizedBox(height: 32),

          // ── Error ─────────────────────────────────────────────────
          if (state.serverError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ErrorBanner(message: state.serverError!),
            ),

          // ── Continue ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PrimaryButton(
              label: 'Continue',
              onPressed: canContinue ? onContinue : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step 2 — Live Selfie
// ═══════════════════════════════════════════════════════════════════════════════

class _SelfieStep extends StatelessWidget {
  const _SelfieStep({
    required this.state,
    required this.onCapture,
    required this.onRetake,
    required this.onSubmit,
  });

  final VerificationState state;
  final VoidCallback onCapture;
  final VoidCallback onRetake;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIndicator(currentStep: 2, totalSteps: 2),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Take a quick selfie',
                  style: context.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'This must be a live photo — no gallery uploads allowed. '
                  'We compare your selfie with your CNIC to confirm your identity.',
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Camera area / selfie preview ──────────────────────────
          if (state.selfie == null)
            _SelfieGuidePlaceholder(onCapture: onCapture)
          else
            _SelfiePreview(
              imageFile: state.selfie!,
              onRetake: onRetake,
              onContinue: onSubmit,
            ),
          const SizedBox(height: 12),

          // ── Error ─────────────────────────────────────────────────
          if (state.serverError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ErrorBanner(message: state.serverError!),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Submitting (loading) view
// ═══════════════════════════════════════════════════════════════════════════════

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  AlwaysStoppedAnimation(context.colors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Uploading your documents\u2026',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please keep this screen open.',
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Confirmation
// ═══════════════════════════════════════════════════════════════════════════════

class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // ── Checkmark illustration ────────────────────────────────
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
            'Verification Submitted',
            style: context.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'Your documents are under review. '
            'This usually takes a few hours.',
            style: context.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),

          SecondaryButton(
            label: 'Back to Home',
            onPressed: () => context.go(RoutePaths.home),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Upload card (CNIC front / back)
// ═══════════════════════════════════════════════════════════════════════════════

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.label,
    required this.imageFile,
    required this.onTapPlaceholder,
    required this.onTapRetake,
  });

  final String label;
  final XFile? imageFile;
  final VoidCallback onTapPlaceholder;
  final VoidCallback onTapRetake;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (imageFile != null) {
      // ── Preview state ─────────────────────────────────────────────
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(imageFile!.path),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: onTapRetake,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Retake',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Placeholder state ───────────────────────────────────────────────
    return GestureDetector(
      onTap: onTapPlaceholder,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: colors.border),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 40, color: colors.textMedium),
              const SizedBox(height: 12),
              Text(
                label,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to upload',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Selfie guide placeholder
// ═══════════════════════════════════════════════════════════════════════════════

/// Shows a circular face-guide overlay in Secondary teal and a capture
/// button. Uses the front camera via [ImageSource.camera].
class _SelfieGuidePlaceholder extends StatelessWidget {
  const _SelfieGuidePlaceholder({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ── Face guide ────────────────────────────────────────────
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.secondary, width: 3),
                ),
                child: Center(
                  child: Icon(
                    Icons.face_outlined,
                    size: 64,
                    color: colors.secondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Take Selfie',
            icon: Icons.camera_alt,
            onPressed: onCapture,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Selfie preview (after capture)
// ═══════════════════════════════════════════════════════════════════════════════

class _SelfiePreview extends StatelessWidget {
  const _SelfiePreview({
    required this.imageFile,
    required this.onRetake,
    required this.onContinue,
  });

  final XFile imageFile;
  final VoidCallback onRetake;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(imageFile.path),
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Retake',
                  onPressed: onRetake,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Submit for Verification',
                  onPressed: onContinue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dashed border painter
// ═══════════════════════════════════════════════════════════════════════════════

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final radius = BorderRadius.circular(16).toRRect(
      Offset.zero & size,
    );

    final path = Path()..addRRect(radius);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
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
      margin: const EdgeInsets.only(bottom: 16),
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
