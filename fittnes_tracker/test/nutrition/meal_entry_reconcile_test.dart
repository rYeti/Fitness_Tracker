import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/network/services/meal_entry_reconcile.dart';

/// Which of a meal's food entries the sync still has to send.
///
/// The old push sent every local entry with no `serverId`, which is only right
/// when the server holds nothing for that meal. It frequently holds something —
/// creating a meal is idempotent server-side, a reconcile pass clears local
/// `serverId`s without the server losing a thing, and a second device pushes the
/// same breakfast — and every one of those cases logged the food twice and
/// inflated the day's calories.
///
/// Matching is by food *and count*, never set membership: two portions of the
/// same food is something a client really logs, and collapsing them would take
/// calories away from someone who ate them.
void main() {
  LocalFoodEntry local(int id, {String? serverId, String? food = 'food-oats'}) =>
      LocalFoodEntry(id: id, serverId: serverId, foodServerId: food);

  ServerFoodEntry server(String id, {String food = 'food-oats'}) =>
      ServerFoodEntry(id: id, foodItemId: food);

  test('a meal the server has never seen pushes everything', () {
    final plan = planMealEntryPush(
      local: [local(1), local(2, food: 'food-eggs')],
      server: const [],
    );

    expect(plan.adopt, isEmpty);
    expect(plan.push, [1, 2]);
  });

  test('entries the server already holds are adopted, not sent again', () {
    // The reconcile-reset shape: the rows are all still on the server, the
    // device just forgot their ids.
    final plan = planMealEntryPush(
      local: [local(1), local(2, food: 'food-eggs')],
      server: [server('srv-1'), server('srv-2', food: 'food-eggs')],
    );

    expect(plan.adopt, {1: 'srv-1', 2: 'srv-2'});
    expect(plan.push, isEmpty);
  });

  test('a second portion of a food the server has once is still pushed', () {
    final plan = planMealEntryPush(
      local: [local(1), local(2)],
      server: [server('srv-1')],
    );

    expect(plan.adopt, {1: 'srv-1'});
    expect(plan.push, [2]);
  });

  test('an entry that already owns its server row cannot have it adopted', () {
    // Without this the entry the device already synced would hand its server row
    // to the new one, and the new food would never be pushed at all.
    final plan = planMealEntryPush(
      local: [local(1, serverId: 'srv-1'), local(2)],
      server: [server('srv-1')],
    );

    expect(plan.adopt, isEmpty);
    expect(plan.push, [2]);
  });

  test('a food that has not synced yet is neither adopted nor pushed', () {
    // The batch endpoint takes food server ids; there is nothing to send.
    final plan = planMealEntryPush(
      local: [local(1, food: null)],
      server: const [],
    );

    expect(plan.adopt, isEmpty);
    expect(plan.push, isEmpty);
  });

  test('an entry whose server row is gone is left alone rather than re-sent', () {
    // Another device deleted it. Re-pushing would resurrect it on every sync
    // forever, and the next pull is what cleans the local row up.
    final plan = planMealEntryPush(
      local: [local(1, serverId: 'srv-deleted')],
      server: const [],
    );

    expect(plan.adopt, isEmpty);
    expect(plan.push, isEmpty);
  });

  test('foods are matched to their own kind, not to each other', () {
    final plan = planMealEntryPush(
      local: [local(1, food: 'food-eggs')],
      server: [server('srv-1', food: 'food-oats')],
    );

    expect(plan.adopt, isEmpty);
    expect(plan.push, [1]);
  });
}
