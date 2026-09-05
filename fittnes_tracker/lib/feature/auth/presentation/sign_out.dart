import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/secure_token_storage.dart';
import 'package:ForgeForm/core/network/services/sync_service.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/chat/data/attachment_store.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart' hide Consumer;
import 'package:shared_preferences/shared_preferences.dart';

/// Confirms and performs a sign-out, clearing this device's copy of the account.
///
/// Returns `true` if the user signed out, `false` if they cancelled. Navigation
/// is the caller's business — this only tears the session down.
///
/// ## Why the wipe happens here and not at the next login
///
/// The local database used to survive sign-out and be cleared on the *next*
/// login, but only when the username differed from `last_logged_in_user`. That
/// left one account's rows sitting on disk under the next account's bearer
/// token, and a sync firing in that window pushes the wrong person's workouts
/// into the wrong person's account. Clearing on the way out closes most of that
/// window. The login-time check stays as a backstop for the paths that never
/// reach this function — a refresh-token expiry, or a crash mid-sign-out.
///
/// ## Why it asks first
///
/// Clearing is unrecoverable for anything still pending. For a `pendingDelete`
/// row it is worse than losing an edit: the row is the *only* record that the
/// user deleted something, so discarding it silently resurrects whatever they
/// removed the next time the account is pulled down. We try to push first, and
/// if anything is still outstanding we say how much and let the user decide.
Future<bool> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final access = context.read<AccessProvider>();
  final goals = context.read<UserGoalsProvider>();
  final db = sl<AppDatabase>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(l10n.signOut),
          content: Text(l10n.signOutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l10n.signOut,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return false;

  // Best effort: get pending work to the server while we still hold a token.
  // A failure here is not fatal — it just means the warning below has something
  // to report.
  if (await db.countUnsyncedChanges() > 0) {
    await _pushPendingChanges();
  }

  final remaining = await db.countUnsyncedChanges();
  if (remaining > 0) {
    if (!context.mounted) return false;
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.signOutUnsyncedTitle),
            content: Text(l10n.signOutUnsyncedBody(remaining)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.signOutAnyway,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
          ),
    );
    if (discard != true) return false;
  }

  await access.reset();
  await ref.read(authProvider.notifier).logout();
  await db.clearAllUserData();
  await clearPerAccountPrefs();
  // The identity key deliberately survives sign-out (docs/chat-encryption.md
  // §8); a library of somebody's progress photos and form-check videos must
  // not — see docs/chat-attachments.md §C.4.
  await AttachmentStore().clearAll();
  await goals.reload();
  return true;
}

/// Pushes whatever is pending, swallowing failures — offline is the ordinary
/// case here, and the caller re-counts afterwards either way.
Future<void> _pushPendingChanges() async {
  try {
    if (await SecureTokenStorage.getToken() == null) return;
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(serverUrlPrefsKey) ?? serverUrlDefault;
    final db = sl<AppDatabase>();
    await SyncService(
      db: db,
      apiClient: ApiClient(baseUrl: serverUrl),
      mealTemplateDao: MealTemplateDao(db),
    ).syncAll();
  } catch (_) {
    // No network, or the server is down. The re-count tells the user.
  }
}

/// Removes the SharedPreferences entries that belong to one account rather than
/// to the device, so the next person to sign in does not inherit them.
///
/// The sync timestamps matter most: leaving them behind makes the next account's
/// first launch believe it is already up to date and skip the pull that would
/// fetch its data.
Future<void> clearPerAccountPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await Future.wait([
    prefs.remove('meal_templates'),
    prefs.remove('last_sync_timestamp'),
    prefs.remove(lastPullPrefsKey),
    // A half-finished session belonging to the previous account, which the home
    // screen otherwise reads on launch and jumps straight to.
    prefs.remove('active_workout_scheduled_id'),
    prefs.remove('active_workout_scheduled_date'),
    prefs.remove('active_workout_exercise_index'),
    prefs.remove('active_workout_set_index'),
  ]);
}
