import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_colors.dart';

/// Why a seeker needs blood — persisted as `blood_requests.reason`.
///
/// Values mirror the CHECK constraint on the `blood_requests.reason`
/// column (migration `20260829_add_request_reason`).
enum RequestReason {
  accident('accident', 'Accident / Trauma'),
  surgery('surgery', 'Surgery'),
  pregnancyChildbirth('pregnancy_childbirth', 'Pregnancy & Childbirth'),
  cancerChemotherapy('cancer_chemotherapy', 'Cancer / Chemotherapy'),
  anemiaDisorder('anemia_disorder', 'Anemia / Blood Disorder'),
  dengueInfection('dengue_infection', 'Dengue / Infection'),
  other('other', 'Other');

  const RequestReason(this.value, this.label);

  /// String persisted in Supabase.
  final String value;

  /// Human-readable label shown in forms and pills.
  final String label;

  /// Resolves a stored value back to the enum.
  ///
  /// Falls back to [RequestReason.other] for unknown or legacy rows
  /// so the UI never breaks on old data.
  static RequestReason fromValue(String? value) {
    if (value == null) return RequestReason.other;
    return RequestReason.values.firstWhere(
      (reason) => reason.value == value,
      orElse: () => RequestReason.other,
    );
  }
}

/// Icon and accent mapping for [RequestReason].
///
/// Every accent pulls from existing [AppColors] tokens — no new colors.
/// The pill tint recipe (12% fill + 30% border) follows [DonorStatusChip].
extension RequestReasonStyle on RequestReason {
  /// Rounded-stroke Phosphor icon for this reason.
  PhosphorIconData get icon => switch (this) {
        RequestReason.accident => PhosphorIconsRegular.warningCircle,
        RequestReason.surgery => PhosphorIconsRegular.syringe,
        RequestReason.pregnancyChildbirth => PhosphorIconsRegular.baby,
        RequestReason.cancerChemotherapy => PhosphorIconsRegular.pill,
        RequestReason.anemiaDisorder => PhosphorIconsRegular.drop,
        RequestReason.dengueInfection => PhosphorIconsRegular.virus,
        RequestReason.other => PhosphorIconsRegular.question,
      };

  /// Existing-palette accent so each reason reads distinct at a glance:
  /// urgent red → accident, teal → surgery, crimson → pregnancy,
  /// ink → cancer, green → anemia, amber → dengue, gray → other.
  Color accent(AppColors colors) => switch (this) {
        RequestReason.accident => colors.urgent,
        RequestReason.surgery => colors.secondary,
        RequestReason.pregnancyChildbirth => colors.primary,
        RequestReason.cancerChemotherapy => colors.textHigh,
        RequestReason.anemiaDisorder => colors.success,
        RequestReason.dengueInfection => colors.warning,
        RequestReason.other => colors.textMedium,
      };
}
