import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
class ProductRepository {
  ProductRepository(this.db);
  final GeStockDatabase db;
  final _uuid = const Uuid();
  Future<List<Map<String, Object?>>> list(String businessId) async {
    final d = await db.database;
    return d.query('products', where: 'business_id = ?', whereArgs: [businessId], orderBy: 'name COLLATE NOCASE');
  }
  Future<void> save({required String businessId, required String name, required String sku, required double salePrice, required double quantity, required double minQuantity}) async {
    final d = await db.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {'id': id, 'business_id': businessId, 'name': name.trim(), 'sku': sku.trim(), 'sale_price': salePrice, 'quantity': quantity, 'min_quantity': minQuantity, 'updated_at': now};
    await d.transaction((txn) async {
      await txn.insert('products', {...payload, 'unit': 'unité', 'purchase_price': 0, 'sync_state': 'pending'});
      await txn.insert('outbox', {'id': _uuid.v4(), 'business_id': businessId, 'entity_type': 'product', 'entity_id': id, 'operation': 'upsert', 'payload': jsonEncode(payload), 'created_at': now});
    });
  }
}
