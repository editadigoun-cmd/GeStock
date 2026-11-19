import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
import '../repositories/auth_repository.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

class SyncService {
  SyncService({required this.database, required this.auth, Dio? dio, FlutterSecureStorage? secureStorage, ConnectivityCheck? connectivityCheck})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('GESTOCK_API_URL'),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Content-Type': 'application/json'},
        )),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _connectivityCheck = connectivityCheck ?? (() => Connectivity().checkConnectivity());

  final GeStockDatabase database;
  final AuthRepository auth;
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final ConnectivityCheck _connectivityCheck;
  static const _deviceKeyStorage = 'gestock_sync_device_key';
  static const _platformStorage = 'gestock_sync_platform';
  final _uuid = const Uuid();

  Future<String> _deviceKey() async {
    var value = await _secureStorage.read(key: _deviceKeyStorage);
    if (value == null || value.isEmpty) {
      value = _uuid.v4();
      await _secureStorage.write(key: _deviceKeyStorage, value: value);
    }
    return value;
  }

  String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  Future<bool> retryFailed() async {
    final db = await database.database;
    await db.update('outbox', {'status': 'queued'}, where: "status IN ('failed','conflict')");
    return syncPending();
  }

  Future<bool> syncPending() async {
    if (_dio.options.baseUrl.trim().isEmpty) return false;
    final connectivity = await _connectivityCheck();
    if (connectivity.contains(ConnectivityResult.none)) return false;
    final token = await auth.getAccessToken();
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final registration = await _dio.post('/v1/sync/devices/register', data: {'device_key': await _deviceKey(), 'platform': _platform()});
    final deviceData = registration.data;
    if (deviceData is! Map || deviceData['data'] is! Map || deviceData['data']['id'] is! String) {
      throw StateError('Réponse d’enregistrement de l’appareil invalide.');
    }
    final deviceId = deviceData['data']['id'] as String;
    await _secureStorage.write(key: _platformStorage, value: _platform());
    final db = await database.database;
    var allApplied = true;
    while (true) {
      final pending = await db.rawQuery("""
        SELECT id,business_id,entity_type,entity_id,operation,payload,created_at,attempts
        FROM outbox WHERE status='queued'
        ORDER BY CASE entity_type WHEN 'business' THEN 0 WHEN 'product' THEN 1 WHEN 'stock_movement' THEN 2 WHEN 'sale' THEN 3 ELSE 4 END,
        created_at ASC,rowid ASC LIMIT 30
      """);
      if (pending.isEmpty) break;
      final operations = pending.map((row) => {
        'id': row['id'], 'business_id': row['business_id'], 'entity_type': row['entity_type'],
        'entity_id': row['entity_id'], 'operation': row['operation'],
        'payload': jsonDecode(row['payload'] as String), 'created_at': row['created_at'],
      }).toList();
      final response = await _dio.post('/v1/sync/batch', data: {'device_id': deviceId, 'operations': operations});
      final responseData = response.data;
      if (responseData is! Map || responseData['data'] is! List) throw StateError('Réponse de synchronisation invalide.');
      final results = (responseData['data'] as List).whereType<Map>().toList();
      for (final result in results) {
        final operationId = result['operation_id'] as String?;
        final operationRow = pending.firstWhere((row) => row['id'] == operationId, orElse: () => <String, Object?>{});
        final operationType = operationRow['entity_type'] as String?;
        if (operationId == null) continue;
        if (result['status'] == 'applied') {
          await db.transaction((txn) async {
            final rows = await txn.query('outbox', where: 'id = ?', whereArgs: [operationId], limit: 1);
            if (rows.isEmpty) return;
            final type = rows.first['entity_type'] as String;
            final entityId = rows.first['entity_id'] as String;
            if (type == 'business') {
              await txn.update('businesses', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [entityId]);
            } else if (type == 'product') {
              await txn.update('products', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [entityId]);
            } else if (type == 'stock_movement') {
              await txn.update('stock_movements', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [entityId]);
            } else if (type == 'sale') {
              await txn.update('sales', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [entityId]);
              await txn.update('stock_movements', {'sync_state': 'synced'}, where: 'source_type = ? AND source_id = ?', whereArgs: ['sale', entityId]);
            }
            await txn.delete('outbox', where: 'id = ?', whereArgs: [operationId]);
          });
        } else {
          allApplied = false;
          final attempts = (pending.firstWhere((row) => row['id'] == operationId, orElse: () => {'attempts': 0})['attempts'] as int? ?? 0) + 1;
          final status = result['status'] == 'rejected' ? 'failed' : 'conflict';
          await db.update('outbox', {'attempts': attempts, 'status': status}, where: 'id = ?', whereArgs: [operationId]);
          if (operationType == 'business') {
            await db.update('businesses', {'sync_state': status}, where: 'id = ?', whereArgs: [operationRow['entity_id']]);
          } else if (operationType == 'product') {
            await db.update('products', {'sync_state': status}, where: 'id = ?', whereArgs: [operationRow['entity_id']]);
          } else if (operationType == 'stock_movement') {
            await db.update('stock_movements', {'sync_state': status}, where: 'id = ?', whereArgs: [operationRow['entity_id']]);
          } else if (operationType == 'sale') {
            await db.update('sales', {'sync_state': status}, where: 'id = ?', whereArgs: [operationId]);
            await db.update('stock_movements', {'sync_state': status}, where: 'source_type = ? AND source_id = ?', whereArgs: ['sale', operationId]);
          }
        }
      }
      if (results.length < operations.length) allApplied = false;
      if (results.isEmpty) break;
    }
    return allApplied;
  }
}
