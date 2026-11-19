import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
import 'sale_math.dart';

class SalesRepository {
  SalesRepository(this.db);
  final GeStockDatabase db;
  final _uuid = const Uuid();

  Future<List<Map<String, Object?>>> list(String businessId) async {
    final d = await db.database;
    return d.query('sales', where: 'business_id = ?', whereArgs: [businessId], orderBy: 'sold_at DESC', limit: 100);
  }

  Future<int> pendingCount(String businessId) async {
    final d = await db.database;
    final rows = await d.rawQuery("SELECT COUNT(*) AS count FROM outbox WHERE business_id = ? AND entity_type = 'sale' AND status IN ('queued','conflict','failed')", [businessId]);
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<String> createSale({
    required String businessId,
    required String currencyCode,
    required Map<String, double> quantities,
    required String paymentMethod,
  }) async {
    if (quantities.isEmpty) throw StateError('Le panier est vide.');
    if (!['cash', 'mobile_money', 'card', 'bank_transfer', 'other'].contains(paymentMethod)) {
      throw ArgumentError('Mode de paiement invalide.');
    }
    final d = await db.database;
    final warehouseRows = await d.query('warehouses', where: 'business_id = ? AND is_default = 1', whereArgs: [businessId], limit: 1);
    if (warehouseRows.isEmpty) throw StateError('Dépôt principal introuvable.');
    final warehouseId = warehouseRows.first['id'] as String;
    final productRows = <Map<String, Object?>>[];
    for (final entry in quantities.entries) {
      if (!entry.value.isFinite || entry.value <= 0) throw ArgumentError('Quantité invalide.');
      final rows = await d.query('products', where: 'id = ? AND business_id = ?', whereArgs: [entry.key, businessId], limit: 1);
      if (rows.isEmpty) throw StateError('Produit introuvable.');
      final product = rows.first;
      final current = (product['quantity'] as num?)?.toDouble() ?? 0;
      if (current < entry.value) throw StateError('Stock insuffisant pour ${product['name']}.');
      productRows.add({...product, 'cart_quantity': entry.value});
    }

    final lines = productRows.map((product) {
      final quantity = (product['cart_quantity'] as num).toDouble();
      final price = (product['sale_price'] as num?)?.toDouble() ?? 0;
      final taxRate = (product['tax_rate'] as num?)?.toDouble() ?? 0;
      return SaleLineDraft(quantity: quantity, unitPrice: price, taxAmount: roundMoney(quantity * price * taxRate / 100));
    }).toList();
    final totals = calculateSaleTotals(lines);
    final saleId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final number = 'GS-${now.replaceAll(RegExp(r'[-:T.]'), '').substring(0, 14)}-${saleId.substring(0, 4).toUpperCase()}';
    final pendingPayment = ['mobile_money', 'card', 'bank_transfer'].contains(paymentMethod);
    final amountPaid = pendingPayment ? 0.0 : totals.total;
    final payloadItems = productRows.map((product) => {
      'product_id': product['id'],
      'product_name_snapshot': product['name'],
      'quantity': product['cart_quantity'],
      'unit_price': product['sale_price'],
      'discount_amount': 0,
      'tax_amount': roundMoney((product['cart_quantity'] as num).toDouble() * ((product['sale_price'] as num?)?.toDouble() ?? 0) * ((product['tax_rate'] as num?)?.toDouble() ?? 0) / 100),
    }).toList();
    final payload = {
      'id': saleId,
      'business_id': businessId,
      'warehouse_id': warehouseId,
      'sale_number': number,
      'currency_code': currencyCode,
      'sold_at': now,
      'payment_method': paymentMethod,
      'payment_amount': totals.total,
      'items': payloadItems,
    };

    await d.transaction((txn) async {
      await txn.insert('sales', {
        'id': saleId, 'business_id': businessId, 'sale_number': number,
        'currency_code': currencyCode, 'subtotal': totals.subtotal, 'discount_total': totals.discountTotal,
        'tax_total': totals.taxTotal, 'total': totals.total, 'amount_paid': amountPaid,
        'payment_method': paymentMethod, 'payment_status': pendingPayment ? 'pending' : 'confirmed',
        'status': 'completed', 'sold_at': now, 'sync_state': 'pending',
        'warehouse_id': warehouseId, 'created_at': now,
      });
      for (var i = 0; i < productRows.length; i++) {
        final product = productRows[i];
        final quantity = (product['cart_quantity'] as num).toDouble();
        final price = (product['sale_price'] as num?)?.toDouble() ?? 0;
        final lineTotal = roundMoney(quantity * price);
        await txn.insert('sale_items', {
          'id': _uuid.v4(), 'sale_id': saleId, 'product_id': product['id'],
          'product_name_snapshot': product['name'], 'quantity': quantity,
          'unit_price': price, 'discount_amount': 0, 'tax_amount': roundMoney(quantity * price * ((product['tax_rate'] as num?)?.toDouble() ?? 0) / 100), 'line_total': roundMoney(lineTotal + roundMoney(quantity * price * ((product['tax_rate'] as num?)?.toDouble() ?? 0) / 100)),
        });
        await txn.update('products', {
          'quantity': ((product['quantity'] as num?)?.toDouble() ?? 0) - quantity,
          'updated_at': now,
        }, where: 'id = ? AND business_id = ?', whereArgs: [product['id'], businessId]);
        await txn.insert('stock_movements', {
          'id': _uuid.v4(), 'business_id': businessId, 'warehouse_id': warehouseId,
          'product_id': product['id'], 'movement_type': 'sale', 'quantity_delta': -quantity,
          'note': 'Vente $number', 'occurred_at': now, 'sync_state': 'pending',
          'source_type': 'sale', 'source_id': saleId,
        });
      }
      await txn.insert('sale_payments', {
        'id': _uuid.v4(), 'sale_id': saleId, 'payment_method': paymentMethod,
        'amount': totals.total, 'status': pendingPayment ? 'pending' : 'confirmed',
        'paid_at': pendingPayment ? null : now, 'created_at': now,
      });
      await txn.insert('outbox', {
        'id': saleId, 'business_id': businessId, 'entity_type': 'sale', 'entity_id': saleId,
        'operation': 'create', 'payload': jsonEncode(payload), 'created_at': now, 'attempts': 0, 'status': 'queued',
      });
    });
    return saleId;
  }
}
