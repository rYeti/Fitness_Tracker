import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/core/network/secure_token_storage.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart'
    show serverUrlDefault;
import 'package:ForgeForm/feature/trainer_console/data/trainer_licence_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Where a trainee redeems the code their trainer gave them.
class JoinTrainerScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the real repository.
  final TrainerLicenceRepository? repository;

  /// Runs after a successful join, to re-check entitlements before leaving.
  /// Overridable so widget tests don't reach the network.
  final Future<void> Function(BuildContext context)? onJoined;

  const JoinTrainerScreen({super.key, this.repository, this.onJoined});

  @override
  State<JoinTrainerScreen> createState() => _JoinTrainerScreenState();
}

class _JoinTrainerScreenState extends State<JoinTrainerScreen> {
  late final TrainerLicenceRepository _repository;
  late TextEditingController _code;
  late FocusNode _focusNode;
  bool _isLoading = false;
  String? _fieldError;
  String? _serverError;

  /// Invite codes are 12 hex characters (48 bits from a CSPRNG). Checking the
  /// shape locally saves a round trip on an obvious typo.
  static final _codePattern = RegExp(r'^[0-9A-F]{12}$');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? TrainerLicenceRepository();
    _code = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_validateCode);
  }

  @override
  void dispose() {
    _code.dispose();
    _focusNode.removeListener(_validateCode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.joinTrainerTitle),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 17,
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              l10n.joinTrainerPrompt,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              focusNode: _focusNode,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                _UpperCaseFormatter(),
              ],
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 3,
              ),
              decoration: InputDecoration(
                labelText: l10n.trainerCode,
                hintText: 'A3F2B891C7E4',
                errorText: _fieldError,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 8),
              Semantics(
                container: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: ForgeColors.statusBad,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverError!,
                        style: TextStyle(
                          fontFamily: 'Exo 2',
                          fontSize: 13,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ForgeColors.forgeOrange,
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.joinTrainerAction),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.joinTrainerDisclosure,
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Validates on blur as well as on submit, per CLAUDE.md — an error that only
  /// appears after tapping the button wastes a round of attention.
  void _validateCode() {
    if (_focusNode.hasFocus) return;
    final error = _codeError(AppLocalizations.of(context)!);
    if (error != _fieldError) setState(() => _fieldError = error);
  }

  String? _codeError(AppLocalizations l10n) {
    final value = _code.text.trim().toUpperCase();
    if (value.isEmpty) return l10n.joinTrainerCodeMissing;
    if (!_codePattern.hasMatch(value)) return l10n.joinTrainerCodeMalformed;
    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final error = _codeError(l10n);
    if (error != null) {
      setState(() {
        _fieldError = error;
        _serverError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldError = null;
      _serverError = null;
    });

    try {
      await _repository.joinTrainer(_code.text.trim().toUpperCase());

      // Re-check access before leaving: joining a paying trainer grants Pro,
      // and the app behind this screen has to know that immediately or the
      // trainee sees a paywall on a feature they now have.
      if (!mounted) return;
      await (widget.onJoined ?? _refreshAccess)(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.joinTrainerConnected)),
      );
      // maybePop: this screen can be the root route (reached straight from a
      // trainee's empty state), and popping the last route asserts.
      await Navigator.of(context).maybePop(true);
    } on InviteException catch (e) {
      if (!mounted) return;
      setState(() {
        // A bad code is a field problem; anything about the *trainer's* plan
        // isn't the trainee's input being wrong, so it reads as a notice
        // rather than a validation error.
        final isFieldProblem = e.failure == InviteFailure.invalidCode ||
            e.failure == InviteFailure.expiredCode ||
            e.failure == InviteFailure.selfInvite;
        _fieldError = isFieldProblem ? e.message(l10n) : null;
        _serverError = isFieldProblem ? null : e.message(l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _serverError = l10n.somethingWentWrongRetry);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAccess(BuildContext context) async {
    final access = context.read<AccessProvider>();
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) return;
      await access.refresh(serverBaseUrl: serverUrlDefault, bearerToken: token);
    } catch (_) {
      // The relationship was created regardless; the next launch re-checks.
    }
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
