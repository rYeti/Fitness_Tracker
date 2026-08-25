/// Deciding which of a meal's local food entries still need pushing.
///
/// Pushing a meal's entries used to mean POSTing every local entry that had no
/// `serverId`, which is only correct if the server holds nothing for that meal.
/// It often holds something: creating a meal is idempotent server-side, so a
/// re-pushed meal comes back with the food it already had; a reconcile pass
/// clears local `serverId`s without the server losing anything; and a second
/// device may have pushed the same breakfast. Appending in those cases logs the
/// same food twice and inflates the day's calories.
///
/// So the push is a reconcile: entries the server already holds are *adopted*
/// (the local row is stamped with the server's id) and only the remainder is
/// sent. Matching is by food and by **count**, never by set membership — two
/// portions of the same food is a real thing a client logs, and the API
/// documents that repeats are meaningful.
library;

/// A local `MealFoodTable` row, reduced to what the reconcile needs.
class LocalFoodEntry {
  /// The local row id, so the caller can stamp or push the right row.
  final int id;

  /// The server's id for this entry, or null when it has never been pushed.
  final String? serverId;

  /// The *food item's* server id. Null when the food itself hasn't synced yet —
  /// such an entry can't be pushed at all, since the batch endpoint takes food
  /// server ids.
  final String? foodServerId;

  const LocalFoodEntry({
    required this.id,
    required this.serverId,
    required this.foodServerId,
  });
}

/// One entry the server says the meal holds.
class ServerFoodEntry {
  final String id;
  final String foodItemId;

  const ServerFoodEntry({required this.id, required this.foodItemId});
}

/// What to do with a meal's local entries: [adopt] maps a local row id to the
/// server entry id it turned out to already have, [push] lists the local rows
/// that genuinely aren't on the server yet, in order.
class MealEntryPlan {
  final Map<int, String> adopt;
  final List<int> push;

  const MealEntryPlan({required this.adopt, required this.push});
}

/// Works out [MealEntryPlan] for one meal.
///
/// A local entry whose `serverId` is no longer in [server] is left alone rather
/// than re-pushed: the usual reason for it to vanish is that another device
/// deleted it, and re-pushing would resurrect it on every sync forever. The
/// local row is cleaned up by the next pull instead.
MealEntryPlan planMealEntryPush({
  required List<LocalFoodEntry> local,
  required List<ServerFoodEntry> server,
}) {
  // Server entries grouped by food, in the order the server returned them, so
  // popping one is "there is a spare portion of this food on the server".
  final unclaimed = <String, List<String>>{};
  for (final entry in server) {
    unclaimed.putIfAbsent(entry.foodItemId, () => <String>[]).add(entry.id);
  }

  // Entries this device already owns claim their server row first, so they
  // can't be handed to a second local row as a spare.
  for (final entry in local) {
    final owned = entry.serverId;
    if (owned == null) continue;
    for (final ids in unclaimed.values) {
      if (ids.remove(owned)) break;
    }
  }

  final adopt = <int, String>{};
  final push = <int>[];
  for (final entry in local) {
    if (entry.serverId != null) continue;
    final foodServerId = entry.foodServerId;
    if (foodServerId == null) continue; // unpushable until the food syncs

    final spares = unclaimed[foodServerId];
    if (spares != null && spares.isNotEmpty) {
      adopt[entry.id] = spares.removeAt(0);
    } else {
      push.add(entry.id);
    }
  }

  return MealEntryPlan(adopt: adopt, push: push);
}
