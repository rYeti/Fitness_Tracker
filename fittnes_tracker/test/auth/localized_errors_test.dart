import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/auth/data/Models/auth_failure.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/l10n/app_localizations_de.dart';
import 'package:ForgeForm/l10n/app_localizations_en.dart';

/// Every refusal a user reads comes from the .arb files, not from the API.
///
/// The API has no localization and never receives an Accept-Language header, so
/// its `message` is English-only. It names the case with a machine-readable
/// `error` code and the client supplies the wording. These tests pin that,
/// because the code previously preferred the server's sentence — which made
/// every translated string unreachable and handed German users English.
void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();

  DioException refusal(int status, Map<String, dynamic> body) => DioException(
    requestOptions: RequestOptions(path: '/'),
    response: Response(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );

  group('InviteException', () {
    test('ignores the server sentence in favour of the localized one', () {
      // The regression. A server message is always sent, so preferring it meant
      // the localized string never rendered.
      const failure = InviteException(
        InviteFailure.invalidCode,
        'Some English sentence from the API.',
      );

      expect(failure.message(en), en.inviteFailureInvalidCode);
      expect(failure.message(de), de.inviteFailureInvalidCode);
      expect(failure.message(de), isNot(contains('English')));
    });

    test('keeps the server sentence for diagnostics only', () {
      const failure = InviteException(InviteFailure.network, 'boom from API');
      expect(failure.toString(), 'boom from API');
    });

    test('describes a full plan with the numbers, in the reader language', () {
      // The one case the server was genuinely more specific about. The
      // specificity is data, not wording, so it survives translation.
      const failure = InviteException(
        InviteFailure.seatLimitReached,
        'Your plan covers 10 clients and all of them are in use.',
        10,
        10,
      );

      expect(failure.message(en), contains('10'));
      expect(failure.message(de), contains('10'));
      expect(failure.message(de), de.inviteFailureSeatLimitReachedDetailed(10, 10));
    });

    test('falls back to the plain wording when no numbers were sent', () {
      const failure = InviteException(InviteFailure.seatLimitReached);
      expect(failure.message(en), en.inviteFailureSeatLimitReached);
    });

    test('every failure has wording in both languages', () {
      for (final f in InviteFailure.values) {
        expect(f.localizedMessage(en), isNotEmpty, reason: '$f in en');
        expect(f.localizedMessage(de), isNotEmpty, reason: '$f in de');
      }
    });
  });

  group('classifyAuthError', () {
    test('names an unknown account type from its error code', () {
      final failure = classifyAuthError(
        refusal(400, {'error': 'unknown_account_type', 'message': 'Choose one of: Trainee, Trainer.'}),
        registering: true,
      );
      expect(failure, AuthFailure.unknownAccountType);
      expect(failure.localizedMessage(de), de.authFailureUnknownAccountType);
    });

    test('reads 401 as bad credentials even with a bare string body', () {
      // The login endpoint answers with a plain string, not a JSON error object.
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 401,
          data: 'Invalid username or password.',
        ),
        type: DioExceptionType.badResponse,
      );
      expect(
        classifyAuthError(e, registering: false),
        AuthFailure.invalidCredentials,
      );
    });

    test('reads 400 while registering as a taken username or email', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 400,
          data: 'Registration failed. Please check the provided information.',
        ),
        type: DioExceptionType.badResponse,
      );
      expect(
        classifyAuthError(e, registering: true),
        AuthFailure.registrationFailed,
      );
    });

    test('does not read a 400 outside registration as a taken username', () {
      final e = refusal(400, {'error': 'something_else'});
      expect(classifyAuthError(e, registering: false), AuthFailure.unknown);
    });

    test('separates a connection failure from a rejection', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      expect(classifyAuthError(e, registering: false), AuthFailure.network);
    });

    test('never leaks a raw exception string', () {
      // The old _friendlyError returned e.toString() as its fallback, so a Dio
      // stack trace could land in a snackbar.
      final failure = classifyAuthError(Exception('PII in here'), registering: false);
      expect(failure, AuthFailure.unknown);
      expect(failure.localizedMessage(en), en.authFailureUnknown);
      expect(failure.localizedMessage(en), isNot(contains('PII')));
    });

    test('every failure has wording in both languages', () {
      for (final f in AuthFailure.values) {
        expect(f.localizedMessage(en), isNotEmpty, reason: '$f in en');
        expect(f.localizedMessage(de), isNotEmpty, reason: '$f in de');
      }
      for (final f in ResetPasswordFailure.values) {
        expect(f.localizedMessage(en), isNotEmpty, reason: '$f in en');
        expect(f.localizedMessage(de), isNotEmpty, reason: '$f in de');
      }
    });
  });
}
