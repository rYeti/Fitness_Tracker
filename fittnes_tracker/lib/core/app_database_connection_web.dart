import 'package:drift/drift.dart';
import 'package:drift/web.dart';

LazyDatabase connect() {
  return LazyDatabase(() async => WebDatabase('fittracker_db'));
}
