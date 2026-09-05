import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/extensions.dart';

/// A row of 6 single-digit input boxes for OTP entry.
///
/// Uses the app's existing theme tokens (border, text, card colors).
/// Auto-advances focus on digit entry; supports backspace navigation
/// and full-code paste.
class OtpInputWidget extends StatefulWidget {
  const OtpInputWidget({
    super.key,
    required this.length,
    required this.onChanged,
    this.onCompleted,
  });

  /// Number of digits (typically 6).
  final int length;

  /// Called whenever the combined code changes.
  final ValueChanged<String> onChanged;

  /// Called when all digits are filled.
  final VoidCallback? onCompleted;

  @override
  State<OtpInputWidget> createState() => _OtpInputWidgetState();
}

class _OtpInputWidgetState extends State<OtpInputWidget> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Returns the combined OTP code.
  String get code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length == 1) {
      // Move to next box if available.
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Backspace on empty — move focus to previous box.
      _focusNodes[index - 1].requestFocus();
    }
    final combined = code;
    widget.onChanged(combined);
    if (combined.length == widget.length) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: index == 0 || index == widget.length - 1 ? 0 : 4),
          child: SizedBox(
            width: 48,
            height: 56,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              onChanged: (v) => _onChanged(index, v),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
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
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}
