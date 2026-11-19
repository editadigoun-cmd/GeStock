import 'dart:convert';
import 'package:sqflite/sqflite.dart';
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

  Future<Map<String, Object?>> stockSummary(String businessId) async {
    final d = await db.database;
    final products = await d.query('products', where: 'business_id = ?', whereArgs: [businessId]);
    var units = 0.0;
    var low = 0;
    var value = 0.0;
    for (final product in products) {
      final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
      final minimum = (product['min_quantity'] as num?)?.toDouble() ?? 0;
      units += quantity;
      if (quantity <= minimum) low++;
      value += quantity * ((product['purchase_price'] as num?)?.toDouble() ?? 0);
    }
    final movements = await d.rawQuery('SELECT COUNT(*) AS count FROM stock_movements WHERE business_id = ?', [businessId]);
    return {'products': products.length, 'units': units, 'low_stock': low, 'stock_value': value, 'movements': movements.first['count']};
  }

  Future<List<Map<String, Object?>>> movementHistory(String businessId) async {
    final d = await db.database;
    return d.rawQuery("""
      SELECT m.id,m.movement_type,m.quantity_delta,m.note,m.occurred_at,m.sync_state,p.name AS product_name
      FROM stock_movements m LEFT JOIN products p ON p.id=m.product_id
      WHERE m.business_id=? ORDER BY m.occurred_at DESC LIMIT 50
    """, [businessId]);
  }

  Future<void> save({
    required String businessId,
    required String name,
    required String sku,
    required String barcode,
    required double purchasePrice,
    required double salePrice,
    required double taxRate,
    required double quantity,
    required double minQuantity,
  }) async {
    if (name.trim().isEmpty || [purchasePrice, salePrice, taxRate, quantity, minQuantity].any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Veuillez vérifier les informations du produit.');
    }
    final d = await db.database;
    final id = _uuid.v4();
    final warehouseRows = await d.query('warehouses', where: 'business_id = ? AND is_default = 1', whereArgs: [businessId], limit: 1);
    if (warehouseRows.isEmpty) throw StateError('Aucun dépôt principal pour cette entreprise.');
    final warehouseId = warehouseRows.first['id'] as String;
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'id': id, 'business_id': businessId, 'name': name.trim(),
      'sku': sku.trim().isEmpty ? null : sku.trim(),
      'barcode': barcode.trim().isEmpty ? null : barcode.trim(),
      'purchase_price': purchasePrice, 'sale_price': salePrice, 'tax_rate': taxRate,
      'quantity': quantity, 'min_quantity': minQuantity, 'unit': 'unité', 'updated_at': now,
    };
    await d.transaction((txn) async {
      await txn.insert('products', {
        ...payload, 'category': null, 'track_stock': 1, 'sync_state': 'pending',
      });
      await txn.insert('outbox', {
        'id': _uuid.v4(), 'business_id': businessId, 'entity_type': 'product', 'entity_id': id,
        'operation': 'upsert', 'payload': jsonEncode(payload), 'created_at': now,
      });
      if (quantity > 0) {
        final movementId = _uuid.v4();
        final movement = {
          'id': movementId, 'business_id': businessId, 'warehouse_id': warehouseId,
          'product_id': id, 'movement_type': 'opening', 'quantity_delta': quantity,
          'note': 'Stock initial', 'occurred_at': now,
        };
        await txn.insert('stock_movements', {...movement, 'sync_state': 'pending'});
        await txn.insert('outbox', {
          'id': _uuid.v4(), 'business_id': businessId, 'entity_type': 'stock_movement',
          'entity_id': movementId, 'operation': 'create', 'payload': jsonEncode(movement), 'created_at': now,
        });
      }
    });
  }

  Future<void> adjustStock({required String businessId, required String productId, required double delta, required String note}) async {
    if (!delta.isFinite || delta == 0) throw ArgumentError('La quantité doit être différente de zéro.');
    final d = await db.database;
    final rows = await d.query('products', where: 'id = ? AND business_id = ?', whereArgs: [productId, businessId], limit: 1);
    if (rows.isEmpty) throw StateError('Produit introuvable.');
    final current = (rows.first['quantity'] as num).toDouble();
    if (current + delta < 0) throw StateError('Le stock ne peut pas devenir négatif.');
    final warehouseRows = await d.query('warehouses', where: 'business_id = ? AND is_default = 1', whereArgs: [businessId], limit: 1);
    if (warehouseRows.isEmpty) throw StateError('Dépôt principal introuvable.');
    final now = DateTime.now().toUtc().toIso8601String();
    final movementId = _uuid.v4();
    final payload = {
      'id': movementId, 'business_id': businessId, 'warehouse_id': warehouseRows.first['id'],
      'product_id': productId, 'movement_type': delta > 0 ? 'purchase' : 'adjustment',
      'quantity_delta': delta, 'note': note, 'occurred_at': now,
    };
    await d.transaction((txn) async {
      await txn.update('products', {'quantity': current + delta, 'updated_at': now, 'sync_state': 'pending'}, where: 'id = ? AND business_id = ?', whereArgs: [productId, businessId]);
      await txn.insert('stock_movements', {...payload, 'sync_state': 'pending'});
      await txn.insert('outbox', {
        'id': _uuid.v4(), 'business_id': businessId, 'entity_type': 'stock_movement',
        'entity_id': movementId, 'operation': 'create', 'payload': jsonEncode(payload), 'created_at': now,
      });
    });
  }
}
