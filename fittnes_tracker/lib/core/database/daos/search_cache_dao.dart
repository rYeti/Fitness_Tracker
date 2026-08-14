import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'search_cache_dao.g.dart';

@DriftAccessor(tables: [SearchCacheTable])
class SearchCacheDao extends DatabaseAccessor<AppDatabase>
    with _$SearchCacheDaoMixin {
  SearchCacheDao(super.db);

  Future<void> upsert(String q, String jsonData, int ts) async {
    await into(searchCacheTable).insertOnConflictUpdate(
      SearchCacheTableCompanion(
        query: Value(q),
        json: Value(jsonData),
        ts: Value(ts),
      ),
    );
  }

  Future<List<SearchCacheTableData>> getAll() => select(searchCacheTable).get();

  Future<void> deleteByQuery(String q) async {
    await (delete(searchCacheTable)..where((tbl) => tbl.query.equals(q))).go();
  }

  Future<void> deleteOlderThan(int cutoffTs) async {
    await (delete(searchCacheTable)
      ..where((tbl) => tbl.ts.isSmallerThanValue(cutoffTs))).go();
  }
}
