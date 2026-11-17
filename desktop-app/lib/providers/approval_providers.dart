import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_session.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// Whether this computer can approve the actions that hand the wallet over.
/// Asked again each time something shows it, so a password or Windows Hello
/// set up meanwhile is seen.
final approvalAvailabilityProvider = FutureProvider.autoDispose<ApprovalAvailability>(
  (ref) => ref.watch(userApprovalProvider).availability(),
);

/// What to tell the person when approval cannot be asked for, or null when
/// it can.
String? approvalUnavailableNote(AppLocalizations l10n, ApprovalAvailability availability) => switch (availability) {
  ApprovalAvailability.available => null,
  ApprovalAvailability.notSetUp => approvalNotSetUpNote(l10n),
};

/// What to set up so that approval can be asked for.
String approvalNotSetUpNote(AppLocalizations l10n) => switch (defaultTargetPlatform) {
  TargetPlatform.windows => l10n.desktopApprovalNeedsWindowsHello,
  TargetPlatform.linux => l10n.desktopApprovalNeedsLinuxService,
  _ => l10n.desktopApprovalNeedsMacPassword,
};

/// Asks for approval, telling the person [reason]. Null once approved;
/// otherwise what to tell them: [declined] if they said no.
Future<String?> askForApproval(
  UserApproval approval,
  AppLocalizations l10n, {
  required String reason,
  required String declined,
}) async {
  try {
    return switch (await approval.approve(reason: reason)) {
      ApprovalResult.approved => null,
      ApprovalResult.declined => declined,
      ApprovalResult.notSetUp => approvalNotSetUpNote(l10n),
    };
  } on PamUnexpectedPromptException {
    return l10n.desktopApprovalLoginAsksMore;
  } catch (e) {
    return l10n.desktopApprovalFailed('$e');
  }
}
