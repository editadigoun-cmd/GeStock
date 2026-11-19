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

  test('country defaults resolve currency and timezone consistently', () async {
    expect(defaultCurrencyForCountry('BJ'), 'XOF');
    expect(defaultCurrencyForCountry('CM'), 'XAF');
    expect(defaultCurrencyForCountry('US'), 'USD');
    expect(defaultCurrencyForCountry('NG'), 'NGN');
    expect(defaultCurrencyForCountry('GH'), 'GHS');
    expect(defaultCurrencyForCountry('GB'), 'GBP');
    expect(defaultTimezoneForCountry('US'), 'America/New_York');
    expect(defaultTimezoneForCountry('NG'), 'Africa/Lagos');
    await BusinessRepository(db).create(name: 'US test', type: 'commerce', country: 'US', currency: defaultCurrencyForCountry('US'));
    final business = (await BusinessRepository(db).active())!;
    expect(business['currency_code'], 'USD');
    expect(business['timezone'], 'America/New_York');
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

  test('external payment methods stay pending until a provider confirms them', () async {
    final businesses = BusinessRepository(db);
    final products = ProductRepository(db);
    final sales = SalesRepository(db);
    await businesses.create(name: 'Boutique paiement', type: 'commerce', country: 'BJ', currency: 'XOF');
    final business = (await businesses.active())!;
    final businessId = business['id'] as String;
    await products.save(
      businessId: businessId, name: 'Produit paiement', sku: 'PAY-01', barcode: '',
      purchasePrice: 100, salePrice: 250, taxRate: 0, quantity: 2, minQuantity: 0,
    );
    final product = (await products.list(businessId)).single;
    final saleId = await sales.createSale(
      businessId: businessId, currencyCode: 'XOF',
      quantities: {product['id'] as String: 1}, paymentMethod: 'mobile_money',
    );
    final sale = (await sales.list(businessId)).single;
    expect(sale['id'], saleId);
    expect(sale['payment_status'], 'pending');
    expect(sale['amount_paid'], 0);
    final database = await db.database;
    final payment = (await database.query('sale_payments', where: 'sale_id = ?', whereArgs: [saleId])).single;
    expect(payment['status'], 'pending');
    expect(payment['paid_at'], isNull);
  });

  test('duplicate barcodes are rejected on create and update', () async {
    final businesses = BusinessRepository(db);
    final products = ProductRepository(db);
    await businesses.create(name: 'Barcode test', type: 'commerce', country: 'BJ', currency: 'XOF');
    final businessId = (await businesses.active())!['id'] as String;
    await products.save(businessId: businessId, name: 'First', sku: 'A', barcode: '123456', purchasePrice: 10, salePrice: 20, taxRate: 0, quantity: 1, minQuantity: 0);
    await products.save(businessId: businessId, name: 'Second', sku: 'B', barcode: '654321', purchasePrice: 10, salePrice: 20, taxRate: 0, quantity: 1, minQuantity: 0);
    final second = (await products.list(businessId)).firstWhere((row) => row['sku'] == 'B');
    await expectLater(products.save(businessId: businessId, name: 'Third', sku: 'C', barcode: '123456', purchasePrice: 10, salePrice: 20, taxRate: 0, quantity: 0, minQuantity: 0), throwsStateError);
    await expectLater(products.update(businessId: businessId, productId: second['id'] as String, name: 'Second', sku: 'B', barcode: '123456', purchasePrice: 10, salePrice: 20, taxRate: 0, minQuantity: 0), throwsStateError);
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
