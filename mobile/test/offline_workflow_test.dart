import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gestock/data/local/gestock_database.dart';
import 'package:gestock/data/repositories/business_repository.dart';
import 'package:gestock/data/repositories/product_repository.dart';
import 'package:gestock/data/repositories/sales_repository.dart';

void main() {
  late GeStockDatabase db;
  late String testPath;

  setUp(() async {
    sqfliteFfiInit();
    final root = await databaseFactoryFfi.getDatabasesPath();
    testPath = root + '/gestock_test_' + DateTime.now().microsecondsSinceEpoch.toString() + '.db';
    db = GeStockDatabase(path: testPath, factory: databaseFactoryFfi);
  });

  tearDown(() async {
    await db.close();
    await databaseFactoryFfi.deleteDatabase(testPath);
  });

  test('business, catalogue, stock adjustments and POS persist offline to the outbox', () async {
    final businesses = BusinessRepository(db);
    final products = ProductRepository(db);
    final sales = SalesRepository(db);

    await businesses.create(name: 'Boutique test', type: 'commerce', country: 'BJ', currency: 'XOF');
    final business = await businesses.active();
    expect(business, isNotNull);
    final businessId = business!['id'] as String;

    await products.save(
      businessId: businessId, name: 'Produit test', sku: 'SKU-01', barcode: '',
      purchasePrice: 100, salePrice: 200, taxRate: 0, quantity: 5, minQuantity: 2,
    );
    final product = (await products.list(businessId)).single;
    final productId = product['id'] as String;
    expect(product['quantity'], 5);

    await products.adjustStock(businessId: businessId, productId: productId, delta: -2, note: 'Correction inventaire');
    expect((await products.list(businessId)).single['quantity'], 3);

    final saleId = await sales.createSale(
      businessId: businessId, currencyCode: 'XOF', quantities: {productId: 1}, paymentMethod: 'cash',
    );
    expect(saleId, isNotEmpty);
    expect((await products.list(businessId)).single['quantity'], 2);
    expect((await sales.list(businessId)).single['total'], 200);

    final database = await db.database;
    final movementCount = await database.rawQuery('SELECT COUNT(*) AS count FROM stock_movements WHERE business_id = ?', [businessId]);
    final outboxCount = await database.rawQuery('SELECT COUNT(*) AS count FROM outbox WHERE business_id = ? AND status = ?', [businessId, 'queued']);
    expect(movementCount.single['count'], 3);
    expect(outboxCount.single['count'], 5);
    expect(await sales.pendingCount(businessId), 1);
  });

  test('editing a product coalesces its pending create and preserves stock', () async {
    final businesses = BusinessRepository(db);
    final products = ProductRepository(db);
    await businesses.create(name: 'Boutique test', type: 'commerce', country: 'BJ', currency: 'XOF');
    final business = (await businesses.active())!;
    final businessId = business['id'] as String;
    await products.save(
      businessId: businessId, name: 'Original', sku: 'REF-2', barcode: '',
      purchasePrice: 50, salePrice: 80, taxRate: 0, quantity: 4, minQuantity: 1,
    );
    final product = (await products.list(businessId)).single;
    await products.update(
      businessId: businessId, productId: product['id'] as String, name: 'Renommé', sku: 'REF-2',
      barcode: '12345', purchasePrice: 55, salePrice: 95, taxRate: 5, minQuantity: 3,
    );
    final updated = (await products.list(businessId)).single;
    expect(updated['name'], 'Renommé');
    expect(updated['sale_price'], 95);
    expect(updated['quantity'], 4);
    final database = await db.database;
    final queuedProductOps = await database.query('outbox', where: "entity_type = 'product' AND entity_id = ? AND status = 'queued'", whereArgs: [product['id']]);
    expect(queuedProductOps, hasLength(1));
    expect(queuedProductOps.single['attempts'], 0);
  });
}
