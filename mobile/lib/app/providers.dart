import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/gestock_database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/sales_repository.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/supplier_repository.dart';
import '../data/repositories/purchase_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/customer_payment_repository.dart';
import '../data/repositories/sale_return_repository.dart';
import '../data/repositories/cash_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/services/sync_service.dart';

final databaseProvider = Provider<GeStockDatabase>((ref) {
  final db = GeStockDatabase();
  ref.onDispose(db.close);
  return db;
});
final businessRepositoryProvider = Provider((ref) => BusinessRepository(ref.watch(databaseProvider)));
final productRepositoryProvider = Provider((ref) => ProductRepository(ref.watch(databaseProvider)));
final salesRepositoryProvider = Provider((ref) => SalesRepository(ref.watch(databaseProvider)));
final customerRepositoryProvider = Provider((ref) => CustomerRepository(ref.watch(databaseProvider), ref.watch(authRepositoryProvider)));
final authRepositoryProvider = Provider((ref) => AuthRepository());
final supplierRepositoryProvider = Provider((ref) => SupplierRepository(ref.watch(databaseProvider), ref.watch(authRepositoryProvider)));
final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository(ref.watch(databaseProvider), ref.watch(authRepositoryProvider)));
final expenseRepositoryProvider = Provider((ref) => ExpenseRepository(ref.watch(databaseProvider), ref.watch(authRepositoryProvider)));
final customerPaymentRepositoryProvider = Provider((ref) => CustomerPaymentRepository(ref.watch(databaseProvider), ref.watch(authRepositoryProvider)));
final saleReturnRepositoryProvider = Provider((ref) => SaleReturnRepository(ref.watch(databaseProvider)));
final cashRepositoryProvider = Provider((ref) => CashRepository(ref.watch(databaseProvider), ref.watch(authRepositoryProvider)));
final employeeRepositoryProvider = Provider((ref) => EmployeeRepository(ref.watch(authRepositoryProvider)));
final syncServiceProvider = Provider((ref) => SyncService(
  database: ref.watch(databaseProvider),
  auth: ref.watch(authRepositoryProvider),
));

final autoSyncProvider = Provider<void>((ref) {
  final runner = AutoSyncRunner(ref.watch(syncServiceProvider));
  runner.start();
  ref.onDispose(runner.dispose);
});
