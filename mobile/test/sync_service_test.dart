import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gestock/data/local/gestock_database.dart';
import 'package:gestock/data/repositories/auth_repository.dart';
import 'package:gestock/data/repositories/business_repository.dart';
import 'package:gestock/data/repositories/product_repository.dart';
import 'package:gestock/data/services/sync_service.dart';

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return Future<String?>.value(values[invocation.namedArguments[#key]]);
    }
    if (invocation.memberName == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) { values.remove(key); } else { values[key] = value; }
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      values.remove(invocation.namedArguments[#key]);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _TokenAuth extends AuthRepository {
  _TokenAuth() : super(dio: Dio(BaseOptions(baseUrl: 'https://auth.test')), storage: _MemoryStorage());
  @override
  Future<String> getAccessToken() async => 'test-access-token';
}

class _SyncAdapter implements HttpClientAdapter {
  _SyncAdapter({this.conflictStockMovement = false});
  final bool conflictStockMovement;
  final seen = <String>[];
  final levels = <String,double>{};

  ResponseBody _response(Object body, [int status = 200]) => ResponseBody.fromString(
    jsonEncode(body), status, headers: {'content-type': ['application/json']},
  );

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options.path);
    if (options.path == '/v1/sync/devices/register') {
      return _response({'data': {'id': 'device-test'}});
    }
    if (options.path == '/v1/stock/levels') {
      return _response({'data': levels.entries.map((entry) => {'product_id': entry.key, 'quantity': entry.value}).toList()});
    }
    if (options.path == '/v1/sync/batch') {
      final operations = (options.data as Map)['operations'] as List;
      return _response({'data': operations.map((operation) {
        final op = operation as Map;
        final conflict = conflictStockMovement && op['entity_type'] == 'stock_movement';
        if (!conflict && op['entity_type'] == 'stock_movement') {
          final payload = op['payload'] as Map;
          final productId = payload['product_id'].toString();
          levels[productId] = (levels[productId] ?? 0) + ((payload['quantity_delta'] as num).toDouble());
        }
        return {'operation_id': op['id'], 'status': conflict ? 'conflict' : 'applied', if (conflict) 'error': 'STOCK_CONFLICT'};
      }).toList()});
    }
    return _response({'error': 'NOT_FOUND'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late GeStockDatabase db;
  late String path;
  setUp(() async {
    sqfliteFfiInit();
    path = (await databaseFactoryFfi.getDatabasesPath()) + '/gestock_sync_test_' + DateTime.now().microsecondsSinceEpoch.toString() + '.db';
    db = GeStockDatabase(path: path, factory: databaseFactoryFfi);
  });
  tearDown(() async {
    await db.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });

  Future<String> createBusinessAndProduct() async {
    final businessRepo = BusinessRepository(db);
    final productRepo = ProductRepository(db);
    await businessRepo.create(name: 'Sync test', type: 'commerce', country: 'BJ', currency: 'XOF');
    final business = (await businessRepo.active())!;
    await productRepo.save(
      businessId: business['id'] as String, name: 'Sync item', sku: 'SYNC-01', barcode: '',
      purchasePrice: 50, salePrice: 100, taxRate: 0, quantity: 3, minQuantity: 1,
    );
    return business['id'] as String;
  }

  test('sync applies queued business, product and opening movement then clears outbox', () async {
    final businessId = await createBusinessAndProduct();
    final adapter = _SyncAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    final service = SyncService(
      database: db, auth: _TokenAuth(), dio: dio, secureStorage: _MemoryStorage(),
      connectivityCheck: () async => [ConnectivityResult.wifi],
    );
    expect(await service.syncPending(), isTrue);
    expect(adapter.seen, contains('/v1/sync/devices/register'));
    expect(adapter.seen, contains('/v1/sync/batch'));
    final database = await db.database;
    expect(await database.query('outbox', where: 'business_id = ?', whereArgs: [businessId]), isEmpty);
    expect((await database.query('businesses', where: 'id = ?', whereArgs: [businessId])).single['sync_state'], 'synced');
    expect((await database.query('products', where: 'business_id = ?', whereArgs: [businessId])).single['sync_state'], 'synced');
    expect((await database.query('stock_movements', where: 'business_id = ?', whereArgs: [businessId])).single['sync_state'], 'synced');
  });

  test('sync conflict remains queued as conflict and marks movement status', () async {
    final businessId = await createBusinessAndProduct();
    final adapter = _SyncAdapter(conflictStockMovement: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    final service = SyncService(
      database: db, auth: _TokenAuth(), dio: dio, secureStorage: _MemoryStorage(),
      connectivityCheck: () async => [ConnectivityResult.wifi],
    );
    expect(await service.syncPending(), isFalse);
    final database = await db.database;
    final movement = (await database.query('stock_movements', where: 'business_id = ?', whereArgs: [businessId])).single;
    expect(movement['sync_state'], 'conflict');
    final outbox = await database.query('outbox', where: 'business_id = ? AND status = ?', whereArgs: [businessId, 'conflict']);
    expect(outbox, hasLength(1));
  });
}
