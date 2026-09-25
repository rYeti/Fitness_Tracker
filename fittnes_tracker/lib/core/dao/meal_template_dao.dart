import 'dart:convert';
import 'package:ForgeForm/core/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

// An implementation that uses SharedPreferences for persistent storage
class MealTemplateDao {
  final AppDatabase db;
  static const String _storageKey = 'meal_templates';

  /// Server ids of templates deleted on this device and not yet deleted on
  /// the server. Per account — `clearPerAccountPrefs` removes it with the
  /// templates themselves.
  static const String deletedStorageKey = 'meal_templates_deleted';
  static int _nextId = 1;

  MealTemplateDao(this.db) {
    _initNextId();
  }

  // Initialize the next ID based on stored templates
  Future<void> _initNextId() async {
    try {
      final templates = await getAllTemplates();
      if (templates.isNotEmpty) {
        final maxId = templates
            .map((t) => t['id'] as int)
            .reduce((value, element) => value > element ? value : element);
        _nextId = maxId + 1;
      }
    } catch (e) {
      dev.log('Error initializing next ID: $e', name: 'MealTemplateDao');
    }
  }

  // Load templates from SharedPreferences
  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) {
        final map = Map<String, dynamic>.from(item);
        // Templates saved before the meal-category naming was unified with
        // the food tracker ('Snack' vs 'Snacks') would otherwise disappear
        // from the Snacks tab and fail to match logged meals when applied.
        if (map['category'] == 'Snack') map['category'] = 'Snacks';
        return map;
      }).toList();
    } catch (e, stackTrace) {
      dev.log('Error loading templates: $e', name: 'MealTemplateDao');
      dev.log('Stack trace: $stackTrace', name: 'MealTemplateDao');
      return [];
    }
  }

  // Save templates to SharedPreferences
  Future<void> _saveTemplates(List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(templates);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      dev.log('Error saving templates: $e', name: 'MealTemplateDao');
    }
  }

  // Get all templates
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    try {
      return await _loadTemplates();
    } catch (e) {
      dev.log('Error getting all templates: $e', name: 'MealTemplateDao');
      return [];
    }
  }

  // Get templates by category
  Future<List<Map<String, dynamic>>> getTemplatesByCategory(
    String category,
  ) async {
    try {
      final templates = await _loadTemplates();
      return templates.where((t) => t['category'] == category).toList();
    } catch (e) {
      dev.log(
        'Error getting templates by category: $e',
        name: 'MealTemplateDao',
      );
      return [];
    }
  }

  // Get items for a template
  Future<List<Map<String, dynamic>>> getTemplateItems(int templateId) async {
    try {
      final templates = await _loadTemplates();
      final template = templates.firstWhere(
        (t) => t['id'] == templateId,
        orElse: () => {'items': []},
      );
      return List<Map<String, dynamic>>.from(template['items'] ?? []);
    } catch (e) {
      dev.log('Error getting template items: $e', name: 'MealTemplateDao');
      return [];
    }
  }

  // Insert a new template
  Future<int> insertTemplate(Map<String, dynamic> template) async {
    try {
      final templates = await _loadTemplates();

      // Create a new template with ID
      final id = _nextId++;
      template['id'] = id;
      if (!template.containsKey('items')) {
        template['items'] = [];
      }
      // Its id on the server, minted here so every attempt to create it
      // carries the same one — see [newSyncId]. One pulled from the server
      // arrives with the server's.
      if ((template['serverId'] as String?)?.isNotEmpty != true) {
        template['serverId'] = newSyncId();
        template['pending'] = true;
      }

      templates.add(template);
      await _saveTemplates(templates);

      dev.log('Template inserted with ID: $id', name: 'MealTemplateDao');
      return id;
    } catch (e) {
      dev.log('Error inserting template: $e', name: 'MealTemplateDao');
      return -1;
    }
  }

  // Insert a template item
  Future<int> insertTemplateItem(Map<String, dynamic> item) async {
    try {
      final templates = await _loadTemplates();
      final templateId = item['templateId'];
      final index = templates.indexWhere((t) => t['id'] == templateId);

      if (index >= 0) {
        final template = templates[index];
        final items = List<Map<String, dynamic>>.from(template['items'] ?? []);

        // Generate a new ID for this item
        final itemId =
            items.isEmpty
                ? 1
                : (items
                        .map((i) => i['id'] as int)
                        .reduce((a, b) => a > b ? a : b) +
                    1);

        // Set the ID and add the item
        item['id'] = itemId;
        items.add(Map<String, dynamic>.from(item));

        // Update the template
        template['items'] = items;
        _markEdited(template);
        templates[index] = template;

        await _saveTemplates(templates);
        return itemId;
      }

      return -1;
    } catch (e) {
      dev.log('Error inserting template item: $e', name: 'MealTemplateDao');
      return -1;
    }
  }

  // Update a template
  Future<bool> updateTemplate(Map<String, dynamic> template, int id) async {
    try {
      final templates = await _loadTemplates();
      final index = templates.indexWhere((t) => t['id'] == id);

      if (index >= 0) {
        // Preserve the original template id
        template['id'] = id;

        // Preserve the items if not provided in the update
        if (!template.containsKey('items')) {
          template['items'] = templates[index]['items'];
        }

        // And the sync bookkeeping, which no caller knows about: dropping the
        // server id here made every edited template look new, so the push
        // created a second copy on the server and the next pull brought the
        // first back beside it.
        for (final key in const ['serverId', 'rev', 'pending']) {
          if (!template.containsKey(key) &&
              templates[index].containsKey(key)) {
            template[key] = templates[index][key];
          }
        }
        _markEdited(template);

        // Update the template in the list
        templates[index] = template;
        dev.log(
          'Updating template with ID: $id, data: ${jsonEncode(template)}',
          name: 'MealTemplateDao',
        );
        await _saveTemplates(templates);
        return true;
      }
      dev.log(
        'Template with ID: $id not found for update',
        name: 'MealTemplateDao',
      );
      return false;
    } catch (e, stackTrace) {
      dev.log('Error updating template: $e', name: 'MealTemplateDao');
      dev.log('Stack trace: $stackTrace', name: 'MealTemplateDao');
      return false;
    }
  }

  // Delete all items for a template
  Future<int> deleteTemplateItems(int templateId) async {
    try {
      final templates = await _loadTemplates();
      final index = templates.indexWhere((t) => t['id'] == templateId);

      if (index >= 0) {
        final itemCount = (templates[index]['items'] as List).length;
        templates[index]['items'] = [];
        _markEdited(templates[index]);
        await _saveTemplates(templates);
        return itemCount;
      }
      return 0;
    } catch (e) {
      dev.log('Error deleting template items: $e', name: 'MealTemplateDao');
      return 0;
    }
  }

  // Delete a template
  Future<int> deleteTemplate(int templateId) async {
    try {
      final templates = await _loadTemplates();
      final index = templates.indexWhere((t) => t['id'] == templateId);

      if (index >= 0) {
        final removed = templates.removeAt(index);
        await _saveTemplates(templates);
        // Remembered until the push has told the server — without it the next
        // pull found the template still there and put it back. Remembered even
        // if it was never marked pushed: a create whose answer was lost left
        // the template on the server under this id, and a DELETE for one the
        // server never got is answered 404, which the push treats as done.
        final serverId = removed['serverId'] as String?;
        if (serverId != null && serverId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(deletedStorageKey, [
            ...?prefs.getStringList(deletedStorageKey),
            serverId,
          ]);
        }
        return 1;
      }
      return 0;
    } catch (e) {
      dev.log('Error deleting template: $e', name: 'MealTemplateDao');
      return 0;
    }
  }

  // ── Sync helpers ────────────────────────────────────────────────────────────

  // Templates live in SharedPreferences, where the database's sync triggers
  // (lib/core/sync/sync_triggers.dart) can't see them, so they keep the same
  // two facts by hand: `dirty`, set on every edit to one the server has, and
  // `rev`, bumped on every edit so a push can tell whether what it sent is
  // still what's stored.
  //
  // A third fact is `pending`: set on a template this device made until the
  // server has it. Every template has a `serverId` from the moment it is made,
  // so the id no longer says that; a template from before ids were minted
  // here has none, and counts as pending too.
  static void _markEdited(Map<String, dynamic> template) {
    template['rev'] = ((template['rev'] as int?) ?? 0) + 1;
    if (_isOnServer(template)) template['dirty'] = true;
  }

  /// Whether this device knows the server has this template — what
  /// `SyncStatus.isOnServer` says for a database row. A template has no
  /// status column, so the `pending` flag stands in for `sync_status = 0`.
  static bool _isOnServer(Map template) =>
      template['pending'] != true &&
      ((template['serverId'] as String?)?.isNotEmpty ?? false);

  /// Templates the server doesn't have yet.
  Future<List<Map<String, dynamic>>> getUnsyncedTemplates() async {
    final templates = await _loadTemplates();
    return templates.where((t) => !_isOnServer(t)).toList();
  }

  /// Templates the server has that were edited here since.
  Future<List<Map<String, dynamic>>> getEditedTemplates() async {
    final templates = await _loadTemplates();
    return templates
        .where((t) => t['dirty'] == true && _isOnServer(t))
        .toList();
  }

  /// Gives a template the server doesn't have a fresh id and returns it: one
  /// made before ids were minted here, or one whose id the server refused
  /// (409 — it names a row that isn't this account's).
  Future<String> assignServerId(int localId) async {
    final templates = await _loadTemplates();
    final id = newSyncId();
    final index = templates.indexWhere((t) => t['id'] == localId);
    if (index >= 0 && !_isOnServer(templates[index])) {
      templates[index]['serverId'] = id;
      templates[index]['pending'] = true;
      await _saveTemplates(templates);
    }
    return id;
  }

  /// Stores the server's id for the template — the one it was sent with,
  /// unless the server answered with another — and records that the server
  /// has it as of [sentRev] — unless it was edited while the request
  /// was in flight, in which case it stays marked for the next push.
  Future<void> markTemplateSynced(
    int localId,
    String serverId, {
    int? sentRev,
  }) async {
    final templates = await _loadTemplates();
    final index = templates.indexWhere((t) => t['id'] == localId);
    if (index >= 0) {
      final template = templates[index];
      template['serverId'] = serverId;
      template.remove('pending');
      final unchanged = ((template['rev'] as int?) ?? 0) == (sentRev ?? 0);
      if (unchanged) {
        template.remove('dirty');
      } else {
        template['dirty'] = true;
      }
      await _saveTemplates(templates);
    }
  }

  /// Whether any template has something to send: never pushed, edited since
  /// it was, or deleted here. Static so the push scheduler can ask without
  /// building a DAO.
  static Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getStringList(deletedStorageKey) ?? const []).isNotEmpty) {
      return true;
    }
    final json = prefs.getString(_storageKey);
    if (json == null || json.isEmpty) return false;
    try {
      for (final t in (jsonDecode(json) as List).cast<Map>()) {
        if (!_isOnServer(t) || t['dirty'] == true) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Writes the server's copy of a template over this device's, the way the
  /// sync engine writes a database row: without marking it edited.
  ///
  /// Only a template that holds nothing to send is overwritten. One edited
  /// here and not sent yet, or one whose create this device hasn't heard back
  /// about, is left as it is and reported [TemplateApply.heldBack] — the push
  /// sends it, and the pull asks for the server's copy again afterwards.
  Future<TemplateApply> applyFromServer(
    String serverId,
    Map<String, dynamic> fields,
  ) async {
    final templates = await _loadTemplates();
    final index = templates.indexWhere((t) => t['serverId'] == serverId);
    if (index < 0) return TemplateApply.absent;
    final template = templates[index];
    if (!_isOnServer(template) || template['dirty'] == true) {
      return TemplateApply.heldBack;
    }
    // Its local id, sync bookkeeping and anything else stored beside the
    // server's fields stay; the fields the server sends replace them.
    templates[index] = {...template, ...fields};
    if (!fields.containsKey('total_weight_grams')) {
      templates[index].remove('total_weight_grams');
    }
    await _saveTemplates(templates);
    return TemplateApply.applied;
  }

  /// Removes a template the server deleted — another device did, or it was
  /// deleted there after a create this device never heard back about —
  /// without remembering it as deleted here: there is nothing to tell the
  /// server. A deletion of it this device was waiting to send is forgotten
  /// too, for the same reason.
  Future<void> removeDeletedElsewhere(String serverId) async {
    final templates = await _loadTemplates();
    final before = templates.length;
    templates.removeWhere((t) => t['serverId'] == serverId);
    if (templates.length != before) await _saveTemplates(templates);
    await clearDeleted(serverId);
  }

  /// Server ids of templates deleted here that the server may still have.
  Future<List<String>> getDeletedServerIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(deletedStorageKey) ?? const [];
  }

  /// Forgets a deletion the server has been told about.
  Future<void> clearDeleted(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(deletedStorageKey, [
      for (final id in prefs.getStringList(deletedStorageKey) ?? const [])
        if (id != serverId) id,
    ]);
  }

  /// Returns the server UUID for the given local template ID, or null.
  String? getServerId(Map<String, dynamic> template) =>
      template['serverId'] as String?;
}

/// What [MealTemplateDao.applyFromServer] did with the server's copy.
enum TemplateApply {
  /// No template here has that server id.
  absent,

  /// This device's copy was clean, and now matches the server's.
  applied,

  /// This device's copy holds something not sent yet, and was left alone.
  heldBack,
}
