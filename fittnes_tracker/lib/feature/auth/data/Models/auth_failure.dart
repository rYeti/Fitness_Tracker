import 'package:dio/dio.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';

/// Why an authentication call failed.
///
/// The notifier reports the *case*, not the sentence: a [StateNotifier] has no
/// [BuildContext] and so no locale, and the API sends its `message` in English
/// only — it has no localization and never receives an `Accept-Language`. So
/// the server names which refusal happened via a machine-readable `error` code
/// and the screen turns that into text at build time, where the locale is
/// known. Mirrors `ConsoleError` in the trainer console.
enum AuthFailure {
  invalidCredentials,
  registrationFailed,
  unknownAccountType,
  network,
  unknown,
}

extension AuthFailureMessage on AuthFailure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    AuthFailure.invalidCredentials => l10n.authFailureInvalidCredentials,
    AuthFailure.registrationFailed => l10n.authFailureRegistrationFailed,
    AuthFailure.unknownAccountType => l10n.authFailureUnknownAccountType,
    AuthFailure.network => l10n.authFailureNetwork,
    AuthFailure.unknown => l10n.authFailureUnknown,
  };
}

/// Classifies a thrown error into the case the UI should explain.
///
/// Reads the response body's `error` code where the API sends one, and falls
/// back to the status. This replaced substring-matching `'400'` and `'401'`
/// against `e.toString()`, whose final fallback returned the raw exception —
/// so a Dio stack trace could end up in a snackbar.
AuthFailure classifyAuthError(Object error, {required bool registering}) {
  if (error is! DioException) return AuthFailure.unknown;

  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return AuthFailure.network;
  }

  final data = error.response?.data;
  if (data is Map<String, dynamic> &&
      data['error'] == 'unknown_account_type') {
    return AuthFailure.unknownAccountType;
  }

  return switch (error.response?.statusCode) {
    401 => AuthFailure.invalidCredentials,
    // Register answers 400 for a taken username or email; login answers 401
    // for bad credentials, so a 400 there is something else entirely.
    400 when registering => AuthFailure.registrationFailed,
    null => AuthFailure.network,
    _ => AuthFailure.unknown,
  };
}

/// Why a password reset couldn't be completed. Separate from [AuthFailure]
/// because the reset screen has its own two outcomes and no session to speak of.
enum ResetPasswordFailure { linkNoLongerValid, unknown }

extension ResetPasswordFailureMessage on ResetPasswordFailure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    ResetPasswordFailure.linkNoLongerValid =>
      l10n.resetFailureLinkNoLongerValid,
    ResetPasswordFailure.unknown => l10n.authFailureUnknown,
  };
}
