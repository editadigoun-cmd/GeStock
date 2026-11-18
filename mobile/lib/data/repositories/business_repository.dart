import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
class BusinessRepository {
  BusinessRepository(this.db);
  final GeStockDatabase db;
  final _uuid = const Uuid();
  Future<List<Map<String, Object?>>> list() async {
    final d = await db.database;
    return d.query('businesses', orderBy: 'created_at DESC');
  }
  Future<void> create({required String name, required String type, required String country, required String currency}) async {
    final d = await db.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {'id': id, 'name': name.trim(), 'business_type': type, 'country_code': country, 'currency_code': currency};
    await d.transaction((txn) async {
      await txn.insert('businesses', {...payload, 'timezone': country == 'BJ' ? 'Africa/Porto-Novo' : 'UTC', 'created_at': now, 'sync_state': 'pending'});
      await txn.insert('outbox', {'id': _uuid.v4(), 'business_id': id, 'entity_type': 'business', 'entity_id': id, 'operation': 'create', 'payload': jsonEncode(payload), 'created_at': now});
    });
  }
}
