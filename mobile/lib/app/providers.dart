import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/gestock_database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/services/sync_service.dart';

final databaseProvider = Provider<GeStockDatabase>((ref) {
  final db = GeStockDatabase();
  ref.onDispose(db.close);
  return db;
});
final businessRepositoryProvider = Provider((ref) => BusinessRepository(ref.watch(databaseProvider)));
final productRepositoryProvider = Provider((ref) => ProductRepository(ref.watch(databaseProvider)));
final authRepositoryProvider = Provider((ref) => AuthRepository());
final syncServiceProvider = Provider((ref) => SyncService(
  database: ref.watch(databaseProvider),
  auth: ref.watch(authRepositoryProvider),
));
